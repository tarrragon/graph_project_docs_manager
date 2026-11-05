"""SPEC-007 README 凍結資訊核對。"""

from __future__ import annotations

import re
from typing import Any

from spec007_extract import (  # noqa: E402
    CORPUS_FB,
    CORPUS_GPDM,
)


# ---------------------------------------------------------------------------
# README 凍結資訊核對：README 是人工同步的副本，compute 逐欄對照凍結檔
# ---------------------------------------------------------------------------

README_NAME = "README.md"
SEP_PAIR = "／"  # i18n-exempt: 開發者工具
SECTION_ENV = "## 量測環境"  # i18n-exempt: 開發者工具的 README 解析標籤
SECTION_COMPARE = "## 實測值與版本契約第 2 欄的對照"  # i18n-exempt: 開發者工具的 README 解析標籤
SECTION_OTHER = "其他實測（`real_only`）"  # i18n-exempt: 開發者工具的 README 解析標籤
SYNTHETIC_GROUP_RE = re.compile(r"節點 (\d+)、`duplicateId` (\d+)、引用值總數 (\d+)、`graphDefect` (\d+)")  # i18n-exempt: 開發者工具的 README 解析標籤
COMPARE_LABELS = ("節點數", "斷邊", "格式錯誤", "spawn 只在反向", "spawn multiSource", "provenance multiSource")  # i18n-exempt: 開發者工具的 README 解析標籤


def _section_text(text: str, start_marker: str) -> str:
    """從 start_marker 起到下一個 `## ` 標題（不含）。找不到回傳空字串。"""
    begin = text.find(start_marker)
    if begin < 0:
        return ""
    end = text.find("\n## ", begin + len(start_marker))
    return text[begin:] if end < 0 else text[begin:end]


def _table_rows(section: str) -> list[list[str]]:
    rows = []
    for line in section.splitlines():
        if line.startswith("|"):
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
    return rows


def _find_row(rows: list[list[str]], label_prefix: str, strip_ticks: bool = False) -> list[str] | None:
    for cells in rows:
        label = cells[0].replace("`", "") if strip_ticks else cells[0]
        if label.startswith(label_prefix):
            return cells
    return None


def _pair(values: tuple[Any, ...]) -> str:
    return SEP_PAIR.join(str(v) for v in values)


def _fmt_sha(sha: str) -> str:
    return f"{sha[:8]}...{sha[-6:]}"


def _spawn_reverse_only(edges_by_corpus: dict[str, Any], corpus: str) -> int:
    """spawn 邊中宣告來源只有終點者；由 expected_edges 推導（合成列不帶 spawn）。"""
    return sum(
        1 for e in edges_by_corpus[corpus] if e["edge_type"] == "spawn" and e["declared_by"] == [e["to"]]
    )


def readme_frozen_values(
    manifest: dict[str, Any], counts: dict[str, Any], edges: dict[str, Any]
) -> dict[str, str]:
    """凍結檔端的權威值，鍵為 README 欄位標籤，值一律字串。"""
    header = manifest["header"]
    values: dict[str, str] = {"env.frozen_date": header["frozen_date"]}
    pair_corpora = (CORPUS_GPDM, CORPUS_FB)
    for corpus in pair_corpora:
        snap = header["corpus_snapshots"][corpus]
        values[f"env.{corpus}.commit"] = header["corpus_commits"][corpus]["commit"]
        values[f"env.{corpus}.docs_md_files"] = str(snap["docs_md_files"])
        values[f"env.{corpus}.signature"] = _fmt_sha(snap["signature_sha256"])
    real = {c: counts[c]["real_only"] for c in pair_corpora}
    multi = {c: real[c]["multi_source_by_edge_type"] for c in pair_corpora}
    compare = {
        "節點數": [real[c]["node_count"] for c in pair_corpora],  # i18n-exempt: 開發者工具
        "斷邊": [real[c]["dangling_count"] for c in pair_corpora],  # i18n-exempt: 開發者工具
        "格式錯誤": [real[c]["malformed_count"] for c in pair_corpora],  # i18n-exempt: 開發者工具
        "spawn 只在反向": [_spawn_reverse_only(edges, c) for c in pair_corpora],  # i18n-exempt: 開發者工具
        "spawn multiSource": [multi[c].get("spawn", 0) for c in pair_corpora],
        "provenance multiSource": [multi[c].get("provenance", 0) for c in pair_corpora],
    }
    for label, pair in compare.items():
        values[f"compare.{label}"] = _pair(tuple(pair))
    for corpus, label in ((CORPUS_GPDM, "gpdm"), (CORPUS_FB, "fb")):
        r = real[corpus]
        typed = r["edges_by_type"]
        values[f"other.{label}.reference_value_total"] = str(r["reference_value_total"])
        values[f"other.{label}.resolved_dangling_malformed"] = _pair(
            (r["resolved_count"], r["dangling_count"], r["malformed_count"])
        )
        values[f"other.{label}.edge_count"] = str(r["edge_count"])
        values[f"other.{label}.typed_edges"] = _pair(
            tuple(typed.get(k, 0) for k in ("closed_by", "uc_ticket_refs", "domain_dependency"))
        )
        values[f"other.{label}.closed_by_total"] = (
            f"{r['closed_by_field_value_total']}＝{r['closed_by_reference_count']}＋{r['closed_by_skipped_count']}"  # i18n-exempt: 開發者工具
        )
        values[f"other.{label}.graph_defect_count"] = str(r["graph_defect_count"])
    full = counts[CORPUS_GPDM]
    values["synthetic_group"] = _pair(
        (full["node_count"], full["duplicate_id_count"], full["reference_value_total"], full["graph_defect_count"])
    )
    return values


