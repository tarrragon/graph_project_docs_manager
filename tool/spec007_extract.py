"""SPEC-007 型別表、引用抽取與引用值計數。"""

from __future__ import annotations

import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any



REFERENCE_VERSION = "1.3.1"  # 對應 SPEC-007 v1.40
NAME_RESOLVED_EDGE_TYPE = "domain_dependency"  # SPEC-007 FR-11／D6：引用值是 domain 名稱，走名稱索引
DOMAIN_BUNDLE_TYPE = "DomainBundle"
DOMAIN_FIELD = "domain"
INCLUDED_PROPOSED_EDGE_TYPES = frozenset({"bundle_dependency", "closed_by"})  # SPEC-007 D6：納入的 proposed 層邊型
CLOSED_BY_EDGE_TYPE = "closed_by"  # SPEC-007 FR-03〈closed_by 的略過規則〉（D6 第三處鍵名例外）
FLOW_STEP_TYPE = "FlowStep"  # FR-10：不進主圖，略過判定時排除其 id_pattern
DIRECTION_UNDIRECTED = "undirected"  # SPEC-007 FR-05：無向由 direction 欄判定
BUILTIN_SCHEMA_RELATIVE = Path("assets/schema/builtin_tracking_schema.json")
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
    undirected: bool = False


def builtin_directions() -> dict[str, str]:
    """內建表的 direction（FR-01 缺欄補值來源）。"""
    path = Path(__file__).resolve().parent.parent / BUILTIN_SCHEMA_RELATIVE
    builtin = json.loads(path.read_text(encoding="utf-8"))
    return {k: v["direction"] for k, v in builtin["edge_types"].items() if "direction" in v}


def resolve_direction(name: str, spec: dict[str, Any], builtin: dict[str, str]) -> str:
    """FR-01：型別表有 direction 用之；缺欄依鍵名取內建表；內建表也沒有則 directed。"""
    return spec.get("direction") or builtin.get(name, "directed")


def is_active_edge_type(name: str, layer: str) -> bool:
    """FR-01／D6：established（含 domain_dependency，v1.38 起）加 proposed 的 bundle_dependency、closed_by。"""
    return layer == "established" or name in INCLUDED_PROPOSED_EDGE_TYPES


def load_edge_types(
    table: dict[str, Any], builtin: dict[str, str] | None = None
) -> list[EdgeType]:
    """FR-01：使用中邊型見 is_active_edge_type；欄位、基數、方向取自型別表。"""
    builtin = builtin_directions() if builtin is None else builtin
    result = []
    for name, spec in table["edge_types"].items():
        if not is_active_edge_type(name, spec["layer"]):
            continue
        result.append(
            EdgeType(
                name=name,
                forward_field=spec["forward_field"],
                reverse_field=spec.get("reverse_field"),
                cardinality=spec["forward_cardinality"],
                undirected=resolve_direction(name, spec, builtin) == DIRECTION_UNDIRECTED,
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


def compile_main_graph_patterns(table: dict[str, Any]) -> list[re.Pattern[str]]:
    """closed_by 外部格式判定用：主圖節點型別的 id_pattern，排除 FlowStep（FR-03、FR-10）。"""
    return [
        re.compile(spec["id_pattern"])
        for name, spec in table["node_types"].items()
        if spec.get("id_pattern") and name != FLOW_STEP_TYPE
    ]


def is_closed_by_skipped(
    edge_type: str, raw: Any, invalid_shape: bool, main_patterns: list[re.Pattern[str]]
) -> bool:
    """字串值且不符合任何主圖節點型別 id_pattern 才略過；形狀不合法不略過。"""
    return (
        edge_type == CLOSED_BY_EDGE_TYPE
        and not invalid_shape
        and isinstance(raw, str)
        and not any(p.match(raw) for p in main_patterns)
    )


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


def _closed_by_units(value: Any) -> list[Any]:
    """獨立於 extract_refs：closed_by 欄位值（不含缺席、null、空字串）逐項攤平。"""
    if value is None or value == "":
        return []
    if isinstance(value, list):
        return [item for item in value if item is not None]
    return [value]


def count_closed_by_values(
    rows: list[dict[str, Any]], main_patterns: list[re.Pattern[str]]
) -> tuple[int, int]:
    """(closed_by 欄位值總數, 其中外部格式略過數)；重複 ID 的節點不計（FR-02）。"""
    id_counts = Counter(row["id"] for row in rows)
    field_total = skipped = 0
    for row in rows:
        if id_counts[row["id"]] > 1:
            continue
        for item in _closed_by_units(row.get("edge_fields", {}).get(CLOSED_BY_EDGE_TYPE)):
            field_total += 1
            if isinstance(item, str) and not any(p.match(item) for p in main_patterns):
                skipped += 1
    return field_total, skipped


def count_reference_values(
    rows: list[dict[str, Any]],
    edge_types: list[EdgeType],
    main_patterns: list[re.Pattern[str]] | None = None,
) -> int:
    """遍歷 manifest 各列 edge_fields 計數；重複 ID 的節點不計（FR-02）；扣 closed_by 略過值。"""
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
    if main_patterns is not None and any(e.name == CLOSED_BY_EDGE_TYPE for e in edge_types):
        total -= count_closed_by_values(rows, main_patterns)[1]
    return total
