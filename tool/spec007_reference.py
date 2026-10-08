#!/usr/bin/env python3
"""SPEC-007 建圖參照實作（獨立於待測 Dart 實作）。

依 `docs/spec/graph/SPEC-007-graph-building.md`（FR-02～FR-06、FR-09、D5）與
`docs/test-design/SPEC-007-test-design.md` §2.1～§2.3 撰寫，產生 IT-1／IT-2／IT-3 的凍結測資。

獨立性約束：不 import、不執行、不讀取任何 Dart 實作或其產物；只讀 manifest、型別表，
`freeze` 時另讀語料原始檔。Corpus 判型借用同為 Python 的 `tool/spec006_reference.py`
（SPEC-006 參照實作），不涉及 Dart。引用值總數由 `count_reference_values` 依
〈用詞〉「引用值」逐欄獨立計數，不由三類分類結果加總。

子命令：
  selftest  內嵌單元測試
  freeze    讀兩語料，產出 manifest、型別表副本、三份 expected、IT-3 樣本
  compute   只讀 manifest 與型別表重算 expected；不帶 --out-dir 時與現有檔案比對
執行時機：凍結時離線執行，CI 不執行。
"""

from __future__ import annotations

import argparse
import copy
import datetime
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec006_reference as corpus_ref  # noqa: E402  只借 Corpus 判型，非 Dart

REFERENCE_VERSION = "1.0.0"
EXCLUDED_EDGE_TYPE = "domain_dependency"  # SPEC-007 D6：唯一以鍵名排除的邊型
UNDIRECTED_EDGE_TYPE = "association"  # SPEC-007 FR-04／FR-05：無向邊
TICKET_TYPE = "Ticket"
SYNTHETIC_CORPUS = "synthetic"
CORPUS_GPDM = "graph_project_docs_manager"
CORPUS_FB = "flutter_balance"
FIXTURE_DIR = Path("test/fixtures/spec007")
SCHEMA_RELATIVE = Path(".claude/skills/doc/doc_system/core/tracking_schema.json")

REASON_INVALID_SHAPE = "invalidShape"
REASON_PATTERN = "patternMismatch"
REASON_SELF = "selfReference"
REASON_MISSING = "targetMissing"
REASON_DUPLICATED = "targetDuplicated"

# D5 樣本類別（SPEC-007-test-design §2.2.1）
COVERS_ALL = (
    "related_one_side",
    "related_both_sides",
    "spawn_reverse_only",
    "spawn_multi_source",
    "provenance_multi_source",
    "dangling",
    "malformed_pattern",
    "duplicate_id",
    "self_reference",
    "invalid_shape",
    "target_duplicated",
    "outputs_non_list_subkey",
    "null_in_list",
    "non_string_status_title",
)


# ---------------------------------------------------------------------------
# 型別表
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class EdgeType:
    name: str
    forward_field: str
    reverse_field: str | None
    cardinality: str


def load_edge_types(table: dict[str, Any]) -> list[EdgeType]:
    """FR-01：使用中邊型 = established 扣除 domain_dependency；欄位與基數取自型別表。"""
    result = []
    for name, spec in table["edge_types"].items():
        if spec["layer"] != "established" or name == EXCLUDED_EDGE_TYPE:
            continue
        result.append(
            EdgeType(
                name=name,
                forward_field=spec["forward_field"],
                reverse_field=spec.get("reverse_field"),
                cardinality=spec["forward_cardinality"],
            )
        )
    return sorted(result, key=lambda e: e.name)


def edge_field_names(edge_types: list[EdgeType]) -> list[str]:
    names = set()
    for edge in edge_types:
        names.add(edge.forward_field)
        if edge.reverse_field:
            names.add(edge.reverse_field)
    return sorted(names)


def compile_id_patterns(table: dict[str, Any]) -> list[re.Pattern[str]]:
    """id_pattern_dialect 為 python-re；全部節點型別（含 proposed）皆參與比對。"""
    return [
        re.compile(spec["id_pattern"])
        for spec in table["node_types"].values()
        if spec.get("id_pattern")
    ]


# ---------------------------------------------------------------------------
# FR-03 抽取
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Ref:
    source_id: str
    path: str
    edge_type: str
    is_reverse: bool
    field: str
    raw: Any
    invalid_shape: bool


def _list_units(items: list[Any]) -> list[tuple[Any, bool]]:
    return [(item, not isinstance(item, str)) for item in items if item is not None]


def _field_units(value: Any) -> list[tuple[Any, bool]]:
    """(原值, 形狀是否不合法)：缺席、null、空字串、空清單不產生引用值。"""
    if value is None or (isinstance(value, str) and value == ""):
        return []
    if isinstance(value, list):
        return _list_units(value)
    return [(value, not isinstance(value, str))]


def _outputs_map_units(mapping: dict[str, Any]) -> list[tuple[Any, bool]]:
    """反向欄位 map：子鍵只是分組；子鍵值非清單時整個子鍵計為一個格式錯誤。"""
    units: list[tuple[Any, bool]] = []
    for sub_value in mapping.values():
        if isinstance(sub_value, list):
            units.extend(_list_units(sub_value))
        elif sub_value is not None and sub_value != "":
            units.append((sub_value, True))
    return units


def extract_refs(row: dict[str, Any], edge_types: list[EdgeType]) -> list[Ref]:
    fields = row.get("edge_fields", {})
    refs: list[Ref] = []
    for edge in edge_types:
        slots = [(edge.forward_field, False)]
        if edge.reverse_field:
            slots.append((edge.reverse_field, True))
        for field_name, is_reverse in slots:
            value = fields.get(field_name)
            if is_reverse and isinstance(value, dict):
                units = _outputs_map_units(value)
            else:
                units = _field_units(value)
            for raw, invalid in units:
                refs.append(
                    Ref(row["id"], row["path"], edge.name, is_reverse, field_name, raw, invalid)
                )
    return refs


