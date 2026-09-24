"""SPEC-006 IT-2（破洞分類）獨立 Python 參照實作。

依 SPEC-006（docs/spec/corpus/SPEC-006-corpus-parsing-and-gap-classification.md）
FR-01、FR-03、FR-04、FR-05、FR-06、FR-07 規則獨立實作，供離線產生 IT-1、IT-2
的凍結預期值使用（SPEC-006 D3）。

刻意不 import 任何 Dart 待測實作或其產物；只讀取上游 schema
（.claude/skills/doc/doc_system/core/tracking_schema.json）與（比對用途的）
框架 frontmatter_parser.py。carrier_path_patterns 的比對一律以 ASCII 語意
編譯（SPEC-006 D9：`re.ASCII`），id_pattern 依型別表 `id_pattern_dialect`
（python-re，Unicode 語意）比對，兩者比對語意刻意不同，不可混用。

本檔為開發者離線 CLI 工具，非產品 user-facing 介面。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

FRONTMATTER_DELIMITER = "---"

# FR-01 結果分類五種（不含「無法讀取」，無法讀取屬 FR-05，先於切分發生）
RESULT_USABLE = "usable"
RESULT_NO_FRONTMATTER = "no_frontmatter"
RESULT_UNCLOSED = "unclosed"
RESULT_EMPTY_OR_NON_MAP = "empty_or_non_map"
RESULT_YAML_ERROR = "yaml_error"

FR01_RESULTS = frozenset(
    {
        RESULT_USABLE,
        RESULT_NO_FRONTMATTER,
        RESULT_UNCLOSED,
        RESULT_EMPTY_OR_NON_MAP,
        RESULT_YAML_ERROR,
    }
)

# FR-05 無法讀取子原因
UNREADABLE_ENCODING = "encoding"
UNREADABLE_PERMISSION = "permission"
UNREADABLE_MISSING = "missing"

# 切分規則 2：框架 splitlines() 另外承認、本規格不承認的行分隔字元
# （僅用於樣本排除自我驗證，見 IT1-A4）
EXCLUDED_LINE_SEPARATORS = (
    "\x0b",
    "\x0c",
    "\x1c",
    "\x1d",
    "\x1e",
    "\x85",
    " ",
    " ",
)


@dataclass
class ClassifyResult:
    """FR-01 切分與分類結果。"""

    result: str
    frontmatter_text: str | None = None
    keys: list[str] | None = None
    data: dict[str, Any] | None = None
    yaml_error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "result": self.result,
            "frontmatter_text": self.frontmatter_text,
            "keys": self.keys,
        }


def split_lines_strict(text: str) -> list[str]:
    """切分規則 2：只認 `\\n` 與 `\\r\\n` 作行分隔，不含其他字元。"""
    lines = re.split(r"\r\n|\n", text)
    # 模擬 str.splitlines() 的「結尾分隔字元不產生末尾空字串」行為，
    # 使無其他特殊分隔字元的樣本與框架函式行為一致。
    if lines and lines[-1] == "":
        lines = lines[:-1]
    return lines


def strip_bom(text: str) -> str:
    """切分規則 1：檔案開頭的 UTF-8 BOM 先移除。"""
    if text.startswith("﻿"):
        return text[1:]
    return text


def contains_excluded_line_separator(text: str) -> bool:
    """IT1-A4 守衛：樣本是否含排除字元清單中的任一字元。"""
    return any(ch in text for ch in EXCLUDED_LINE_SEPARATORS)


def classify_text(text: str) -> ClassifyResult:
    """FR-01：對已讀取的檔案文字內容做切分與五類結果分類。"""
    text = strip_bom(text)
    lines = split_lines_strict(text)

    if not lines or lines[0].strip() != FRONTMATTER_DELIMITER:
        return ClassifyResult(result=RESULT_NO_FRONTMATTER)

    end_index = None
    for i in range(1, len(lines)):
        if lines[i].strip() == FRONTMATTER_DELIMITER:
            end_index = i
            break

    if end_index is None:
        return ClassifyResult(result=RESULT_UNCLOSED)

    yaml_text = "\n".join(lines[1:end_index])

    try:
        parsed = yaml.safe_load(yaml_text)
    except yaml.YAMLError as exc:
        return ClassifyResult(
            result=RESULT_YAML_ERROR, frontmatter_text=yaml_text, yaml_error=str(exc)
        )

    if isinstance(parsed, dict) and len(parsed) > 0:
        return ClassifyResult(
            result=RESULT_USABLE,
            frontmatter_text=yaml_text,
            keys=sorted(parsed.keys()),
            data=parsed,
        )

    return ClassifyResult(result=RESULT_EMPTY_OR_NON_MAP, frontmatter_text=yaml_text)


def naive_split_classify(text: str) -> tuple[int | None, bool]:
    """判別樣本用：天真語意 `split("---")` 解析，回傳 (鍵數或 None, 是否 YAML 錯誤)。"""
    parts = text.split(FRONTMATTER_DELIMITER)
    if len(parts) < 3:
        return None, False
    candidate = parts[1]
    try:
        parsed = yaml.safe_load(candidate)
    except yaml.YAMLError:
        return None, True
    if isinstance(parsed, dict):
        return len(parsed), False
    return None, False


@dataclass
class ReadResult:
    """FR-05：讀取結果，`text` 為 None 時 `reason` 必為 FR-05 三個子原因之一。"""

    text: str | None
    reason: str | None = None


def read_file(path: Path) -> ReadResult:
    """FR-05：讀取檔案內容，區分編碼／權限／檔案消失三個子原因。

    不做寬鬆解碼（規則明寫：不以寬鬆解碼繼續解析）。
    """
    try:
        raw = path.read_bytes()
    except FileNotFoundError:
        return ReadResult(text=None, reason=UNREADABLE_MISSING)
    except PermissionError:
        return ReadResult(text=None, reason=UNREADABLE_PERMISSION)

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return ReadResult(text=None, reason=UNREADABLE_ENCODING)

    return ReadResult(text=text)


# ---------------------------------------------------------------------------
# FR-06：路徑對型別查詢（Schema 公開面）
# ---------------------------------------------------------------------------


@dataclass
class PathTypeQueryResult:
    """FR-06 規則 5：未命中／命中一型／平手 三選一。"""

    kind: str  # "miss" | "hit" | "tie" | "unavailable"
    node_type: str | None = None
    candidate_types: list[str] = field(default_factory=list)
    schema_ambiguous: bool = False


class SchemaTypeTable:
    """依 tracking_schema.json 建構的路徑對型別查詢器（FR-06）。"""

    def __init__(self, node_types: dict[str, Any]):
        self._compiled: dict[str, list[tuple[re.Pattern[str], tuple[int, int]]]] = {}
        self._id_patterns: dict[str, re.Pattern[str]] = {}
        self.available = False

        for type_name, definition in node_types.items():
            id_pattern = definition.get("id_pattern")
            if id_pattern:
                # id_pattern_dialect: python-re（Unicode 語意），與 carrier 路徑比對
                # 的 ASCII 語意刻意不同（D9 只限定 carrier_path_patterns）。
                self._id_patterns[type_name] = re.compile(id_pattern)

            patterns = definition.get("carrier_path_patterns")
            # FR-06 規則 3：依欄位是否存在判定是否參與比對，不依型別名。
            if patterns is None:
                continue
            self.available = True
            compiled_list = []
            for element in patterns:
                specificity = tuple(element["specificity"])
                # D9：carrier 路徑模式以 ASCII 語意編譯。
                compiled = re.compile(element["pattern"], re.ASCII)
                compiled_list.append((compiled, specificity))
            self._compiled[type_name] = compiled_list

    def query_path(self, relative_path: str) -> PathTypeQueryResult:
        """FR-06：給相對路徑，回傳命中型別（未命中／一型／平手）。"""
        if not self.available:
            return PathTypeQueryResult(kind="unavailable")

        hits: list[tuple[str, tuple[int, int]]] = []
        for type_name, compiled_list in self._compiled.items():
            best_for_type: tuple[int, int] | None = None
            for compiled, specificity in compiled_list:
                if compiled.match(relative_path):
                    # 規則 6 段落備註：同型多元素命中時取最高具體度者參與比較。
                    if best_for_type is None or specificity > best_for_type:
                        best_for_type = specificity
            if best_for_type is not None:
                hits.append((type_name, best_for_type))

        if not hits:
            return PathTypeQueryResult(kind="miss")

        if len(hits) == 1:
            return PathTypeQueryResult(kind="hit", node_type=hits[0][0])

        # 規則 6：先比字面段數（多者優先），再比跨段萬用成分數（少者優先）。
        max_specificity = max(spec for _, spec in hits)
        top = [name for name, spec in hits if spec == max_specificity]
        if len(top) == 1:
            return PathTypeQueryResult(kind="hit", node_type=top[0])

        return PathTypeQueryResult(
            kind="tie", candidate_types=sorted(top), schema_ambiguous=True
        )

    def match_id(self, node_id: str) -> PathTypeQueryResult:
        """FR-03：以 `id` 比對各型別 `id_pattern`，回傳未命中／一型／多型衝突。"""
        hits = [
            type_name
            for type_name, pattern in self._id_patterns.items()
            if pattern.match(node_id)
        ]
        if not hits:
            return PathTypeQueryResult(kind="miss")
        if len(hits) == 1:
            return PathTypeQueryResult(kind="hit", node_type=hits[0])
        return PathTypeQueryResult(
            kind="tie", candidate_types=sorted(hits), schema_ambiguous=True
        )


def load_type_table(schema_json_path: Path) -> SchemaTypeTable:
    with schema_json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return SchemaTypeTable(data["node_types"])


# ---------------------------------------------------------------------------
# 逐檔分類（整合 FR-01, FR-03, FR-04, FR-05, FR-06）
# ---------------------------------------------------------------------------

FAILURE_REASON_MAP = {
    RESULT_NO_FRONTMATTER: "no_frontmatter",
    RESULT_UNCLOSED: "unclosed",
    RESULT_EMPTY_OR_NON_MAP: "empty_or_non_map",
    RESULT_YAML_ERROR: "yaml_error",
}


@dataclass
class FileClassification:
    relative_path: str
    kind: str  # "node" | "non_node" | "gap" | "failure_unmatched" | "failure_unjudged"
    node_type: str | None = None
    candidate_types: list[str] = field(default_factory=list)
    schema_ambiguous: bool = False
    reason: str | None = None  # FR-01 四類 或 "unreadable_encoding" 等


def classify_file(
    workspace_root: Path, absolute_path: Path, type_table: SchemaTypeTable
) -> FileClassification:
    """整合 FR-01～FR-06，對單一檔案產生分類結果。"""
    relative_path = absolute_path.relative_to(workspace_root).as_posix()

    read_result = read_file(absolute_path)
    if read_result.text is None:
        reason = f"unreadable_{read_result.reason}"
        return _classify_failure(relative_path, reason, type_table)

    classified = classify_text(read_result.text)

    if classified.result == RESULT_USABLE:
        node_id = classified.data.get("id") if classified.data else None
        if not isinstance(node_id, str):
            return FileClassification(relative_path=relative_path, kind="non_node")
        id_result = type_table.match_id(node_id)
        if id_result.kind == "hit":
            return FileClassification(
                relative_path=relative_path, kind="node", node_type=id_result.node_type
            )
        if id_result.kind == "tie":
            return FileClassification(
                relative_path=relative_path,
                kind="non_node",
                candidate_types=id_result.candidate_types,
                schema_ambiguous=True,
            )
        return FileClassification(relative_path=relative_path, kind="non_node")

    reason = FAILURE_REASON_MAP[classified.result]
    return _classify_failure(relative_path, reason, type_table)


def _classify_failure(
    relative_path: str, reason: str, type_table: SchemaTypeTable
) -> FileClassification:
    query = type_table.query_path(relative_path)
    if query.kind == "unavailable":
        return FileClassification(
            relative_path=relative_path, kind="failure_unjudged", reason=reason
        )
    if query.kind == "miss":
        return FileClassification(
            relative_path=relative_path, kind="failure_unmatched", reason=reason
        )
    if query.kind == "hit":
        return FileClassification(
            relative_path=relative_path,
            kind="gap",
            node_type=query.node_type,
            reason=reason,
        )
    # tie
    return FileClassification(
        relative_path=relative_path,
        kind="gap",
        candidate_types=query.candidate_types,
        schema_ambiguous=True,
        reason=reason,
    )


# ---------------------------------------------------------------------------
# FR-02 掃描範圍：workspace 下 docs/ 內遞迴 .md（不追符號連結，副檔名小寫）
# ---------------------------------------------------------------------------


def scan_markdown_files(workspace_root: Path) -> list[Path]:
    """FR-02：掃描 `docs/` 下所有小寫 `.md`，不追符號連結。"""
    import os

    docs_dir = workspace_root / "docs"
    if not docs_dir.is_dir():
        return []

    results: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(docs_dir, followlinks=False):
        dirnames[:] = [d for d in dirnames if not (Path(dirpath) / d).is_symlink()]
        for name in filenames:
            file_path = Path(dirpath) / name
            if file_path.is_symlink():
                continue
            if name[-3:] == ".md":
                results.append(file_path)
    return results


# ---------------------------------------------------------------------------
# 單元測試（内嵌，`python3 tool/spec006_reference.py selftest` 執行）
#
# 未落地為獨立 test/ 檔案：本票 where.files 未列出額外測試檔路徑，改以內嵌
# selftest 子命令滿足「參照實作附單元測試並全綠」的驗收條件，詳見
# test/fixtures/spec006/README.md 偏離說明。
# ---------------------------------------------------------------------------


def _make_test_type_table() -> SchemaTypeTable:
    node_types = {
        "Alpha": {
            "carrier_path_patterns": [
                {"pattern": r"^docs/alpha/[^/]+\.md$", "specificity": [2, 0]}
            ],
            "id_pattern": "^ALPHA-\\d+$",
        },
        "Beta": {
            "carrier_path_patterns": [
                {"pattern": r"^docs/alpha/x\.md$", "specificity": [2, 0]}
            ],
            "id_pattern": "^BETA-\\d+$",
        },
        "NoPathType": {
            # 不帶 carrier_path_patterns：FR-06 規則 3，不參與路徑比對
            "id_pattern": "^NOPATH-\\d+$",
        },
    }
    return SchemaTypeTable(node_types)


def _run_selftests() -> None:
    failures: list[str] = []

    def check(name: str, condition: bool) -> None:
        if not condition:
            failures.append(name)

    # --- FR-01：切分規則與五類結果 ---
    check(
        "usable-basic",
        classify_text("---\nid: X\ntitle: y\n---\nbody").result == RESULT_USABLE,
    )
    check(
        "no-frontmatter",
        classify_text("# heading\nbody").result == RESULT_NO_FRONTMATTER,
    )
    check(
        "unclosed",
        classify_text("---\nid: X\n").result == RESULT_UNCLOSED,
    )
    check(
        "empty-map",
        classify_text("---\n---\nbody").result == RESULT_EMPTY_OR_NON_MAP,
    )
    check(
        "list-not-map",
        classify_text("---\n- a\n- b\n---\nbody").result == RESULT_EMPTY_OR_NON_MAP,
    )
    check(
        "scalar-not-map",
        classify_text("---\nhello\n---\nbody").result == RESULT_EMPTY_OR_NON_MAP,
    )
    check(
        "yaml-error",
        classify_text('---\nkey: "unterminated\n---\nbody').result == RESULT_YAML_ERROR,
    )
    check(
        "bom-stripped",
        classify_text("﻿---\nid: X\n---\nbody").result == RESULT_USABLE,
    )
    check(
        "quoted-table-not-truncated",
        classify_text('---\nid: X\ntitle: "|---|---|"\nfoo: bar\n---\nbody').keys
        == ["foo", "id", "title"],
    )
    check(
        "delimiter-line-whitespace-stripped",
        classify_text("  ---  \nid: X\n---\nbody").result == RESULT_USABLE,
    )
    check(
        "trailing-whitespace-tolerated",
        classify_text("---  \nid: X\n---  \nbody").result == RESULT_USABLE,
    )

    # --- 切分規則 2：只認 \n 與 \r\n ---
    check(
        "crlf-equivalent",
        classify_text("---\r\nid: X\r\n---\r\nbody").keys
        == classify_text("---\nid: X\n---\nbody").keys,
    )
    check(
        "excluded-separator-not-linebreak",
        "\x0c" in (classify_text("---\nid: X\x0cY\n---\nbody").frontmatter_text or ""),
    )
    check(
        "excluded-separator-detector-positive",
        contains_excluded_line_separator("a b"),
    )
    check(
        "excluded-separator-detector-negative",
        not contains_excluded_line_separator("a\nb\r\nc"),
    )

    # --- naive split 判別力 ---
    naive_keys, naive_err = naive_split_classify(
        '---\nid: X\ntitle: "|---|---|"\n---\nbody'
    )
    check("naive-split-has-lower-fidelity", naive_err or (naive_keys or 0) < 2)

    # --- FR-06：路徑對型別查詢 ---
    tt = _make_test_type_table()
    check("path-hit-alpha", tt.query_path("docs/alpha/y.md").kind == "hit")
    check(
        "path-hit-alpha-type",
        tt.query_path("docs/alpha/y.md").node_type == "Alpha",
    )
    check("path-miss", tt.query_path("docs/other/y.md").kind == "miss")
    tie = tt.query_path("docs/alpha/x.md")
    check("path-tie-kind", tie.kind == "tie")
    check(
        "path-tie-candidates",
        sorted(tie.candidate_types) == ["Alpha", "Beta"],
    )
    check("path-tie-ambiguous-flag", tie.schema_ambiguous is True)
    check(
        "path-case-sensitive",
        tt.query_path("docs/Alpha/y.md").kind == "miss",
    )
    check(
        "nopathtype-excluded",
        "NoPathType" not in tt._compiled,
    )

    # --- FR-06 規則 2：ASCII 語意（全形數字不命中 \d） ---
    ascii_tt = SchemaTypeTable(
        {
            "Digit": {
                "carrier_path_patterns": [
                    {"pattern": r"^docs/n/\d+\.md$", "specificity": [2, 0]}
                ]
            }
        }
    )
    check(
        "ascii-digit-matches-ascii",
        ascii_tt.query_path("docs/n/123.md").kind == "hit",
    )
    check(
        "ascii-digit-rejects-fullwidth",
        ascii_tt.query_path("docs/n/１２３.md").kind == "miss",
    )

    # --- FR-03：id_pattern 判型（互斥、多型衝突） ---
    id_tt = SchemaTypeTable(
        {
            "One": {"id_pattern": "^ONE-\\d+$"},
            "Two": {"id_pattern": "^TWO-\\d+$"},
        }
    )
    check("id-hit-one", id_tt.match_id("ONE-1").node_type == "One")
    check("id-miss", id_tt.match_id("THREE-1").kind == "miss")
    clash_tt = SchemaTypeTable(
        {
            "One": {"id_pattern": "^X-1$"},
            "Two": {"id_pattern": "^X-1$"},
        }
    )
    clash = clash_tt.match_id("X-1")
    check("id-clash-tie", clash.kind == "tie")
    check("id-clash-ambiguous", clash.schema_ambiguous is True)

    # --- FR-06 規則 6：具體度二層比較 ---
    spec_tt = SchemaTypeTable(
        {
            "MoreLiteral": {
                "carrier_path_patterns": [
                    {"pattern": r"^docs/spec/[^/]+/x\.md$", "specificity": [3, 0]}
                ]
            },
            "FewerLiteral": {
                "carrier_path_patterns": [
                    {"pattern": r"^docs/spec/.+\.md$", "specificity": [1, 1]}
                ]
            },
        }
    )
    check(
        "specificity-more-literal-wins",
        spec_tt.query_path("docs/spec/corpus/x.md").node_type == "MoreLiteral",
    )

    # --- FR-05：讀取失敗子原因 ---
    import tempfile

    with tempfile.TemporaryDirectory() as d:
        missing = Path(d) / "missing.md"
        check("read-missing", read_file(missing).reason == UNREADABLE_MISSING)

        bad_enc = Path(d) / "bad.md"
        bad_enc.write_bytes(b"\xff\xfe\x00broken")
        check("read-encoding-error", read_file(bad_enc).reason == UNREADABLE_ENCODING)

        ok_file = Path(d) / "ok.md"
        ok_file.write_text("---\nid: X\n---\nbody", encoding="utf-8")
        check("read-ok", read_file(ok_file).text is not None)

    # --- FR-02：掃描範圍 ---
    import tempfile as _tempfile

    with _tempfile.TemporaryDirectory() as d2:
        root = Path(d2)
        check("scan-no-docs-dir", scan_markdown_files(root) == [])

        (root / "docs" / "a" / "b").mkdir(parents=True)
        (root / "docs" / "a" / "b" / "x.md").write_text("x")
        (root / "docs" / "X.MD").write_text("x")
        (root / "README.md").write_text("x")
        found = scan_markdown_files(root)
        check("scan-recursive-lowercase-only", len(found) == 1)
        check(
            "scan-relative-lowercase-match",
            found[0].name == "x.md",
        )

    # --- FR-04/整合：classify_file 端到端 ---
    with _tempfile.TemporaryDirectory() as d3:
        root = Path(d3)
        (root / "docs" / "spec" / "corpus").mkdir(parents=True)
        gap_file = root / "docs" / "spec" / "corpus" / "domain-map.md"
        gap_file.write_text("# no frontmatter\nbody", encoding="utf-8")
        real_tt = load_type_table(
            Path(__file__).resolve().parent.parent
            / ".claude"
            / "skills"
            / "doc"
            / "doc_system"
            / "core"
            / "tracking_schema.json"
        )
        classification = classify_file(root, gap_file, real_tt)
        check("classify-gap-domainbundle", classification.kind == "gap")
        check(
            "classify-gap-node-type",
            classification.node_type == "DomainBundle",
        )

        node_file = root / "docs" / "spec" / "corpus" / "SPEC-777-x.md"
        node_file.write_text("---\nid: SPEC-777\ntitle: t\n---\nbody", encoding="utf-8")
        node_classification = classify_file(root, node_file, real_tt)
        check("classify-node-kind", node_classification.kind == "node")
        check("classify-node-type", node_classification.node_type == "SPEC")

    if failures:
        print(f"SELFTEST FAILED: {len(failures)} 項未通過")
        for name in failures:
            print(f"  - {name}")
        raise SystemExit(1)

    print("SELFTEST PASSED: 全部通過")  # i18n-exempt


# ---------------------------------------------------------------------------
# CLI：離線產生 IT-1 / IT-2 凍結測資用
# ---------------------------------------------------------------------------


def _cmd_scan(args: argparse.Namespace) -> None:
    schema_path = Path(args.schema)
    type_table = load_type_table(schema_path)
    workspace_root = Path(args.workspace).resolve()
    files = scan_markdown_files(workspace_root)

    records = []
    for path in files:
        classification = classify_file(workspace_root, path, type_table)
        records.append(
            {
                "path": classification.relative_path,
                "kind": classification.kind,
                "node_type": classification.node_type,
                "candidate_types": classification.candidate_types,
                "schema_ambiguous": classification.schema_ambiguous,
                "reason": classification.reason,
            }
        )

    print(json.dumps(records, ensure_ascii=False, indent=2))


# 五個框架語料專案（SPEC-006 D3；與 docs/domain-map.md §7 量測範圍一致）。
# 只用於 freeze 子命令（離線一次性重建凍結測資），main scan 子命令不依賴此常數。
CORPUS_PROJECTS = (
    "flutter_balance",
    "book_overview_app",
    "book_overview_v1",
    "monitor",
    "screen_clock",
)


def _augmented_type_table(schema_path: Path) -> tuple[SchemaTypeTable, dict[str, Any]]:
    """載入真實 node_types，附加測試專用合成型別（SyntheticTie、ClashB）。

    合成型別的模式刻意設計為只命中特定合成路徑／id，不影響真實語料掃描結果
    （見 `tool/tests`〈freeze-it2 header note〉與 README 產生指令說明）。
    """
    with schema_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    node_types = dict(data["node_types"])
    node_types["SyntheticTie"] = {
        "carrier": "synthetic test-only type for tie-break fixture",
        "carrier_path_patterns": [
            {"pattern": r"^docs/proposals/PROP-\d{3}-tie\.md$", "specificity": [2, 0]}
        ],
        "id_pattern": "^SYNTHETIC-TIE-[0-9]+$",
        "layer": "proposed",
    }
    node_types["ClashB"] = {
        "carrier": "synthetic test-only type for id_pattern clash fixture",
        "id_pattern": "^SPEC-999$",
        "layer": "proposed",
    }
    return SchemaTypeTable(node_types), {
        "node_types": node_types,
        "schema_generated_at_framework_version": data["schema_generated_at_framework_version"],
    }


def _synthetic_it2_rows() -> list[dict[str, Any]]:
    """IT-2 合成補充列：只補語料掃描結果中缺席的類別（見 README 樣本覆蓋表）。"""

    def row(path, shape, id_=None, kind=None, node_type=None, candidate_types=None,
            schema_ambiguous=False, reason=None):
        return {
            "path": path,
            "project": "synthetic",
            "shape": shape,
            "id": id_,
            "expected": {
                "kind": kind,
                "node_type": node_type,
                "candidate_types": candidate_types or [],
                "schema_ambiguous": schema_ambiguous,
                "reason": reason,
            },
            "synthetic": True,
            "source": None,
        }

    return [
        row("docs/work-logs/v0/v0.1/tickets/0.1.0-W1-999.md", "unclosed",
            kind="gap", node_type="Ticket", reason="unclosed"),
        row("docs/proposals/PROP-999-synthetic.md", "empty_or_non_map",
            kind="gap", node_type="PROP", reason="empty_or_non_map"),
        row("docs/usecases/UC-99-synthetic.md", "unreadable_encoding",
            kind="gap", node_type="UC", reason="unreadable_encoding"),
        row("docs/proposals/PROP-998-tie.md", "no_frontmatter",
            kind="gap", candidate_types=["PROP", "SyntheticTie"],
            schema_ambiguous=True, reason="no_frontmatter"),
        row("docs/spec/corpus/id-clash-synthetic.md", "usable", id_="SPEC-999",
            kind="non_node", candidate_types=["ClashB", "SPEC"], schema_ambiguous=True),
        # 多型別命中、依具體度分出型別的失敗檔（0.3.0-W3-530）：路徑同時命中
        # DomainBundle（specificity [3, 0]）與 SPEC（specificity [2, 0]），
        # 具體度不同故非平手，query_path 回傳 "hit"（node_type=DomainBundle，
        # candidate_types 空、schema_ambiguous=False），與平手列（schema_ambiguous
        # =True）刻意區分。
        row("docs/spec/synthetic-domain/domain-map.md", "no_frontmatter",
            kind="gap", node_type="DomainBundle", reason="no_frontmatter"),
    ]


def _classify_row_shape(classification: FileClassification) -> str:
    """FR-01 五類 或「unreadable_*」三類 或 usable（node/non_node）。"""
    if classification.kind in ("node", "non_node"):
        return "usable"
    return classification.reason


def _cmd_freeze_it2(args: argparse.Namespace) -> None:
    """SPEC-006 D3：全量掃描五個語料專案，凍結 IT-2 manifest（含合成補充列）。

    離線一次性執行（`python3 tool/spec006_reference.py freeze-it2`），輸出寫入
    `test/fixtures/spec006/it2/manifest.json`；CI 不重跑本命令。
    """
    repo_root = Path(__file__).resolve().parent.parent
    schema_path = repo_root / ".claude" / "skills" / "doc" / "doc_system" / "core" / "tracking_schema.json"
    type_table, type_table_snapshot = _augmented_type_table(schema_path)

    rows: list[dict[str, Any]] = []
    for project in CORPUS_PROJECTS:
        root = Path.home() / "project" / project
        for f in scan_markdown_files(root):
            classification = classify_file(root, f, type_table)
            rows.append(
                {
                    "path": f"{project}/{classification.relative_path}",
                    "project": project,
                    "shape": _classify_row_shape(classification),
                    "id": None,
                    "expected": {
                        "kind": classification.kind,
                        "node_type": classification.node_type,
                        "candidate_types": classification.candidate_types,
                        "schema_ambiguous": classification.schema_ambiguous,
                        "reason": classification.reason,
                    },
                    "synthetic": False,
                    "source": f"corpus:{project}/{classification.relative_path}",
                }
            )

    rows.extend(_synthetic_it2_rows())

    node_count = sum(1 for r in rows if r["expected"]["kind"] == "node")
    non_node_count = sum(1 for r in rows if r["expected"]["kind"] == "non_node")
    gap_count = sum(1 for r in rows if r["expected"]["kind"] == "gap")
    unmatched_count = sum(1 for r in rows if r["expected"]["kind"] == "failure_unmatched")
    unjudged_count = sum(1 for r in rows if r["expected"]["kind"] == "failure_unjudged")
    reason_counts: dict[str, int] = {}
    for r in rows:
        if r["shape"] != "usable":
            reason_counts[r["shape"]] = reason_counts.get(r["shape"], 0) + 1

    total_files = len(rows)
    assert total_files == node_count + non_node_count + sum(reason_counts.values())
    assert sum(reason_counts.values()) == gap_count + unmatched_count + unjudged_count

    header = {
        "frozen_date": "2026-09-24",
        "reference_impl": "tool/spec006_reference.py",
        "corpus_projects": list(CORPUS_PROJECTS),
        "schema_generated_at_framework_version": type_table_snapshot[
            "schema_generated_at_framework_version"
        ],
        "type_table_note": (
            "real tracking_schema.json node_types plus two test-only synthetic "
            "types: SyntheticTie (tie-break vs PROP), ClashB (id_pattern clash "
            "vs SPEC-999); neither pattern matches any real corpus path/id"
        ),  # i18n-exempt
        "type_table": type_table_snapshot["node_types"],
        "expected_counts": {
            "total_files": total_files,
            "real_files": total_files - len(_synthetic_it2_rows()),
            "synthetic_files": len(_synthetic_it2_rows()),
            "node_count": node_count,
            "non_node_count": non_node_count,
            "failure_reason_counts": reason_counts,
            "gap_count": gap_count,
            "unmatched_count": unmatched_count,
            "unjudged_count": unjudged_count,
        },
        "conservation_check_1": "total_files == node_count + non_node_count + sum(failure_reason_counts.values())",
        "conservation_check_2": "sum(failure_reason_counts.values()) == gap_count + unmatched_count + unjudged_count",
    }

    out = {"header": header, "rows": rows}
    out_path = repo_root / "test" / "fixtures" / "spec006" / "it2" / "manifest.json"
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"wrote {len(rows)} rows to {out_path}")  # i18n-exempt
    print(json.dumps(header["expected_counts"], ensure_ascii=False, indent=2))


_IT1_SYNTHETIC_SAMPLES: dict[str, dict[str, str]] = {
    "IT1-S1": {"content": "﻿---\nid: SPEC-TEST-001\ntitle: bom sample\n---\nbody\n", "expected_result": RESULT_USABLE},
    "IT1-S2": {"content": "---\nid: SPEC-TEST-002\ntitle: unclosed\n", "expected_result": RESULT_UNCLOSED},
    "IT1-S3": {"content": "---\n---\nbody\n", "expected_result": RESULT_EMPTY_OR_NON_MAP},
    "IT1-S4": {"content": "---\n# just a comment\n---\nbody\n", "expected_result": RESULT_EMPTY_OR_NON_MAP},
    "IT1-S5": {"content": "---\n{}\n---\nbody\n", "expected_result": RESULT_EMPTY_OR_NON_MAP},
    "IT1-S6": {"content": "---\n- a\n- b\n---\nbody\n", "expected_result": RESULT_EMPTY_OR_NON_MAP},
    "IT1-S7": {"content": "# no frontmatter\nbody text\n", "expected_result": RESULT_NO_FRONTMATTER},
    "IT1-S8": {"content": "---\r\nid: SPEC-TEST-008\r\ntitle: crlf sample\r\n---\r\nbody\r\n", "expected_result": RESULT_USABLE},
}


def _frontmatter_prefix_text(text: str) -> str:
    """回傳只到閉合 `---` 行為止的字首（含該行），用於控制 IT-1 樣本體積。

    天真語意 `split("---")` 的 parts[1] 由文字中前兩次出現的 "---" 界定，
    截斷內容之後的部分不改變前兩次出現的位置，故截斷後天真切分與逐行語意
    的比對結果與截斷前相同（SPEC-006 D3「IT-1 樣本」段落備註）。
    """
    text_for_search = strip_bom(text)
    lines_search = text_for_search.splitlines(keepends=True)
    if not lines_search or lines_search[0].strip() != FRONTMATTER_DELIMITER:
        return text
    end_idx = None
    for i in range(1, len(lines_search)):
        if lines_search[i].strip() == FRONTMATTER_DELIMITER:
            end_idx = i
            break
    if end_idx is None:
        return text
    lines_original = text.splitlines(keepends=True)
    return "".join(lines_original[: end_idx + 1])


def _cmd_freeze_it1(args: argparse.Namespace) -> None:
    """SPEC-006 D3：掃描五個語料專案的全部可用檔案，收錄天真切分與逐行語意
    結果不同的全部真實檔案（僅存 frontmatter 段以控制體積），加上 S1~S8 合成樣本。

    離線一次性執行（`python3 tool/spec006_reference.py freeze-it1`），輸出寫入
    `test/fixtures/spec006/it1/expected.json`；CI 不重跑本命令。
    """
    import tempfile

    repo_root = Path(__file__).resolve().parent.parent
    fp_module_dir = (
        repo_root / ".claude" / "skills" / "doc" / "doc_system" / "core"
    )
    sys.path.insert(0, str(fp_module_dir))
    import frontmatter_parser as fp  # noqa: E402  （動態路徑注入後才能匯入）

    records: list[dict[str, Any]] = []
    usable_scanned = 0
    excluded_sep_count = 0

    for project in CORPUS_PROJECTS:
        root = Path.home() / "project" / project
        for f in scan_markdown_files(root):
            rr = read_file(f)
            if rr.text is None:
                continue
            cls = classify_text(rr.text)
            if cls.result != RESULT_USABLE:
                continue
            usable_scanned += 1
            if contains_excluded_line_separator(rr.text):
                excluded_sep_count += 1
                continue
            naive_keys, naive_err = naive_split_classify(rr.text)
            our_keys = len(cls.keys) if cls.keys else 0
            if not (naive_err or naive_keys != our_keys):
                continue

            truncated = _frontmatter_prefix_text(rr.text)

            fd, tmp_path = tempfile.mkstemp(suffix=".md")
            try:
                with open(tmp_path, "wb") as tf:
                    import os

                    os.close(fd)
                    tf.write(truncated.encode("utf-8"))
                fw_parsed = fp.parse_frontmatter(tmp_path)
            finally:
                import os

                os.unlink(tmp_path)

            truncated_cls = classify_text(truncated)
            truncated_naive_keys, truncated_naive_err = naive_split_classify(truncated)

            records.append(
                {
                    "name": f"IT1-REAL-{len(records) + 1:03d}",
                    "source": f"corpus:{project}/{f.relative_to(root).as_posix()}",
                    "content_base64": __import__("base64")
                    .b64encode(truncated.encode("utf-8"))
                    .decode("ascii"),
                    "sha256": __import__("hashlib")
                    .sha256(truncated.encode("utf-8"))
                    .hexdigest(),
                    "framework_result": "split" if fw_parsed is not None else "none",
                    "frontmatter_text": truncated_cls.frontmatter_text,
                    "keys": sorted(fw_parsed.keys()) if fw_parsed is not None else None,
                    "naive_key_count": truncated_naive_keys,
                    "naive_yaml_error": truncated_naive_err,
                    "expected_result": truncated_cls.result,
                    "truncated_to_frontmatter_only": True,
                }
            )

    discriminating_n = len(records)

    for name, spec in _IT1_SYNTHETIC_SAMPLES.items():
        text = spec["content"]
        cls = classify_text(text)
        assert cls.result == spec["expected_result"], (name, cls.result)

        fd, tmp_path = tempfile.mkstemp(suffix=".md")
        try:
            with open(tmp_path, "wb") as tf:
                import os

                os.close(fd)
                tf.write(text.encode("utf-8"))
            fw_parsed = fp.parse_frontmatter(tmp_path)
        finally:
            import os

            os.unlink(tmp_path)

        naive_keys, naive_err = naive_split_classify(text)
        records.append(
            {
                "name": name,
                "source": "synthetic",
                "content_base64": __import__("base64").b64encode(text.encode("utf-8")).decode("ascii"),
                "sha256": __import__("hashlib").sha256(text.encode("utf-8")).hexdigest(),
                "framework_result": "split" if fw_parsed is not None else "none",
                "frontmatter_text": cls.frontmatter_text,
                "keys": sorted(fw_parsed.keys()) if fw_parsed is not None else None,
                "naive_key_count": naive_keys,
                "naive_yaml_error": naive_err,
                "expected_result": spec["expected_result"],
                "truncated_to_frontmatter_only": False,
            }
        )

    out = {
        "frozen_date": "2026-09-24",
        "framework_version_file": ".claude/VERSION",
        "corpus_projects": list(CORPUS_PROJECTS),
        "usable_files_scanned": usable_scanned,
        "excluded_line_separator_count": excluded_sep_count,
        "discriminating_real_files_n": discriminating_n,
        "note": (
            "real discriminating samples are truncated to the frontmatter "
            "segment only (through the closing '---' line inclusive) to "
            "control fixture size; naive split('---') semantics are "
            "unaffected by this truncation because parts[1] is bounded by "
            "the first two '---' occurrences, both within the retained "
            "prefix (see README deviation note)"
        ),  # i18n-exempt
        "samples": records,
    }

    out_path = repo_root / "test" / "fixtures" / "spec006" / "it1" / "expected.json"
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"wrote {len(records)} records (N={discriminating_n} real + {len(_IT1_SYNTHETIC_SAMPLES)} synthetic) to {out_path}")  # i18n-exempt
    print(f"usable_files_scanned={usable_scanned}, excluded_line_separator_count={excluded_sep_count}")  # i18n-exempt


def main() -> None:
    # i18n-exempt: 開發者離線 CLI 工具，非產品 user-facing 介面
    parser = argparse.ArgumentParser(description="SPEC-006 IT-2 獨立參照實作 CLI")  # i18n-exempt
    sub = parser.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan", help="離線掃描單一 workspace 並輸出分類結果 JSON")  # i18n-exempt
    scan.add_argument("--workspace", required=True, help="workspace 根目錄")  # i18n-exempt
    scan.add_argument(
        "--schema",
        default=".claude/skills/doc/doc_system/core/tracking_schema.json",
        help="tracking_schema.json 路徑",  # i18n-exempt
    )
    scan.set_defaults(func=_cmd_scan)

    selftest = sub.add_parser("selftest", help="執行內嵌單元測試")  # i18n-exempt
    selftest.set_defaults(func=lambda _args: _run_selftests())

    freeze_it2 = sub.add_parser(
        "freeze-it2", help="離線全量掃描五個語料專案，凍結 IT-2 manifest"  # i18n-exempt
    )
    freeze_it2.set_defaults(func=_cmd_freeze_it2)

    freeze_it1 = sub.add_parser(
        "freeze-it1", help="離線掃描五個語料專案，凍結 IT-1 判別樣本"  # i18n-exempt
    )
    freeze_it1.set_defaults(func=_cmd_freeze_it1)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