def _whole_pair(cell: str, parts: int) -> str | None:
    """「a／b」或「a／b／c」且全為整數才採用；其餘（含括號說明）回傳 None 表示不核對。"""
    pieces = cell.split(SEP_PAIR)
    return cell if len(pieces) == parts and all(p.isdigit() for p in pieces) else None


def _env_claims(text: str) -> dict[str, str]:
    claims: dict[str, str] = {}
    env = _table_rows(_section_text(text, SECTION_ENV))
    date_row = _find_row(env, "凍結日期")  # i18n-exempt: 開發者工具
    found = re.search(r"\d{4}-\d{2}-\d{2}", date_row[1]) if date_row else None
    if found:
        claims["env.frozen_date"] = found.group(0)
    patterns = (
        ("commit", r"`([0-9a-f]{40})`"),
        ("docs_md_files", r"`\.md` (\d+) 檔"),  # i18n-exempt: 開發者工具
        ("signature", r"sha256 `([0-9a-f]+\.\.\.[0-9a-f]+)`"),
    )
    for corpus in (CORPUS_GPDM, CORPUS_FB):
        row = _find_row(env, corpus)
        for key, pattern in patterns:
            found = re.search(pattern, row[1]) if row else None
            if found:
                claims[f"env.{corpus}.{key}"] = found.group(1)
    return claims


OTHER_SPECS = (
    ("引用值總數", "reference_value_total", 1),  # i18n-exempt: 開發者工具
    ("解析成功", "resolved_dangling_malformed", 3),  # i18n-exempt: 開發者工具
    ("邊數", "edge_count", 1),  # i18n-exempt: 開發者工具
    ("其中", "typed_edges", 3),  # i18n-exempt: 開發者工具
    ("closed_by 欄位值總數", "closed_by_total", 0),  # i18n-exempt: 開發者工具
    ("graphDefect 總數", "graph_defect_count", 1),  # i18n-exempt: 開發者工具
)


def _other_cell_ok(cell: str, parts: int) -> bool:
    if parts == 0:
        return re.fullmatch(r"\d+＝\d+＋\d+", cell) is not None  # i18n-exempt: 開發者工具
    return cell.isdigit() if parts == 1 else _whole_pair(cell, parts) is not None


def readme_claims(text: str) -> dict[str, str]:
    """README 端宣稱值；解析不到的欄位不放入（由 check_readme 以缺漏回報）。"""
    claims = _env_claims(text)
    compare = _table_rows(_section_text(text, SECTION_COMPARE))
    for label in COMPARE_LABELS:
        row = _find_row(compare, label, strip_ticks=True)
        cell = _whole_pair(row[2], 2) if row and len(row) >= 3 else None
        if cell:
            claims[f"compare.{label}"] = cell
    other = _table_rows(_section_text(text, SECTION_OTHER))
    for prefix, key, parts in OTHER_SPECS:
        row = _find_row(other, prefix, strip_ticks=True)
        if not row or len(row) < 3:
            continue
        for label, cell in (("gpdm", row[1]), ("fb", row[2])):
            if _other_cell_ok(cell, parts):
                claims[f"other.{label}.{key}"] = cell
    group = SYNTHETIC_GROUP_RE.search(text)
    if group:
        claims["synthetic_group"] = _pair(tuple(int(g) for g in group.groups()))
    return claims


def check_readme(
    text: str, manifest: dict[str, Any], counts: dict[str, Any], edges: dict[str, Any]
) -> list[str]:
    """回傳不一致欄位說明；空清單為一致。README 缺少應有欄位也算不一致（避免解析失敗即靜默通過）。"""
    claims = readme_claims(text)
    problems = []
    for key, expected in readme_frozen_values(manifest, counts, edges).items():
        if key not in claims:
            problems.append(f"{key}: README 缺少或無法解析（凍結值 {expected}）")  # i18n-exempt: 開發者工具訊息
        elif claims[key] != expected:
            problems.append(f"{key}: README {claims[key]} != 凍結檔 {expected}")  # i18n-exempt: 開發者工具訊息
    return problems