# ---------------------------------------------------------------------------
# 引用值總數：獨立計數（不經分類、不共用抽取程式碼）
# ---------------------------------------------------------------------------


def _count_subkey(value: Any) -> int:
    if isinstance(value, list):
        return sum(1 for item in value if item is not None)
    return 0 if value in (None, "") else 1


def _count_units(value: Any, expand_map: bool) -> int:
    if value is None or (isinstance(value, str) and not value):
        return 0
    if isinstance(value, dict) and expand_map:
        return sum(_count_subkey(v) for v in value.values())
    if isinstance(value, list):
        return sum(1 for item in value if item is not None)
    return 1


def count_reference_values(rows: list[dict[str, Any]], edge_types: list[EdgeType]) -> int:
    """遍歷 manifest 各列 edge_fields 計數；重複 ID 的節點不計（FR-02）。"""
    id_counts = Counter(row["id"] for row in rows)
    total = 0
    for row in rows:
        if id_counts[row["id"]] > 1:
            continue
        fields = row.get("edge_fields", {})
        for edge in edge_types:
            total += _count_units(fields.get(edge.forward_field), expand_map=False)
            if edge.reverse_field:
                total += _count_units(fields.get(edge.reverse_field), expand_map=True)
    return total


# ---------------------------------------------------------------------------
# FR-02～FR-05 建圖
# ---------------------------------------------------------------------------


def light_node(row: dict[str, Any]) -> dict[str, Any]:
    """FR-02：輕節點五欄位；status／title 非字串視為缺席。"""

    def text_or_none(value: Any) -> str | None:
        return value if isinstance(value, str) else None

    return {
        "id": row["id"],
        "node_type": row["node_type"],
        "status": text_or_none(row.get("status")),
        "title": text_or_none(row.get("title")),
        "path": row["path"],
    }


def classify_ref(
    ref: Ref,
    node_ids: set[str],
    duplicate_ids: set[str],
    id_patterns: list[re.Pattern[str]],
) -> tuple[str, str | None]:
    """FR-03 有序判定：格式錯誤 -> 自我引用 -> 斷邊 -> 解析成功。"""
    if ref.invalid_shape:
        return "malformed", REASON_INVALID_SHAPE
    if not any(pattern.match(ref.raw) for pattern in id_patterns):
        return "malformed", REASON_PATTERN
    if ref.raw == ref.source_id:
        return "malformed", REASON_SELF
    if ref.raw not in node_ids:
        return "dangling", REASON_DUPLICATED if ref.raw in duplicate_ids else REASON_MISSING
    return "resolved", None


def _edge_key(ref: Ref) -> tuple[str, str, str]:
    if ref.edge_type == UNDIRECTED_EDGE_TYPE:
        low, high = sorted([ref.source_id, ref.raw])
        return ref.edge_type, low, high
    if ref.is_reverse:
        return ref.edge_type, ref.raw, ref.source_id
    return ref.edge_type, ref.source_id, ref.raw


@dataclass
class GraphResult:
    node_count: int
    duplicates: dict[str, list[str]]
    edges: dict[tuple[str, str, str], set[str]]
    ref_defects: list[dict[str, Any]]
    multi_sources: list[dict[str, Any]]
    classification: Counter
    reasons: Counter
    reference_total: int


def _group_rows(
    rows: list[dict[str, Any]],
) -> tuple[dict[str, dict[str, Any]], dict[str, list[str]]]:
    by_id: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_id[row["id"]].append(row)
    nodes = {i: group[0] for i, group in by_id.items() if len(group) == 1}
    duplicates = {i: sorted(r["path"] for r in g) for i, g in by_id.items() if len(g) > 1}
    return nodes, duplicates


def _ref_defect(ref: Ref, kind: str, reason: str) -> dict[str, Any]:
    return {
        "kind": kind,
        "source_id": ref.source_id,
        "path": ref.path,
        "field": ref.field,
        "raw_value": ref.raw,
        "edge_type": ref.edge_type,
        "reason": reason,
    }


def _detect_multi_source(
    edges: dict[tuple[str, str, str], set[str]], edge_types: list[EdgeType]
) -> list[dict[str, Any]]:
    """FR-04：正向基數 one 的邊型，同一起點解析成功的終點 >= 2 時回報一筆。"""
    one_types = {e.name for e in edge_types if e.cardinality == "one"}
    targets: dict[tuple[str, str], dict[str, list[str]]] = defaultdict(dict)
    for (edge_type, start, end), declared in edges.items():
        if edge_type in one_types:
            targets[(edge_type, start)][end] = sorted(declared)
    result = []
    for (edge_type, start), ends in targets.items():
        if len(ends) >= 2:
            result.append(
                {
                    "kind": "multiSource",
                    "from": start,
                    "edge_type": edge_type,
                    "targets": [{"to": to, "declared_by": ends[to]} for to in sorted(ends)],
                }
            )
    return result


