#!/usr/bin/env python3
"""spec validate 的 domain 覆蓋閘門：spec 的每個 FR 是否都被 domain map 的 FR->bundle 覆蓋表歸屬。

背景：一次架構檢討發現 domain 規劃缺口——spec 定義 FR、UC 定義場景，但無 domain
bundle 邊界；且 spec FR 是否全數映射到某 bundle 缺工具強制（曾靠人工四視角審查才
抓出漏覆蓋的 FR）。本檢核作為 /spec validate Layer 1 的擴充規則，機械掃描：
  1. spec 對應的 domain map 是否存在
  2. spec 每個 FR 是否出現在 domain map 的 FR 覆蓋（含標為 presentation/data 的非 domain FR）

domain map 定位鏈：--domain-map 明示（唯一來源，不聯集）-> spec 同目錄 domain-map.md
與 docs/spec/*/domain-map.md 中 frontmatter source_specs 含本 SPEC id 者（同目錄為聯集
成員之一，並聯集 docs/system-layer.md；逐檔解析後於集合層合併）-> docs/domain-map.md。

另含可選檢核「事件流標定」（`--check-event-flow-labeling`）：spec 的 FR 段落若命中
事件流訊號詞（清單見 EVENT_FLOW_SIGNAL_WORDS，與 /spec validate Layer 2 維度 5「資源
競爭」共用同一份訊號詞，見 SKILL.md 維度 5 掃描說明），該 FR 須能在 domain map 的
「通道與協調圖」節（以標題文字定位，不依編號——章節編號在各專案可能已被既有內容
佔用）之「到達類別與級別實例」子表中找到對應的 FR 引用，缺者列為提醒，非阻擋。
"""

import argparse
import re
import sys
from pathlib import Path

import check_api_surface

# FR 標題容許 H3 以上任一層級（### / #### …）——真實 spec 常用 #### FR-XX:，
# 只認 H3 會使 extract_spec_frs 回空集、gate 靜默假通過（Round 2-C 實證）。
# 冒號接受半形與全形（SPEC-006/007 用全形，曾因只認半形而抽出 0 個、假通過）。
FR_HEADER_RE = re.compile(r"^#{3,}\s+(FR-\d+)[:：]", re.MULTILINE)

# 事件流訊號詞：與 /spec validate Layer 2 維度 5「資源競爭」共用單一常數，避免
# Layer 1 機械檢核與 Layer 2 語意維度各自維護清單而漂移（SKILL.md 維度 5 掃描說明）。
EVENT_FLOW_SIGNAL_WORDS = (
    "事件", "通知", "提示", "背景", "排程", "佇列", "推送", "webhook", "isolate",
)

# domain map 章節標題比對：以標題文字定位，不依編號（章節編號在既有專案可能已
# 被其他內容佔用，如本專案 docs/domain-map.md 的「## 2.5」已用於他途）。
CHANNEL_SECTION_TITLE_RE = re.compile(r"^(#{1,6})\s*.*通道與協調圖.*$", re.MULTILINE)
ARRIVAL_LEVEL_TABLE_TITLE_RE = re.compile(r"^(#{1,6})\s*.*到達類別與級別.*$", re.MULTILINE)
# 展開 FR token：FR-NN、逗號續列 FR-01,02,03、範圍 FR-13~17 / FR-13-17
FR_TOKEN_RE = re.compile(r"FR-(\d+)((?:\s*[~\-,]\s*\d+)*)")


def _expand_fr_token(head_num, tail):
    """展開單一 FR token 為 int 集合。head_num=起始號，tail=續列/範圍字串。"""
    nums = {int(head_num)}
    prev = int(head_num)
    for op, digits in re.findall(r"([~\-,])\s*(\d+)", tail):
        n = int(digits)
        if op == ",":
            nums.add(n)
            prev = n
        else:  # ~ 或 - 視為範圍
            for v in range(min(prev, n), max(prev, n) + 1):
                nums.add(v)
            prev = n
    return nums


def extract_fr_ids(text):
    """從文字抽出所有 FR 編號（int 集合），處理逗號續列與範圍。"""
    ids = set()
    for head, tail in FR_TOKEN_RE.findall(text):
        ids |= _expand_fr_token(head, tail)
    return ids


def extract_spec_frs(spec_text):
    """從 spec 的 `### FR-XX:` 標題抽出定義的 FR 編號（int 集合）。"""
    return {int(m.group(1).split("-")[1]) for m in FR_HEADER_RE.finditer(spec_text)}


