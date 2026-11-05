"""SPEC-007 建圖與輸出、預期值計算。"""

from __future__ import annotations

import json
import re
import dataclasses
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from spec007_extract import (  # noqa: E402
    CLOSED_BY_EDGE_TYPE,
    DOMAIN_BUNDLE_TYPE,
    DOMAIN_FIELD,
    EdgeType,
    NAME_RESOLVED_EDGE_TYPE,
    REASON_DUPLICATED,
    REASON_INVALID_SHAPE,
    REASON_MISSING,
    REASON_PATTERN,
    REASON_SELF,
    REFERENCE_VERSION,
    Ref,
    compile_id_patterns,
    compile_main_graph_patterns,
    count_closed_by_values,
    count_reference_values,
    extract_refs,
    is_closed_by_skipped,
    load_edge_types,
)


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


def build_domain_index(nodes: dict[str, dict[str, Any]]) -> dict[str, str]:
    """FR-11：DomainBundle 的 domain（非空字串，精確比對）-> 節點 ID；重複宣告的名稱兩者皆排除。"""
    ids_by_name: dict[str, list[str]] = defaultdict(list)
    for node_id, row in nodes.items():
        name = row.get("edge_fields", {}).get(DOMAIN_FIELD)
        if row["node_type"] == DOMAIN_BUNDLE_TYPE and isinstance(name, str) and name:
            ids_by_name[name].append(node_id)
    return {n: ids[0] for n, ids in ids_by_name.items() if len(ids) == 1}


def classify_name_ref(ref: Ref, domain_index: dict[str, str]) -> tuple[str, str | None, str | None]:
    """FR-03／FR-11：(類別, 原因, 目標 ID)；不比對 id_pattern。非字串 invalidShape，查無 targetMissing。"""
    if ref.invalid_shape:
        return "malformed", REASON_INVALID_SHAPE, None
    target = domain_index.get(ref.raw)
    if target is None:
        return "dangling", REASON_MISSING, None
    return "resolved", None, target


def _edge_key(ref: Ref, undirected: set[str]) -> tuple[str, str, str]:
    if ref.edge_type in undirected:
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
    undirected: frozenset[str] = frozenset()
    closed_by_skipped: int = 0
    closed_by_refs: int = 0
    closed_by_field_total: int = 0


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
    main_patterns: list[re.Pattern[str]],
) -> GraphResult:
    nodes, duplicates = _group_rows(rows)
    node_ids, duplicate_ids = set(nodes), set(duplicates)
    undirected = {e.name for e in edge_types if e.undirected}
    edges: dict[tuple[str, str, str], set[str]] = defaultdict(set)
    ref_defects: list[dict[str, Any]] = []
    classification: Counter = Counter()
    reasons: Counter = Counter()
    closed_by_skipped = closed_by_refs = 0
    domain_index = build_domain_index(nodes)
    for row in nodes.values():
        for ref in extract_refs(row, edge_types):
            if ref.edge_type == NAME_RESOLVED_EDGE_TYPE:
                category, reason, target = classify_name_ref(ref, domain_index)
                classification[category] += 1
                if reason:
                    reasons[reason] += 1
                if category == "resolved":
                    edges[_edge_key(dataclasses.replace(ref, raw=target), undirected)].add(ref.source_id)
                else:
                    kind = "danglingRef" if category == "dangling" else "malformedRef"
                    ref_defects.append(_ref_defect(ref, kind, reason))
                continue
            if is_closed_by_skipped(ref.edge_type, ref.raw, ref.invalid_shape, main_patterns):
                closed_by_skipped += 1
                continue
            if ref.edge_type == CLOSED_BY_EDGE_TYPE:
                closed_by_refs += 1
            category, reason = classify_ref(ref, node_ids, duplicate_ids, id_patterns)
            classification[category] += 1
            if reason:
                reasons[reason] += 1
            if category == "resolved":
                edges[_edge_key(ref, undirected)].add(ref.source_id)
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
        reference_total=count_reference_values(rows, edge_types, main_patterns),
        undirected=frozenset(undirected),
        closed_by_skipped=closed_by_skipped,
        closed_by_refs=closed_by_refs,
        closed_by_field_total=count_closed_by_values(
            [r for r in rows if r["id"] in nodes], main_patterns
        )[0],
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
        if edge_type in result.undirected:
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
    # closed_by：欄位值總數（不含缺席與 null）＝ 引用值數 ＋ 略過數；略過值不是引用值
    by_parts = counts["closed_by_reference_count"] + counts["closed_by_skipped_count"]
    if counts["closed_by_field_value_total"] != by_parts:
        raise AssertionError("closed_by 欄位值總數 != 引用值 + 略過數")  # i18n-exempt: 開發者工具訊息
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
        "closed_by_skipped_count": result.closed_by_skipped,
        "closed_by_reference_count": result.closed_by_refs,
        "closed_by_field_value_total": result.closed_by_field_total,
    }
    assert_conservation(counts)
    return counts


def row_corpus(row: dict[str, Any]) -> str:
    return row["synthetic_host"] if row["synthetic"] else row["corpus"]


def compute_expected(manifest: dict[str, Any], table: dict[str, Any]) -> dict[str, Any]:
    """只讀 manifest 與型別表；每個語料各建一輪圖。"""
    edge_types = load_edge_types(table)
    id_patterns = compile_id_patterns(table)
    main_patterns = compile_main_graph_patterns(table)
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in manifest["rows"]:
        groups[row_corpus(row)].append(row)
    edges, defects, counts = {}, {}, {}
    for corpus in sorted(groups):
        rows = groups[corpus]
        result = build_graph(rows, edge_types, id_patterns, main_patterns)
        edges[corpus] = edges_output(result)
        defects[corpus] = defects_output(result)
        counts[corpus] = counts_output(result)
        real_rows = [r for r in rows if not r["synthetic"]]
        counts[corpus]["real_only"] = counts_output(build_graph(real_rows, edge_types, id_patterns, main_patterns))
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



def write_json(path: Path, data: Any) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    path.write_text(text, encoding="utf-8")