def build_graph(
    rows: list[dict[str, Any]],
    edge_types: list[EdgeType],
    id_patterns: list[re.Pattern[str]],
) -> GraphResult:
    nodes, duplicates = _group_rows(rows)
    node_ids, duplicate_ids = set(nodes), set(duplicates)
    edges: dict[tuple[str, str, str], set[str]] = defaultdict(set)
    ref_defects: list[dict[str, Any]] = []
    classification: Counter = Counter()
    reasons: Counter = Counter()
    for row in nodes.values():
        for ref in extract_refs(row, edge_types):
            category, reason = classify_ref(ref, node_ids, duplicate_ids, id_patterns)
            classification[category] += 1
            if reason:
                reasons[reason] += 1
            if category == "resolved":
                edges[_edge_key(ref)].add(ref.source_id)
            else:
                kind = "danglingRef" if category == "dangling" else "malformedRef"
                ref_defects.append(_ref_defect(ref, kind, reason))
    return GraphResult(
        node_count=len(nodes),
        duplicates=duplicates,
        edges=dict(edges),
        ref_defects=ref_defects,
        multi_sources=_detect_multi_source(edges, edge_types),
        classification=classification,
        reasons=reasons,
        reference_total=count_reference_values(rows, edge_types),
    )


# ---------------------------------------------------------------------------
# 輸出：expected_edges／defects／counts
# ---------------------------------------------------------------------------


def edges_output(result: GraphResult) -> list[dict[str, Any]]:
    return [
        {"edge_type": t, "from": a, "to": b, "declared_by": sorted(result.edges[(t, a, b)])}
        for (t, a, b) in sorted(result.edges)
    ]


def defects_output(result: GraphResult) -> list[dict[str, Any]]:
    duplicates = [
        {"kind": "duplicateId", "id": i, "paths": paths} for i, paths in result.duplicates.items()
    ]
    everything = result.ref_defects + duplicates + result.multi_sources
    return sorted(everything, key=lambda d: json.dumps(d, sort_keys=True, ensure_ascii=False))


def declaration_shapes(result: GraphResult) -> dict[str, dict[str, int]]:
    """有向邊：僅起點／僅終點／兩端。無向邊無起終點之分，另計一端／兩端（規格未定義對應，見 README）。"""
    directed: Counter = Counter()
    undirected: Counter = Counter()
    for (edge_type, start, _end), declared in result.edges.items():
        if edge_type == UNDIRECTED_EDGE_TYPE:
            undirected["both" if len(declared) == 2 else "one_end"] += 1
        elif len(declared) == 2:
            directed["both"] += 1
        else:
            directed["from_only" if start in declared else "to_only"] += 1
    return {
        "directed": {k: directed[k] for k in ("from_only", "to_only", "both")},
        "undirected": {k: undirected[k] for k in ("one_end", "both")},
    }


def assert_conservation(counts: dict[str, Any]) -> None:
    """FR-03 守恆式：獨立計得的引用值總數 == 解析成功 + 斷邊 + 格式錯誤。"""
    summed = counts["resolved_count"] + counts["dangling_count"] + counts["malformed_count"]
    if counts["reference_value_total"] != summed:
        total = counts["reference_value_total"]
        # i18n-exempt: 開發者工具的診斷訊息，非 App 使用者介面字串
        raise AssertionError(f"守恆式不成立：總數 {total} != 分類加總 {summed}")


def counts_output(result: GraphResult) -> dict[str, Any]:
    by_type = Counter(edge_type for (edge_type, _, _) in result.edges)
    multi_by_type = Counter(d["edge_type"] for d in result.multi_sources)
    dangling = result.classification["dangling"]
    malformed = result.classification["malformed"]
    defect_count = dangling + malformed + len(result.duplicates) + len(result.multi_sources)
    counts = {
        "node_count": result.node_count,
        "duplicate_id_count": len(result.duplicates),
        "duplicate_id_node_count": sum(len(p) for p in result.duplicates.values()),
        "edge_count": len(result.edges),
        "edges_by_type": dict(sorted(by_type.items())),
        "declaration_shapes": declaration_shapes(result),
        "reference_value_total": result.reference_total,
        "resolved_count": result.classification["resolved"],
        "dangling_count": dangling,
        "malformed_count": malformed,
        "reason_counts": dict(sorted(result.reasons.items())),
        "multi_source_count": len(result.multi_sources),
        "multi_source_by_edge_type": dict(sorted(multi_by_type.items())),
        "graph_defect_count": defect_count,
    }
    assert_conservation(counts)
    return counts


def row_corpus(row: dict[str, Any]) -> str:
    return row["synthetic_host"] if row["synthetic"] else row["corpus"]


def compute_expected(manifest: dict[str, Any], table: dict[str, Any]) -> dict[str, Any]:
    """只讀 manifest 與型別表；每個語料各建一輪圖。"""
    edge_types = load_edge_types(table)
    id_patterns = compile_id_patterns(table)
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in manifest["rows"]:
        groups[row_corpus(row)].append(row)
    edges, defects, counts = {}, {}, {}
    for corpus in sorted(groups):
        rows = groups[corpus]
        result = build_graph(rows, edge_types, id_patterns)
        edges[corpus] = edges_output(result)
        defects[corpus] = defects_output(result)
        counts[corpus] = counts_output(result)
        real_rows = [r for r in rows if not r["synthetic"]]
        counts[corpus]["real_only"] = counts_output(build_graph(real_rows, edge_types, id_patterns))
    return {"edges": edges, "defects": defects, "counts": counts}


def expected_files(manifest: dict[str, Any], computed: dict[str, Any]) -> dict[str, dict[str, Any]]:
    header = {
        "reference_version": REFERENCE_VERSION,
        "frozen_date": manifest["header"]["frozen_date"],
        "note": "expected values produced by tool/spec007_reference.py; CI does not run it",
    }
    return {
        "expected_edges.json": {"header": header, "corpora": computed["edges"]},
        "expected_defects.json": {"header": header, "corpora": computed["defects"]},
        "expected_counts.json": {"header": header, "corpora": computed["counts"]},
    }