SPEC_ID_RE = re.compile(r"SPEC-\d+")
FRONTMATTER_BLOCK_RE = re.compile(r"\A---\s*\n(.*?)^---\s*$", re.MULTILINE | re.DOTALL)
FRONTMATTER_ID_LINE_RE = re.compile(r"^id:\s*[\"']?([^\s\"']+)", re.MULTILINE)
HEADING_RE = re.compile(r"^(#{1,6})\s")


def extract_spec_id(spec_text, spec_path=None):
    """spec 識別：先取 frontmatter id，缺時取檔名的 SPEC-NNN 前綴，都沒有回 None。

    只接受 SPEC-NNN 形式：domain map 的歸屬鍵由 SPEC_ID_RE 抽出，其他形式的 id
    （如 SPEC-UI-001）在 map 端永遠對不上，回 None 讓呼叫端走相容模式並警告，
    而不是把該 spec 的全部 FR 報成未覆蓋。frontmatter 只看收尾 --- 之前的區塊。
    """
    block = FRONTMATTER_BLOCK_RE.match(spec_text)
    fm = FRONTMATTER_ID_LINE_RE.search(block.group(1)) if block else None
    if fm:
        candidate = fm.group(1).upper()
        return candidate if SPEC_ID_RE.fullmatch(candidate) else None
    if spec_path is not None:
        name = SPEC_ID_RE.match(Path(spec_path).name)
        if name:
            return name.group(0).upper()
    return None


def _line_fr_owners(line, heading_spec):
    """回傳該行每個 FR token 的（所屬 spec 或 None, FR 編號集合）。

    歸屬順序：同一行在 token 之前最近的 SPEC-NNN；否則沿用祖先標題的 spec。
    """
    for m in FR_TOKEN_RE.finditer(line):
        before = SPEC_ID_RE.findall(line[: m.start()])
        owner = before[-1].upper() if before else heading_spec
        yield owner, _expand_fr_token(m.group(1), m.group(2))


def extract_fr_attribution(domain_map_text):
    """回傳 ({spec_id: FR 編號集合}, 未歸屬 FR 編號集合)。"""
    attributed, unattributed = {}, set()
    stack = []  # [(標題階層, 該標題的 spec 或 None)]
    for line in domain_map_text.splitlines():
        heading = HEADING_RE.match(line)
        if heading:
            level = len(heading.group(1))
            while stack and stack[-1][0] >= level:
                stack.pop()
            found = SPEC_ID_RE.search(line)
            stack.append((level, found.group(0).upper() if found else None))
        heading_spec = next((sp for _, sp in reversed(stack) if sp), None)
        for owner, nums in _line_fr_owners(line, heading_spec):
            if owner:
                attributed.setdefault(owner, set()).update(nums)
            else:
                unattributed |= nums
    return attributed, unattributed


def check_domain_coverage(spec_text, domain_map_text, spec_path=None):
    """回傳 spec 定義但 domain map 未覆蓋的 FR 編號（排序 list）。

    比對鍵為（spec 識別, FR 編號）。spec 識別取不到、或 map 無任何已歸屬 token 時，
    走相容模式（不分 spec 的舊比對）並於 stderr 說明。
    """
    spec_frs = extract_spec_frs(spec_text)
    spec_id = extract_spec_id(spec_text, spec_path)
    attributed, _ = extract_fr_attribution(domain_map_text)
    if spec_id is None:
        sys.stderr.write("WARNING: 取不到 spec 識別（frontmatter id / 檔名 SPEC-NNN），走相容模式（不分 spec 比對）\n")
    elif not attributed:
        sys.stderr.write("domain 覆蓋檢核：domain map 無任何 FR 歸屬到 SPEC-NNN，走相容模式（不分 spec 比對）\n")
    else:
        return sorted(spec_frs - attributed.get(spec_id, set()))
    return sorted(spec_frs - extract_fr_ids(domain_map_text))


