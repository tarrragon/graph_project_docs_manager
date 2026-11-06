"""SPEC-006 參照實作核心：FR-01 切分判型、FR-05 讀檔、FR-06 型別表比對、掃描。

由 spec006_reference 拆出。
"""

from __future__ import annotations

import json
import re
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