# ---------------------------------------------------------------------------
# freeze：語料 -> manifest
# ---------------------------------------------------------------------------


def json_safe(value: Any, stats: Counter) -> Any:
    """YAML 的 date／datetime 轉 ISO 字串（Dart yaml 套件不解析時間戳，讀入即為字串）。"""
    if isinstance(value, (datetime.datetime, datetime.date)):
        stats["dates_to_iso_string"] += 1
        return value.isoformat()
    if isinstance(value, dict):
        if not all(isinstance(k, str) for k in value):
            raise ValueError(f"non-string key cannot be frozen: {list(value)}")
        return {k: json_safe(v, stats) for k, v in value.items()}
    if isinstance(value, list):
        return [json_safe(v, stats) for v in value]
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    raise ValueError(f"unserializable YAML value type: {type(value).__name__}")


def _judge_node(
    absolute: Path, type_table: corpus_ref.SchemaTypeTable
) -> tuple[str | None, dict[str, Any] | None]:
    """SPEC-006 FR-03 節點判型（與 corpus_ref.classify_file 的 node 分支同義，只解析一次 YAML）。"""
    text = corpus_ref.read_file(absolute).text
    if text is None:
        return None, None
    classified = corpus_ref.classify_text(text)
    if classified.result != corpus_ref.RESULT_USABLE:
        return None, None
    node_id = classified.data.get("id")
    if not isinstance(node_id, str):
        return None, None
    matched = type_table.match_id(node_id)
    return (matched.node_type, classified.data) if matched.kind == "hit" else (None, None)