def _merged_attribution(named_texts, spec_id):
    """逐檔解析歸屬後於集合層合併，回傳 {spec_id: FR 集合}。

    標題堆疊不跨檔。整份無任何 SPEC 歸屬的檔案（系統層除外），其 FR 一律計給受檢 SPEC（相容語意，
    單檔與多檔同一規則）；檔案內有部分歸屬時，有歸屬者依歸屬，未歸屬者不計入。
    """
    merged = {}
    for name, text in named_texts:
        attributed, unattributed = extract_fr_attribution(text)
        # 系統層是定位鏈無條件附加的，不是因與受檢 SPEC 有關而被選入，不適用預設計給
        is_system_layer = Path(name).name == SYSTEM_LAYER_PATH.name
        if not attributed and unattributed and spec_id and not is_system_layer:
            sys.stderr.write(f"domain 覆蓋檢核：{name} 無任何 SPEC 歸屬，其 FR 依預設計給受檢 SPEC\n")
            attributed = {spec_id: unattributed}
        for owner, nums in attributed.items():
            merged.setdefault(owner, set()).update(nums)
    return merged


def check_domain_coverage_union(spec_text, named_texts, spec_path=None):
    """多份 map（(檔名, 內容) 清單）聯集版的 check_domain_coverage，聯集發生在集合層。"""
    spec_frs = extract_spec_frs(spec_text)
    spec_id = extract_spec_id(spec_text, spec_path)
    attributed = _merged_attribution(named_texts, spec_id)
    if spec_id is None:
        sys.stderr.write("WARNING: 取不到 spec 識別（frontmatter id / 檔名 SPEC-NNN），走相容模式（不分 spec 比對）\n")
    elif not attributed:
        sys.stderr.write("domain 覆蓋檢核：domain map 無任何 FR 歸屬到 SPEC-NNN，走相容模式（不分 spec 比對）\n")
    else:
        return sorted(spec_frs - attributed.get(spec_id, set()))
    return sorted(spec_frs - extract_fr_ids("\n".join(t for _, t in named_texts)))


def extract_event_signaled_frs(spec_text, signal_words=EVENT_FLOW_SIGNAL_WORDS):
    """回傳 spec 中，FR 段落內文命中任一事件流訊號詞的 FR 編號集合（int）。

    段落切分沿用 check_api_surface.split_fr_sections（H3 `### FR-XX:` 標題），
    避免與既有 API surface 檢核各自維護一份切段邏輯。
    """
    signaled = set()
    for fr_id, section in check_api_surface.split_fr_sections(spec_text):
        lowered = section.lower()
        if any(word.lower() in lowered for word in signal_words):
            signaled.add(int(fr_id.split("-")[1]))
    return signaled


def _extract_section_by_title(text, title_re):
    """依標題文字定位一個章節（不依編號），回傳從該標題到下一個同級或更高階標題前的內容。

    找不到標題時回傳 None。「同級或更高階」判定以 `#` 數決定，使巢狀子節（較深階
    標題）不會被誤判為章節邊界。
    """
    match = title_re.search(text)
    if not match:
        return None
    level = len(match.group(1))
    start = match.start()
    next_heading_re = re.compile(r"^#{1," + str(level) + r"}\s+", re.MULTILINE)
    next_match = next_heading_re.search(text, match.end())
    end = next_match.start() if next_match else len(text)
    return text[start:end]


def extract_channel_section(domain_map_text):
    """定位 domain map 的『通道與協調圖』節（標題文字比對，不依編號）。"""
    return _extract_section_by_title(domain_map_text, CHANNEL_SECTION_TITLE_RE)


def extract_arrival_level_table(channel_section_text):
    """在『通道與協調圖』節內，定位含到達類別與級別欄的『到達類別與級別實例』子節。"""
    if channel_section_text is None:
        return None
    return _extract_section_by_title(channel_section_text, ARRIVAL_LEVEL_TABLE_TITLE_RE)


def check_event_flow_labeling(spec_text, domain_map_text, signal_words=EVENT_FLOW_SIGNAL_WORDS):
    """回傳命中事件流訊號詞、但 domain map 通道表未見對應標定的 FR 編號（排序 list）。

    未命中任何訊號詞的 spec 回傳空 list（維度 5 同形的條件式觸發：無事件流訊號時不檢核）。
    """
    return check_event_flow_labeling_union(spec_text, [domain_map_text], signal_words)


def check_event_flow_labeling_union(spec_text, map_texts, signal_words=EVENT_FLOW_SIGNAL_WORDS):
    """多份 map 版：逐檔取通道章節與到達級別子表，聯集已標定的 FR 後再比對。"""
    signaled = extract_event_signaled_frs(spec_text, signal_words)
    if not signaled:
        return []
    labeled = set()
    for text in map_texts:
        table = extract_arrival_level_table(extract_channel_section(text))
        if table:
            labeled |= extract_fr_ids(table)
    return sorted(signaled - labeled)


DOMAIN_MAP_GLOB_DIR = Path("docs/spec")
SYSTEM_LAYER_PATH = Path("docs/system-layer.md")
LEGACY_DOMAIN_MAP_PATH = Path("docs/domain-map.md")
SOURCE_SPECS_RE = re.compile(r"^source_specs:\s*\[(.*?)\]", re.MULTILINE)


def _declared_source_specs(map_text):
    """回傳 domain map frontmatter 的 source_specs 清單（大寫 SPEC-NNN）。"""
    block = FRONTMATTER_BLOCK_RE.match(map_text)
    found = SOURCE_SPECS_RE.search(block.group(1)) if block else None
    return set(SPEC_ID_RE.findall(found.group(1).upper())) if found else set()


def _list_domain_maps():
    """列舉 docs/spec/*/domain-map.md（依路徑排序，結果穩定）。"""
    return sorted(DOMAIN_MAP_GLOB_DIR.glob("*/domain-map.md"))


def _maps_listing_spec(spec_id):
    """回傳 source_specs 含 spec_id 的 domain map 清單。"""
    if spec_id is None:
        return []
    return [
        m for m in _list_domain_maps()
        if spec_id in _declared_source_specs(m.read_text(encoding="utf-8"))
    ]


def locate_domain_maps(spec_path, explicit, spec_id=None):
    """定位 domain map 清單（可多份，覆蓋判定取聯集）。

    解析鏈：explicit -> spec 同目錄（為聯集成員之一，不短路）+ docs/spec/*/domain-map.md 中 source_specs 含本 SPEC
    者（並聯集 docs/system-layer.md）-> docs/domain-map.md。找不到回空 list。
    """
    if explicit:
        p = Path(explicit)
        return [p] if p.exists() else []
    same_dir = spec_path.parent / "domain-map.md"
    if spec_id is None and Path(spec_path).exists():
        spec_id = extract_spec_id(Path(spec_path).read_text(encoding="utf-8"), spec_path)
    found = [same_dir] if same_dir.exists() else []
    seen = {p.resolve() for p in found}
    for m in _maps_listing_spec(spec_id):
        if m.resolve() not in seen:
            found.append(m)
            seen.add(m.resolve())
    if found:
        return found + ([SYSTEM_LAYER_PATH] if SYSTEM_LAYER_PATH.exists() else [])
    return [LEGACY_DOMAIN_MAP_PATH] if LEGACY_DOMAIN_MAP_PATH.exists() else []


def locate_domain_map(spec_path, explicit):
    """相容入口：回傳 locate_domain_maps 的第一份，找不到回 None。"""
    found = locate_domain_maps(spec_path, explicit)
    return found[0] if found else None


def describe_missing_map(explicit):
    """找不到 map 時的訊息：區分「無任何 map」與「有 map 但無一列入本 SPEC」。"""
    if explicit:
        return f"domain 覆蓋檢核：--domain-map 指定的檔案不存在：{explicit}"
    if _list_domain_maps():
        return (
            "domain 覆蓋檢核：有 domain map（docs/spec/*/domain-map.md），但無一份的 "
            "source_specs 列入本 SPEC。請於對應 domain map frontmatter 的 source_specs 補上本 SPEC id，"
            "或以 --domain-map 指定。"
        )
    return (
        "domain 覆蓋檢核：找不到任何 domain map（spec 同目錄 domain-map.md、"
        "docs/spec/*/domain-map.md 或 docs/domain-map.md）。"
        "依 version-bootstrap Step 2.5，規劃波應先產出 domain map。"
    )


DOMAIN_FIELD_RE = re.compile(r"^domain:[ \t]*[\"']?([^\s\"'#]+)", re.MULTILINE)


def _frontmatter_domain(text):
    """回傳 frontmatter 的 domain 欄值；未填或無 frontmatter 回 None。"""
    block = FRONTMATTER_BLOCK_RE.match(text)
    found = DOMAIN_FIELD_RE.search(block.group(1)) if block else None
    if not found or found.group(1).lower() == "null":
        return None
    return found.group(1)


def _declared_domains():
    """各 docs/spec/*/domain-map.md 宣告的 domain 集合；無任何 map 時為空集合。"""
    found = (_frontmatter_domain(m.read_text(encoding="utf-8")) for m in _list_domain_maps())
    return {d for d in found if d}