def collect_real_rows(
    root: Path,
    corpus: str,
    type_table: corpus_ref.SchemaTypeTable,
    field_names: list[str],
    stats: Counter,
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    """回傳 (manifest 列, path -> 完整 frontmatter)；只收 Corpus 判為節點的檔案。"""
    rows, frontmatters = [], {}
    for absolute in sorted(corpus_ref.scan_markdown_files(root)):
        node_type, data = _judge_node(absolute, type_table)
        if node_type is None:
            continue
        relative_path = absolute.relative_to(root).as_posix()
        full = json_safe(data, stats)
        rows.append(
            {
                "corpus": corpus,
                "path": relative_path,
                "id": full["id"],
                "node_type": node_type,
                "status": full.get("status"),
                "title": full.get("title"),
                "edge_fields": {k: full[k] for k in field_names if k in full},
                "synthetic": False,
                "covers": [],
            }
        )
        frontmatters[relative_path] = full
    return rows, frontmatters


def snapshot_signature(root: Path) -> list[tuple[str, int]]:
    """語料 docs/ 下全部 .md 的 (相對路徑, mtime_ns)；用來偵測凍結期間語料被改動。"""
    files = corpus_ref.scan_markdown_files(root)
    return sorted((f.relative_to(root).as_posix(), f.stat().st_mtime_ns) for f in files)


def _syn(id_: str, path: str, node_type: str, covers: list[str], **fields: Any) -> dict[str, Any]:
    return {
        "corpus": SYNTHETIC_CORPUS,
        "synthetic_host": CORPUS_GPDM,
        "path": path,
        "id": id_,
        "node_type": node_type,
        "status": fields.pop("status", "pending"),
        "title": fields.pop("title", f"synthetic {id_}"),
        "edge_fields": fields,
        "synthetic": True,
        "covers": covers,
    }


def synthetic_rows() -> list[dict[str, Any]]:
    """語料缺席類別的合成列（ID 空間 9.9.9／PROP-901，不與真實語料重疊）。"""
    base = "docs/work-logs/v9/v9.9/v9.9.9/tickets/"
    t = TICKET_TYPE
    return [
        _syn("9.9.9-W9-001", base + "9.9.9-W9-001.md", t, ["duplicate_id"]),
        _syn("9.9.9-W9-001", base + "9.9.9-W9-001-copy.md", t, ["duplicate_id"]),
        _syn("9.9.9-W9-002", base + "9.9.9-W9-002.md", t, ["target_duplicated"],
             relatedTo=["9.9.9-W9-001"]),
        _syn("9.9.9-W9-003", base + "9.9.9-W9-003.md", t, ["self_reference"],
             relatedTo=["9.9.9-W9-003"]),
        _syn("9.9.9-W9-004", base + "9.9.9-W9-004.md", t, ["invalid_shape"],
             blockedBy=["9.9.9-W9-002", 42], discovered_during=True,
             source_ticket={"a": "b"}, relatedTo=[["x"]]),
        _syn("9.9.9-W9-005", base + "9.9.9-W9-005.md", t, ["null_in_list"],
             blockedBy=["9.9.9-W9-002", None]),
        _syn("9.9.9-W9-006", base + "9.9.9-W9-006.md", t, ["non_string_status_title"],
             status=3, title=["a"]),
        _syn("PROP-901", "docs/proposals/PROP-901-synthetic.md", "PROP",
             ["outputs_non_list_subkey"],
             outputs={"design_refs": ["9.9.9-W9-002"], "notes": "x"}),
    ]


def derive_real_covers(rows: list[dict[str, Any]], result: GraphResult) -> dict[str, set[str]]:
    """由建圖結果推導真實列各自負責的 D5 類別（path 對類別集合）。"""
    by_id = {r["id"]: r["path"] for r in rows if not r["synthetic"]}
    tags: dict[str, set[str]] = defaultdict(set)

    def tag(node_id: str, cover: str) -> None:
        if node_id in by_id:
            tags[by_id[node_id]].add(cover)

    provenance_targets: dict[str, set[str]] = defaultdict(set)
    for (edge_type, start, end), declared in result.edges.items():
        if edge_type == UNDIRECTED_EDGE_TYPE:
            if len(declared) == 1:
                tag(next(iter(declared)), "related_one_side")
            else:
                tag(start, "related_both_sides")
                tag(end, "related_both_sides")
        elif edge_type == "spawn" and declared == {end}:
            tag(start, "spawn_reverse_only")
        if edge_type == "provenance":
            provenance_targets[start].add(end)
    for start, ends in provenance_targets.items():
        if len(ends) >= 2:
            tag(start, "provenance_multi_source")
    for defect in result.multi_sources:
        if defect["edge_type"] == "spawn":
            tag(defect["from"], "spawn_multi_source")
    for defect in result.ref_defects:
        if defect["reason"] == REASON_MISSING:
            tag(defect["source_id"], "dangling")
        if defect["reason"] == REASON_PATTERN:
            tag(defect["source_id"], "malformed_pattern")
    return tags


def coverage_gaps(rows: list[dict[str, Any]]) -> list[str]:
    """IT1-A5 守衛的參照版：回傳 manifest 未覆蓋的 §2.2.1 類別。"""
    present = {c for row in rows for c in row["covers"]}
    return [c for c in COVERS_ALL if c not in present]


def _null_items(row: dict[str, Any]) -> int:
    count = 0
    for value in row["edge_fields"].values():
        for v in list(value.values()) if isinstance(value, dict) else [value]:
            if isinstance(v, list):
                count += sum(1 for item in v if item is None)
    return count


def _has_non_string(value: Any) -> bool:
    return value is not None and not isinstance(value, str)


def real_evidence_for_synthetic_only(
    rows: list[dict[str, Any]], result: GraphResult
) -> dict[str, int]:
    """合成只補語料缺席類別：回傳這些類別在真實列的實際出現數（必須為 0）。"""
    real_rows = [r for r in rows if not r["synthetic"]]
    return {
        "duplicate_id": len(result.duplicates),
        "self_reference": result.reasons[REASON_SELF],
        "invalid_shape": result.reasons[REASON_INVALID_SHAPE],
        "target_duplicated": result.reasons[REASON_DUPLICATED],
        "null_in_list": sum(_null_items(r) for r in real_rows),
        "non_string_status_title": sum(
            1 for r in real_rows if _has_non_string(r["status"]) or _has_non_string(r["title"])
        ),
    }


def pick_ticket_samples(
    rows: list[dict[str, Any]], frontmatters: dict[tuple[str, str], dict[str, Any]]
) -> dict[str, Any]:
    """IT-3：每個語料、每種字串 status 值至少一張（取路徑字典序第一張）。"""
    samples, status_values, missing = [], {}, {}
    for corpus in (CORPUS_GPDM, CORPUS_FB):
        tickets = sorted(
            (
                r for r in rows
                if not r["synthetic"] and r["corpus"] == corpus and r["node_type"] == TICKET_TYPE
            ),
            key=lambda r: r["path"],
        )
        picked: dict[str, dict[str, Any]] = {}
        status_counts: Counter = Counter()
        for row in tickets:
            if isinstance(row["status"], str):
                status_counts[row["status"]] += 1
                picked.setdefault(row["status"], row)
        status_values[corpus] = dict(sorted(status_counts.items()))
        missing[corpus] = sum(1 for r in tickets if not isinstance(r["status"], str))
        for status in sorted(picked):
            row = picked[status]
            samples.append(
                {
                    "corpus": corpus,
                    "path": row["path"],
                    "id": row["id"],
                    "frontmatter": frontmatters[(corpus, row["path"])],
                }
            )
    return {
        "header": {
            "note": "IT-3 samples; every sample is an existing manifest row (same corpus and path)",
            "status_values": status_values,
            "tickets_without_string_status": missing,
        },
        "samples": samples,
    }


def check_samples_against_manifest(
    samples: dict[str, Any], manifest: dict[str, Any], field_names: list[str]
) -> None:
    """凍結時斷言：樣本的 id／status／title／使用中邊型欄位原值等於 manifest 同 path 的列。"""
    index = {(r["corpus"], r["path"]): r for r in manifest["rows"]}
    for sample in samples["samples"]:
        row = index[(sample["corpus"], sample["path"])]
        fm = sample["frontmatter"]
        got = {k: fm[k] for k in field_names if k in fm}
        same = (
            fm["id"] == row["id"]
            and fm.get("status") == row["status"]
            and fm.get("title") == row["title"]
            and got == row["edge_fields"]
        )
        if not same:
            raise AssertionError(f"sample differs from manifest row: {sample['path']}")


def corpus_commit_info(root: Path) -> dict[str, Any]:
    """讀 HEAD commit。語料為他人 repo 時不呼叫 git，直接讀 .git（唯讀）。"""
    git_dir = root / ".git"
    if git_dir.is_dir():
        head = (git_dir / "HEAD").read_text().strip()
        if head.startswith("ref: "):
            ref = head[5:]
            ref_file = git_dir / ref
            if ref_file.exists():
                return {"commit": ref_file.read_text().strip()}
            for line in (git_dir / "packed-refs").read_text().splitlines():
                if line.endswith(" " + ref):
                    return {"commit": line.split()[0]}
        return {"commit": head}
    out = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    )
    status = subprocess.run(
        ["git", "-C", str(root), "status", "--porcelain", "--", "docs"],
        capture_output=True, text=True, check=True,
    )
    return {"commit": out.stdout.strip(), "dirty_docs_entries": len(status.stdout.splitlines())}