def is_layer_spec(spec_text):
    """SPEC 的 domain 欄非任何已宣告 DomainBundle 的 domain，即為層級 SPEC（以系統層判定）。

    domain 欄未填、或專案無任何已宣告 domain（單 domain 專案）時不適用。
    """
    domain = _frontmatter_domain(spec_text)
    declared = _declared_domains()
    return bool(domain and declared and domain not in declared)


def layer_banner(spec_text):
    """走系統層時印出判定依據：SPEC 的 domain 欄值與已宣告 domain 集合（供人眼比對錯字）。"""
    declared = ", ".join(sorted(_declared_domains()))
    return (
        f"domain 覆蓋檢核：無任何 map 列入本 SPEC，其 domain 欄 {_frontmatter_domain(spec_text)!r} "
        f"不在已宣告 domain 集合 [{declared}]，視為層級 SPEC，以系統層判定"
    )


def describe_missing_system_layer():
    return (
        "domain 覆蓋檢核：本 SPEC 的 domain 欄不是任何已宣告的 domain（層級 SPEC），"
        f"以系統層 {SYSTEM_LAYER_PATH} 判定，但該檔不存在。"
    )


def _read_maps(paths):
    """逐檔讀取，回傳 [(檔名, 內容)]；不串接，供集合層聯集。"""
    return [(str(p), p.read_text(encoding="utf-8")) for p in paths]


DECLARATION_KEY = "has_functional_requirements"
DECLARATION_LINE_RE = re.compile(rf"^{DECLARATION_KEY}:[ \t]*(.*?)[ \t]*$", re.MULTILINE)
# 矛盾檢查比抽取規則寬：任何標題行文字以 FR 開頭（不分大小寫，含 FR01、FR 01、fr-01、
# 全形連字號、en dash）；NFR 開頭與 FRAME 之類字母續接者不命中。
LOOSE_FR_HEADING_RE = re.compile(r"^#{1,6}[ \t]*FR(?![A-Za-z]).*$", re.MULTILINE | re.IGNORECASE)
EXPECTED_HEADING_HINT = (
    "預期標題樣式：`### FR-NN: 標題` 或 `### FR-NN：標題`（H3 以上，半形或全形冒號）；"
    f"若本 SPEC 確實無 FR，請於 frontmatter 宣告 `{DECLARATION_KEY}: false`。"
)


def read_fr_declaration(spec_text):
    """回傳 frontmatter 的 has_functional_requirements：True/False；未填回 True；非布林拋 ValueError。"""
    block = FRONTMATTER_BLOCK_RE.match(spec_text)
    found = DECLARATION_LINE_RE.search(block.group(1)) if block else None
    if not found:
        return True
    raw = re.sub(r"\s+#.*$", "", found.group(1))
    if raw in ("true", "false"):
        return raw == "true"
    raise ValueError(f"{DECLARATION_KEY} 須為布林 true/false，實得 {raw!r}")


def _body_without_frontmatter(spec_text):
    block = FRONTMATTER_BLOCK_RE.match(spec_text)
    return spec_text[block.end():] if block else spec_text


def judge_fr_declaration(spec_text):
    """於 domain map 定位之前判定。回傳 exit code（已結束）或 None（續行覆蓋比對）。"""
    try:
        declared = read_fr_declaration(spec_text)
    except ValueError as exc:
        print(f"domain 覆蓋檢核失敗：{exc}（未填視同 true；非布林不當作 false）")
        return 1
    extracted = extract_spec_frs(spec_text)
    if declared is False:
        loose = LOOSE_FR_HEADING_RE.findall(_body_without_frontmatter(spec_text))
        if extracted or loose:
            print(f"domain 覆蓋檢核失敗：宣告 {DECLARATION_KEY}: false，但內容存在 FR 標題行（宣告與內容矛盾）：")
            for line in loose:
                print(f"  {line.strip()}")
            return 1
        print(f"本 SPEC 宣告無 FR（{DECLARATION_KEY}: false），未執行覆蓋比對")
        return 0
    if not extracted:
        print("domain 覆蓋檢核失敗：未宣告無 FR，但未抽到任何 FR 標題（未執行覆蓋比對）。")
        print(EXPECTED_HEADING_HINT)
        return 1
    return None


def check_layer_coverage(spec_text, system_text, spec_path=None):
    """層級模式：只以該 SPEC 在系統層的歸屬比對，不走相容後備；取不到 SPEC 識別則全部未覆蓋。"""
    spec_frs = extract_spec_frs(spec_text)
    spec_id = extract_spec_id(spec_text, spec_path)
    if spec_id is None:
        return sorted(spec_frs)
    attributed, _ = extract_fr_attribution(system_text)
    return sorted(spec_frs - attributed.get(spec_id, set()))


def _report_domain_coverage(spec_text, domain_map_paths, spec_path=None, layer_mode=False):
    """列印 FR->bundle 覆蓋檢核結果，回傳 exit code。"""
    domain_map_path = ", ".join(str(p) for p in domain_map_paths)
    if layer_mode:
        uncovered = check_layer_coverage(spec_text, domain_map_paths[0].read_text(encoding="utf-8"), spec_path)
    else:
        uncovered = check_domain_coverage_union(spec_text, _read_maps(domain_map_paths), spec_path)
    if not uncovered:
        print(f"domain 覆蓋檢核通過：spec 全部 FR 皆在 {domain_map_path} 有 bundle 歸屬")
        return 0

    print(f"domain 覆蓋檢核發現 {len(uncovered)} 個 FR 未在 domain map 覆蓋：")
    for fr in uncovered:
        print(f"  FR-{fr:02d}")
    if layer_mode:
        print(f"（系統層：{domain_map_path}）層級 SPEC 以系統層判定，請於系統層的 FR 對照節逐條列出歸屬。")
        return 1
    print(f"（domain map：{domain_map_path}）請於 domain map §7 FR->bundle 覆蓋表補上歸屬。")
    return 1


def _report_event_flow_labeling(spec_text, domain_map_paths):
    """列印事件流標定檢核結果，回傳 exit code。性質為啟發式提醒，非阻擋。"""
    domain_map_path = ", ".join(str(p) for p in domain_map_paths)
    missing = check_event_flow_labeling_union(
        spec_text, [t for _, t in _read_maps(domain_map_paths)])
    if not missing:
        print("事件流標定檢核通過：命中事件流訊號詞的 FR 皆在通道與協調圖節有到達類別與級別標定")
        return 0

    print(f"事件流標定檢核發現 {len(missing)} 個 FR 命中事件流訊號詞但未見通道標定（提醒，非阻擋）：")
    for fr in missing:
        print(f"  FR-{fr:02d}")
    print(f"（domain map：{domain_map_path}）請於「通道與協調圖」節之「到達類別與級別實例」子表補上標定。")
    return 1


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="spec check-domain-coverage",
        description="檢查 spec 的每個 FR 是否被 domain map 的 FR->bundle 覆蓋表歸屬",
    )
    parser.add_argument("spec_path", help="Spec 文件路徑")
    parser.add_argument("--domain-map", help="domain map 路徑（省略則自動定位）")
    parser.add_argument(
        "--check-event-flow-labeling",
        action="store_true",
        help="額外執行事件流標定檢核（可選，啟發式提醒，非阻擋）",
    )
    args = parser.parse_args(argv)

    spec_path = Path(args.spec_path)
    spec_text = spec_path.read_text(encoding="utf-8")

    early = judge_fr_declaration(spec_text)
    if early is not None:
        return early

    if args.domain_map == "":
        print("domain 覆蓋檢核：--domain-map 指定的檔案不存在：''（空字串不視為未帶旗標）")
        return 1
    domain_map_paths = locate_domain_maps(spec_path, args.domain_map, extract_spec_id(spec_text, spec_path))
    # 層級判定只在原定位鏈找不到任何 map、且 domain 欄非已宣告 domain 時成立；
    # 有 map 時照原鏈，無 map 但 domain 欄為已宣告 domain 是漏登記，維持紅
    layer_mode = not domain_map_paths and args.domain_map is None and is_layer_spec(spec_text)
    if layer_mode:
        print(layer_banner(spec_text))
        if not SYSTEM_LAYER_PATH.exists():
            print(describe_missing_system_layer())
            return 1
        domain_map_paths = [SYSTEM_LAYER_PATH]
    if not domain_map_paths:
        print(describe_missing_map(args.domain_map))
        return 1

    rc = _report_domain_coverage(spec_text, domain_map_paths, spec_path, layer_mode)
    if args.check_event_flow_labeling:
        rc = _report_event_flow_labeling(spec_text, domain_map_paths) or rc
    return rc


if __name__ == "__main__":
    sys.exit(main())