def write_json(path: Path, data: Any) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    path.write_text(text, encoding="utf-8")


def _finish_manifest(
    rows: list[dict[str, Any]],
    roots: dict[str, Path],
    repo: Path,
    table: dict[str, Any],
    stats: Counter,
    snapshots: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """凍結時附上 covers 標記與 header；synthetic 只補缺席類別，違反即中止。"""
    edge_types = load_edge_types(table)
    patterns = compile_id_patterns(table)
    rows.sort(key=lambda r: (row_corpus(r), r["path"]))
    real_rows = [r for r in rows if not r["synthetic"]]
    for corpus in roots:  # 兩語料 ID 空間可能重疊，逐語料各建一輪
        corpus_rows = [r for r in rows if row_corpus(r) == corpus]
        corpus_real = [r for r in corpus_rows if not r["synthetic"]]
        real_ids = {r["id"] for r in corpus_real}
        clash = [r["id"] for r in corpus_rows if r["synthetic"] and r["id"] in real_ids]
        if clash:
            raise AssertionError(f"synthetic id overlaps real rows: {clash}")
        real_result = build_graph(corpus_real, edge_types, patterns)
        evidence = real_evidence_for_synthetic_only(corpus_rows, real_result)
        if any(evidence.values()):
            raise AssertionError(f"{corpus}: category exists in corpus, must not be synthetic: {evidence}")
        tags = derive_real_covers(corpus_real, real_result)
        for row in corpus_real:
            row["covers"] = sorted(tags.get(row["path"], set()))
    gaps = coverage_gaps(rows)
    if gaps:
        raise AssertionError(f"manifest misses categories: {gaps}")
    cover_rows = {c: {"real": 0, "synthetic": 0} for c in COVERS_ALL}
    for row in rows:
        for c in row["covers"]:
            cover_rows[c]["synthetic" if row["synthetic"] else "real"] += 1
    header = {
        "frozen_date": datetime.date.today().isoformat(),
        "reference_version": REFERENCE_VERSION,
        "framework_version": (repo / ".claude/VERSION").read_text().strip(),
        "schema_generated_at_framework_version": table["schema_generated_at_framework_version"],
        "id_pattern_dialect": table.get("id_pattern_dialect"),
        "corpus_commits": {c: corpus_commit_info(root) for c, root in roots.items()},
        "corpus_snapshots": snapshots,
        "row_counts_real": dict(sorted(Counter(r["corpus"] for r in real_rows).items())),
        "row_counts_with_synthetic": dict(sorted(Counter(row_corpus(r) for r in rows).items())),
        "covers_rows": cover_rows,
        "yaml_dates_converted_to_iso_string": stats["dates_to_iso_string"],
    }
    return {"header": header, "rows": rows}


def _cmd_freeze(args: argparse.Namespace) -> None:
    repo = Path(args.gpdm_root).resolve()
    roots = {CORPUS_GPDM: repo, CORPUS_FB: Path(args.fb_root).expanduser().resolve()}
    out_dir = Path(args.out_dir) if args.out_dir else repo / FIXTURE_DIR
    table = json.loads((repo / SCHEMA_RELATIVE).read_text(encoding="utf-8"))
    type_table = corpus_ref.SchemaTypeTable(table["node_types"])
    field_names = edge_field_names(load_edge_types(table))

    stats: Counter = Counter()
    rows, frontmatters, snapshots = [], {}, {}
    for corpus, root in roots.items():
        before = snapshot_signature(root)
        corpus_rows, corpus_fm = collect_real_rows(root, corpus, type_table, field_names, stats)
        if snapshot_signature(root) != before:
            raise RuntimeError(f"{corpus} changed while freezing; rerun when the corpus is quiet")
        snapshots[corpus] = {
            "docs_md_files": len(before),
            "signature_sha256": hashlib.sha256(json.dumps(before).encode()).hexdigest(),
        }
        rows += corpus_rows
        frontmatters.update({(corpus, p): fm for p, fm in corpus_fm.items()})
    rows += synthetic_rows()

    manifest = _finish_manifest(rows, roots, repo, table, stats, snapshots)
    out_dir.mkdir(parents=True, exist_ok=True)
    write_json(out_dir / "type_table.json", table)
    write_json(out_dir / "graph_manifest.json", manifest)
    computed = compute_expected(manifest, table)
    for name, data in expected_files(manifest, computed).items():
        write_json(out_dir / name, data)
    samples = pick_ticket_samples(manifest["rows"], frontmatters)
    check_samples_against_manifest(samples, manifest, field_names)
    write_json(out_dir / "ticket_detail_samples.json", samples)
    print(json.dumps(manifest["header"], ensure_ascii=False, indent=1))
    print(json.dumps(samples["header"], ensure_ascii=False, indent=1))
    real_only = {c: v["real_only"] for c, v in computed["counts"].items()}
    print(json.dumps(real_only, ensure_ascii=False, indent=1))


def _cmd_compute(args: argparse.Namespace) -> None:
    fixture_dir = Path(args.fixture_dir)
    manifest = json.loads((fixture_dir / "graph_manifest.json").read_text(encoding="utf-8"))
    table = json.loads((fixture_dir / "type_table.json").read_text(encoding="utf-8"))
    files = expected_files(manifest, compute_expected(manifest, table))
    if args.out_dir:
        out = Path(args.out_dir)
        out.mkdir(parents=True, exist_ok=True)
        for name, data in files.items():
            write_json(out / name, data)
        return
    bad = []
    for name, data in files.items():
        frozen = json.loads((fixture_dir / name).read_text(encoding="utf-8"))
        if frozen != json.loads(json.dumps(data)):
            bad.append(name)
    print("recompute matches frozen values" if not bad else f"mismatch: {bad}")
    sys.exit(1 if bad else 0)


# ---------------------------------------------------------------------------
# selftest
# ---------------------------------------------------------------------------

_TEST_NODE_TYPES = {
    "Ticket": {"id_pattern": r"^[\w.]+-W\d+-\d+(\.\d+)*$"},
    "PROP": {"id_pattern": r"^PROP-\d{3}$"},
    "SPEC": {"id_pattern": r"^SPEC-([0-9]{3}|[A-Z0-9-]+)$"},
    "UC": {"id_pattern": r"^UC-\d{2,}$"},
}


def _test_table() -> dict[str, Any]:
    def edge(fwd: str, card: str, rev: str | None = None, layer: str = "established") -> dict:
        return {
            "forward_field": fwd,
            "reverse_field": rev,
            "forward_cardinality": card,
            "layer": layer,
            "class": "x",
        }

    return {
        "node_types": _TEST_NODE_TYPES,
        "edge_types": {
            "association": edge("relatedTo", "many"),
            "blocking": edge("blockedBy", "many"),
            "spawn": edge("source_ticket", "one", "spawned_tickets"),
            "provenance": edge("source_proposal", "many", "outputs"),
            "discovery": edge("discovered_during", "one"),
            "domain_dependency": edge("depends_on_domains", "many"),
            "emission": edge("emits", "many", layer="proposed"),
        },
    }


def _row(id_: str, node_type: str = "Ticket", **fields: Any) -> dict[str, Any]:
    return {
        "corpus": "t",
        "path": f"docs/{id_}.md",
        "id": id_,
        "node_type": node_type,
        "status": "pending",
        "title": "t",
        "edge_fields": fields,
        "synthetic": False,
        "covers": [],
    }


def _graph(rows: list[dict[str, Any]], table: dict[str, Any] | None = None) -> GraphResult:
    table = table or _test_table()
    return build_graph(rows, load_edge_types(table), compile_id_patterns(table))


def _edge_set(result: GraphResult) -> set[tuple]:
    return {(t, a, b, tuple(sorted(d))) for (t, a, b), d in result.edges.items()}


def _reasons(result: GraphResult) -> list[tuple[str, str, Any]]:
    return sorted((d["kind"], d["reason"], d["raw_value"]) for d in result.ref_defects)


A, B, C = "1.0.0-W1-001", "1.0.0-W1-002", "1.0.0-W1-003"


def _test_edge_types_and_patterns() -> None:
    types = {e.name: e for e in load_edge_types(_test_table())}
    assert set(types) == {"association", "blocking", "spawn", "provenance", "discovery"}
    assert types["spawn"].cardinality == "one" and types["provenance"].cardinality == "many"
    changed = copy.deepcopy(_test_table())
    changed["edge_types"]["blocking"]["forward_field"] = "blocks_x"
    rows = [_row(A, blockedBy=[B], blocks_x=[C]), _row(B), _row(C)]
    assert _edge_set(_graph(rows, changed)) == {("blocking", A, C, (A,))}  # E1：改名後不讀舊欄位
    assert _edge_set(_graph(rows)) == {("blocking", A, B, (A,))}


def _test_light_node_and_duplicates() -> None:
    node = light_node({**_row(A), "status": 3, "title": ["a"]})
    assert node["status"] is None and node["title"] is None and len(node) == 5
    dup1 = _row(A, relatedTo=[B])
    dup2 = {**_row(A, relatedTo=[C]), "path": "docs/other.md"}
    r = _graph([dup1, dup2, _row(B, relatedTo=[A])])
    assert r.node_count == 1 and r.duplicates == {A: ["docs/1.0.0-W1-001.md", "docs/other.md"]}
    assert _reasons(r) == [("danglingRef", REASON_DUPLICATED, A)]  # 重複節點自己的引用不計
    assert r.reference_total == 1 and r.classification["dangling"] == 1
    r = _graph([dup1, {**dup2, "id": B}])  # 正向對照：ID 不同則皆入圖
    assert r.node_count == 2 and not r.duplicates


def _test_extraction() -> None:
    zero = _row(A, blockedBy=[], relatedTo="", source_ticket=None, discovered_during="")
    assert extract_refs(zero, load_edge_types(_test_table())) == []
    r = _graph([_row(A, blockedBy=[B, 42, None]), _row(B)])
    assert _edge_set(r) == {("blocking", A, B, (A,))}
    assert _reasons(r) == [("malformedRef", REASON_INVALID_SHAPE, 42)]
    r = _graph([_row(A, discovered_during=True, source_ticket={"k": "v"})])
    assert r.reasons[REASON_INVALID_SHAPE] == 2 and r.reference_total == 2
    prop = _row("PROP-001", "PROP", outputs={"a": [A, B], "b": [C, None], "notes": "x"})
    r = _graph([prop, _row(A), _row(B)])
    assert r.reference_total == 4 and r.reasons[REASON_INVALID_SHAPE] == 1
    assert r.classification["dangling"] == 1  # C 不存在
    assert ("provenance", A, "PROP-001", ("PROP-001",)) in _edge_set(r)


def _test_classification() -> None:
    r = _graph([_row(A, source_ticket="1.0.0-W3-181")])
    assert _reasons(r) == [("danglingRef", REASON_MISSING, "1.0.0-W3-181")]
    rows = [
        _row(A, relatedTo=[f"{B} {C}", " " + B], discovered_during="1.2.1-W3-1057 done",
             spawned_tickets=["PENDING"]),
        _row(B),
        _row(C),
    ]
    r = _graph(rows)
    assert r.classification["malformed"] == 4 and not r.edges
    assert r.reasons[REASON_PATTERN] == 4
    r = _graph([_row(A, relatedTo=[A, B]), _row(B)])
    assert _reasons(r) == [("malformedRef", REASON_SELF, A)]
    assert _edge_set(r) == {("association", A, B, (A,))}
    r = _graph([_row(A, blockedBy=["SPEC-001"]), _row("SPEC-001", "SPEC")])
    assert ("blocking", A, "SPEC-001", (A,)) in _edge_set(r)  # 不檢查終點型別


def _test_edges_and_multisource() -> None:
    parent = _row(A, spawned_tickets=[B])
    r = _graph([parent, _row(B)])
    assert _edge_set(r) == {("spawn", B, A, (A,))} and not r.multi_sources
    r = _graph([parent, _row(B, source_ticket=A)])
    assert _edge_set(r) == {("spawn", B, A, (A, B))}
    rows = [_row(A, spawned_tickets=[C]), _row(B, spawned_tickets=[C]), _row(C, source_ticket=A)]
    r = _graph(rows)
    assert _edge_set(r) == {("spawn", C, A, (A, C)), ("spawn", C, B, (B,))}
    assert [(d["from"], [t["to"] for t in d["targets"]]) for d in r.multi_sources] == [(C, [A, B])]
    r = _graph([parent, _row(B, source_ticket="1.0.0-W9-999")])  # 斷邊不參與 multiSource
    assert not r.multi_sources and r.classification["dangling"] == 1
    r = _graph([
        _row("UC-01", "UC", source_proposal=["PROP-003", "PROP-002"]),
        _row("PROP-003", "PROP", outputs={"usecase_refs": ["UC-01"]}),
        _row("PROP-002", "PROP", outputs={"usecase_refs": ["UC-01"]}),
    ])
    assert _edge_set(r) == {
        ("provenance", "UC-01", "PROP-003", ("PROP-003", "UC-01")),
        ("provenance", "UC-01", "PROP-002", ("PROP-002", "UC-01")),
    }
    assert not r.multi_sources  # provenance 基數 many


def _test_association_union() -> None:
    r = _graph([_row(B, relatedTo=[A]), _row(A)])
    assert _edge_set(r) == {("association", A, B, (B,))}  # 端點依字典序，宣告來源為列出者
    r = _graph([_row(B, relatedTo=[A]), _row(A, relatedTo=[B])])
    assert _edge_set(r) == {("association", A, B, (A, B))}
    assert declaration_shapes(r)["undirected"] == {"one_end": 0, "both": 1}


def _test_counts_and_conservation() -> None:
    rows = [_row(A, relatedTo=[B, "bad id"], blockedBy=[C, 7]), _row(B, relatedTo=[A]), _row(C)]
    counts = counts_output(_graph(rows))
    assert counts["reference_value_total"] == 5
    assert counts["resolved_count"] + counts["dangling_count"] + counts["malformed_count"] == 5
    bad = {**counts, "resolved_count": counts["resolved_count"] - 1}  # E2：少 1 必須被抓到
    try:
        assert_conservation(bad)
    except AssertionError:
        pass
    else:
        raise AssertionError("conservation checker missed a count short by one")
    empty = counts_output(_graph([]))
    assert empty["node_count"] == 0 and empty["edge_count"] == 0
    assert empty["graph_defect_count"] == 0
    assert counts_output(_graph(list(reversed(rows)))) == counts  # 與列順序無關


def _test_reference_total_two_ways_on_fixture() -> None:
    """引用值總數兩種算法（獨立計數 vs 三類加總）在 fixture 上相等。"""
    result = _graph([dict(r) for r in synthetic_rows()])
    assert result.reference_total == sum(result.classification.values()) > 0
    result = _graph([
        _row(A, relatedTo=[B, B, "x y"], blockedBy=[7, None, C], source_ticket=B),
        _row(B, spawned_tickets=[A, A]),
        _row("PROP-001", "PROP", outputs={"k": [A, None], "n": "z", "e": []}),
        _row(C),
    ])
    assert result.reference_total == sum(result.classification.values())


def _test_coverage_guard() -> None:
    rows = synthetic_rows()
    assert "related_one_side" in coverage_gaps(rows)  # E2：缺類別必須回報
    assert coverage_gaps([{**rows[0], "covers": list(COVERS_ALL)}]) == []


def _run_selftests() -> None:
    tests = [
        _test_edge_types_and_patterns,
        _test_light_node_and_duplicates,
        _test_extraction,
        _test_classification,
        _test_edges_and_multisource,
        _test_association_union,
        _test_counts_and_conservation,
        _test_reference_total_two_ways_on_fixture,
        _test_coverage_guard,
    ]
    for test in tests:
        test()
        print(f"ok  {test.__name__}")
    print(f"selftest passed: {len(tests)} groups")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("selftest")
    freeze = sub.add_parser("freeze")
    freeze.add_argument("--gpdm-root", default=str(Path(__file__).resolve().parent.parent))
    freeze.add_argument("--fb-root", default="~/project/flutter_balance")
    freeze.add_argument("--out-dir", default=None)
    compute = sub.add_parser("compute")
    compute.add_argument("--fixture-dir", default=str(FIXTURE_DIR))
    compute.add_argument("--out-dir", default=None)
    args = parser.parse_args()
    handlers = {
        "selftest": lambda a: _run_selftests(),
        "freeze": _cmd_freeze,
        "compute": _cmd_compute,
    }
    handlers[args.command](args)


if __name__ == "__main__":
    main()
