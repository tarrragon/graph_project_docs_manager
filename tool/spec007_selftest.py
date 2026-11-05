"""SPEC-007 內嵌單元測試。"""

from __future__ import annotations

import copy
from typing import Any

from spec007_extract import (  # noqa: E402
    CORPUS_FB,
    CORPUS_GPDM,
    COVERS_ALL,
    REASON_DUPLICATED,
    REASON_INVALID_SHAPE,
    REASON_MISSING,
    REASON_PATTERN,
    REASON_SELF,
    builtin_directions,
    compile_id_patterns,
    compile_main_graph_patterns,
    extract_refs,
    load_edge_types,
)
from spec007_graph import (  # noqa: E402
    GraphResult,
    assert_conservation,
    build_graph,
    counts_output,
    declaration_shapes,
    light_node,
)
from spec007_freeze import (  # noqa: E402
    coverage_gaps,
    synthetic_rows,
)
from spec007_readme_check import (  # noqa: E402
    _fmt_sha,
    check_readme,
)


# ---------------------------------------------------------------------------
# selftest
# ---------------------------------------------------------------------------

_TEST_NODE_TYPES = {
    "Ticket": {"id_pattern": r"^[\w.]+-W\d+-\d+(\.\d+)*$"},
    "PROP": {"id_pattern": r"^PROP-\d{3}$"},
    "SPEC": {"id_pattern": r"^SPEC-([0-9]{3}|[A-Z0-9-]+)$"},
    "UC": {"id_pattern": r"^UC-\d{2,}$"},
    # FlowStep 的 id 是流程內區域名稱；其 pattern 會收 none，略過判定須排除（FR-03）
    "FlowStep": {"id_pattern": r"^[a-z][a-z0-9_]*$"},
    "DomainBundle": {"id_pattern": r"^DB-[a-z-]+$"},
}


def _test_table() -> dict[str, Any]:
    def edge(
        fwd: str, card: str, rev: str | None = None, layer: str = "established",
        direction: str = "directed",
    ) -> dict:
        return {
            "direction": direction,
            "forward_field": fwd,
            "reverse_field": rev,
            "forward_cardinality": card,
            "layer": layer,
            "class": "x",
        }

    return {
        "node_types": _TEST_NODE_TYPES,
        "edge_types": {
            "association": edge("relatedTo", "many", direction="undirected"),
            "blocking": edge("blockedBy", "many"),
            "spawn": edge("source_ticket", "one", "spawned_tickets"),
            "provenance": edge("source_proposal", "many", "outputs"),
            "discovery": edge("discovered_during", "one"),
            "domain_dependency": edge("depends_on_domains", "many"),
            "emission": edge("emits", "many", layer="proposed"),
            "bundle_dependency": edge("depends_on_bundles", "many", layer="proposed"),
            "closed_by": edge("closed_by", "one", layer="proposed"),
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
    return build_graph(
        rows, load_edge_types(table), compile_id_patterns(table), compile_main_graph_patterns(table)
    )


def _edge_set(result: GraphResult) -> set[tuple]:
    return {(t, a, b, tuple(sorted(d))) for (t, a, b), d in result.edges.items()}


def _reasons(result: GraphResult) -> list[tuple[str, str, Any]]:
    return sorted((d["kind"], d["reason"], d["raw_value"]) for d in result.ref_defects)


A, B, C = "1.0.0-W1-001", "1.0.0-W1-002", "1.0.0-W1-003"


def _test_edge_types_and_patterns() -> None:
    types = {e.name: e for e in load_edge_types(_test_table())}
    assert set(types) == {"association", "blocking", "spawn", "provenance", "discovery", "domain_dependency", "bundle_dependency", "closed_by"}
    assert types["spawn"].cardinality == "one" and types["provenance"].cardinality == "many"
    no_bundle = copy.deepcopy(_test_table())  # E2 對照：移除 bundle_dependency 條目後集合不同
    del no_bundle["edge_types"]["bundle_dependency"]
    assert {e.name for e in load_edge_types(no_bundle)} == set(types) - {"bundle_dependency"}
    no_closed_by = copy.deepcopy(_test_table())  # E2 對照：移除 closed_by 條目後不再是使用中邊型
    del no_closed_by["edge_types"]["closed_by"]
    assert {e.name for e in load_edge_types(no_closed_by)} == set(types) - {"closed_by"}
    assert "emission" not in types
    no_domain = copy.deepcopy(_test_table())  # E2 對照：移除 domain_dependency 條目後不再是使用中邊型
    del no_domain["edge_types"]["domain_dependency"]
    assert {e.name for e in load_edge_types(no_domain)} == set(types) - {"domain_dependency"}
    changed = copy.deepcopy(_test_table())
    changed["edge_types"]["blocking"]["forward_field"] = "blocks_x"
    rows = [_row(A, blockedBy=[B], blocks_x=[C]), _row(B), _row(C)]
    assert _edge_set(_graph(rows, changed)) == {("blocking", A, C, (A,))}  # E1：改名後不讀舊欄位
    assert _edge_set(_graph(rows)) == {("blocking", A, B, (A,))}


def _test_closed_by_skip_rule() -> None:
    """FR-03〈closed_by 的略過規則〉：外部格式略過、符合格式者照常分類。"""
    rows = [_row(A, closed_by=B), _row(B)]
    result = _graph(rows)  # E2 正向對照：語料內存在的票號必須建邊
    assert _edge_set(result) == {("closed_by", A, B, (A,))} and result.closed_by_skipped == 0
    for external in ("tarrragon/claude#60", "flutter_balance:W4-007", "none"):
        res = _graph([_row(A, closed_by=external), _row(B)])
        assert res.edges == {} and res.ref_defects == [] and res.closed_by_skipped == 1, external
        assert res.reference_total == 0 and res.classification.total() == 0
    missing = _graph([_row(A, closed_by="1.0.0-W1-999")])  # 符合格式但不存在：斷邊，不略過
    assert [d["kind"] for d in missing.ref_defects] == ["danglingRef"] and missing.closed_by_skipped == 0
    shape = _graph([_row(A, closed_by=42)])  # 形狀不合法：格式錯誤，不略過
    assert _reasons(shape) == [("malformedRef", "invalidShape", 42)] and shape.closed_by_skipped == 0
    leaked = _graph([_row(A, source_ticket="tarrragon/claude#60")])  # E2：略過規則不外溢到其他邊型
    assert _reasons(leaked) == [("malformedRef", "patternMismatch", "tarrragon/claude#60")]
    mixed = counts_output(_graph([_row(A, closed_by="none"), _row(B, closed_by=A), _row(C, closed_by=7)]))
    assert mixed["closed_by_field_value_total"] == 3  # = 引用值 2 + 略過 1
    assert mixed["closed_by_reference_count"] == 2 and mixed["closed_by_skipped_count"] == 1
    assert mixed["reference_value_total"] == 2


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


def _test_direction_from_table() -> None:
    rows = [_row(B, relatedTo=[A]), _row(A)]
    assert _edge_set(_graph(rows)) == {("association", A, B, (B,))}
    directed = copy.deepcopy(_test_table())  # E2 對照：association 改 directed 後不再對稱
    directed["edge_types"]["association"]["direction"] = "directed"
    assert _edge_set(_graph(rows, directed)) == {("association", B, A, (B,))}
    both = _graph([_row(B, relatedTo=[A]), _row(A, relatedTo=[B])], directed)
    assert len(both.edges) == 2  # 有向：A->B 與 B->A 不合併
    see_also = copy.deepcopy(_test_table())  # 非鍵名特權：其他邊型改 undirected 即對稱
    see_also["edge_types"]["blocking"]["direction"] = "undirected"
    r = _graph([_row(B, blockedBy=[A]), _row(A, blockedBy=[B])], see_also)
    assert _edge_set(r) == {("blocking", A, B, (A, B))}


def _test_direction_fill_when_missing() -> None:
    """FR-01：缺 direction 依鍵名取內建表；內建表也沒有則 directed。"""
    table = copy.deepcopy(_test_table())
    for spec in table["edge_types"].values():
        del spec["direction"]
    table["edge_types"]["unknown_edge"] = {
        "forward_field": "ux", "reverse_field": None, "forward_cardinality": "many",
        "layer": "established", "class": "x",
    }
    types = {e.name: e for e in load_edge_types(table)}
    assert types["association"].undirected and not types["blocking"].undirected
    assert not types["unknown_edge"].undirected  # 對照：內建表沒有的鍵名不當無向
    stub = {k: v for k, v in builtin_directions().items() if k != "association"}
    assert not {e.name: e for e in load_edge_types(table, stub)}["association"].undirected


def _test_domain_dependency_name_resolution() -> None:
    """FR-11：名稱解析；E2 正向對照＝未宣告名稱是 danglingRef 而非 malformedRef。"""
    rows = [
        _row("DB-a", "DomainBundle", domain="alpha"),
        _row("DB-b", "DomainBundle", domain="beta"),
        _row("DB-d1", "DomainBundle", domain="dup"),
        _row("DB-d2", "DomainBundle", domain="dup"),
        _row("DB-bad", "DomainBundle", domain=7),
        _row("DB-src", "DomainBundle", domain="src",
             depends_on_domains=["alpha", "beta", "ghost", "dup", 42, "Alpha", "alpha"]),
    ]
    result = _graph(rows)
    edges = set(result.edges)
    assert ("domain_dependency", "DB-src", "DB-a") in edges
    assert ("domain_dependency", "DB-src", "DB-b") in edges
    assert len([e for e in edges if e[0] == "domain_dependency"]) == 2
    reasons = _reasons(result)
    assert ("danglingRef", REASON_MISSING, "ghost") in reasons  # E2：未宣告 -> dangling
    assert ("danglingRef", REASON_MISSING, "dup") in reasons  # 重複宣告兩者皆排除
    assert ("danglingRef", REASON_MISSING, "Alpha") in reasons  # 精確比對，區分大小寫
    assert ("malformedRef", REASON_INVALID_SHAPE, 42) in reasons
    assert not any(r[1] == REASON_PATTERN for r in reasons)  # 不走 id_pattern
    c = result.classification
    assert c["resolved"] == 3 and c["dangling"] == 3 and c["malformed"] == 1
    assert result.reference_total == sum(c.values()) == 7  # 守恆式含名稱引用值
    # E2 對照：移除 DB-a 的宣告後 alpha 變 dangling，邊少一條
    fewer = _graph([r for r in rows if r["id"] != "DB-a"])
    assert len([e for e in fewer.edges if e[0] == "domain_dependency"]) == 1
    assert ("danglingRef", REASON_MISSING, "alpha") in _reasons(fewer)


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


def _readme_case() -> tuple[str, dict[str, Any], dict[str, Any], dict[str, Any]]:
    """最小凍結組與依其格式化的 README（格式同真實 README，值全由凍結組帶入）。"""
    sha = {CORPUS_GPDM: "a" * 8 + "0" * 50 + "b" * 6, CORPUS_FB: "c" * 8 + "1" * 50 + "d" * 6}
    manifest = {"header": {
        "frozen_date": "2026-01-02",
        "corpus_commits": {CORPUS_GPDM: {"commit": "1" * 40}, CORPUS_FB: {"commit": "2" * 40}},
        "corpus_snapshots": {
            c: {"docs_md_files": n, "signature_sha256": sha[c]}
            for c, n in ((CORPUS_GPDM, 10), (CORPUS_FB, 20))
        },
    }}

    def real(n: int) -> dict[str, Any]:
        return {
            "node_count": n, "dangling_count": 1, "malformed_count": 2, "edge_count": 7 + n,
            "multi_source_by_edge_type": {"spawn": 3}, "reference_value_total": 9, "resolved_count": 6,
            "edges_by_type": {"closed_by": 4, "uc_ticket_refs": 5, "domain_dependency": 6},
            "closed_by_field_value_total": 9, "closed_by_reference_count": 4, "closed_by_skipped_count": 5,
            "graph_defect_count": 6,
        }

    counts = {c: {**real(n), "real_only": real(n)} for c, n in ((CORPUS_GPDM, 50), (CORPUS_FB, 60))}
    counts[CORPUS_GPDM].update(node_count=51, duplicate_id_count=1, reference_value_total=10, graph_defect_count=7)
    edge = {"edge_type": "spawn", "from": "x", "to": "y", "declared_by": ["y"]}
    edges = {CORPUS_GPDM: [edge, edge], CORPUS_FB: [edge]}
    text = f"""# t

## 量測環境（x）

| 項目 | 值 |
|------|-----|
| 凍結日期 | 2026-01-02（重凍結） |
| {CORPUS_GPDM} | commit `{"1" * 40}`，docs 下 `.md` 10 檔，簽章 sha256 `{_fmt_sha(sha[CORPUS_GPDM])}` |
| {CORPUS_FB} | HEAD `{"2" * 40}`；docs 下 `.md` 20 檔，簽章 sha256 `{_fmt_sha(sha[CORPUS_FB])}` |

## 實測值與版本契約第 2 欄的對照

| 項目 | 預期 | 實測 | 說明 |
|------|------|------|------|
| 節點數 | 1／1 | 50／60 | x |
| 斷邊 | 1／1 | 1／1 | x |
| 格式錯誤 | 1／1 | 2／2 | x |
| `spawn` 只在反向 | 1／1 | 2／1 | x |
| `spawn` `multiSource` | 1／1 | 3／3 | x |
| `provenance` `multiSource` | 0／0 | 0／0 | x |
| 重複 ID、自我引用 | 0／0 | 0（重複 ID）、0／0（自我引用） | 說明格式不核對 |

其他實測（`real_only`）：

| 項目 | 本專案 | flutter_balance |
|------|------|------|
| 引用值總數（獨立計數） | 9 | 9 |
| 解析成功／斷邊／格式錯誤 | 6／1／2 | 6／1／2 |
| 邊數 | 57 | 67 |
| 其中 `closed_by` 邊／`uc_ticket_refs` 邊／`domain_dependency` 邊 | 4／5／6 | 4／5／6 |
| `closed_by` 欄位值總數＝引用值＋略過數 | 9＝4＋5 | 9＝4＋5 |
| `graphDefect` 總數（x） | 6 | 6 |

含合成列的組（本專案）：節點 51、`duplicateId` 1、引用值總數 10、`graphDefect` 7。
"""
    return text, manifest, counts, edges


def _test_readme_check() -> None:
    """E2 正向對照：README 與凍結檔任一欄不一致，check_readme 必須回報該欄位。"""
    text, manifest, counts, edges = _readme_case()
    assert check_readme(text, manifest, counts, edges) == []  # 基準：一致
    cases = {
        f"env.{CORPUS_GPDM}.docs_md_files": ("docs 下 `.md` 10 檔", "docs 下 `.md` 11 檔"),  # i18n-exempt: 開發者工具
        f"env.{CORPUS_FB}.commit": ("2" * 40, "3" * 40),
        f"env.{CORPUS_FB}.signature": ("d" * 6 + "`", "e" * 6 + "`"),
        "env.frozen_date": ("| 2026-01-02（", "| 2026-01-03（"),
        "compare.節點數": ("| 50／60 |", "| 50／61 |"),  # i18n-exempt: 開發者工具
        "compare.spawn 只在反向": ("| 2／1 | x |", "| 3／1 | x |"),  # i18n-exempt: 開發者工具
        "compare.spawn multiSource": ("| 3／3 | x |", "| 3／4 | x |"),  # i18n-exempt: 開發者工具
        "other.gpdm.edge_count": ("| 57 | 67 |", "| 58 | 67 |"),
        "other.fb.typed_edges": ("| 4／5／6 | 4／5／6 |\n| `closed_by`", "| 4／5／6 | 4／5／7 |\n| `closed_by`"),  # i18n-exempt: 開發者工具
        "other.gpdm.closed_by_total": ("| 9＝4＋5 | 9＝4＋5 |", "| 9＝4＋4 | 9＝4＋5 |"),  # i18n-exempt: 開發者工具
        "synthetic_group": ("引用值總數 10", "引用值總數 11"),  # i18n-exempt: 開發者工具
    }
    for key, (old, new) in cases.items():
        assert old in text, key  # 測試自身：置換目標存在，否則對照無鑑別力
        problems = check_readme(text.replace(old, new, 1), manifest, counts, edges)
        assert any(p.startswith(key + ":") for p in problems), (key, problems)
    broken = text.replace("| 邊數 |", "| 邊 |")  # 欄位消失不得靜默通過  # i18n-exempt: 開發者工具
    assert any(p.startswith("other.gpdm.edge_count:") for p in check_readme(broken, manifest, counts, edges))
    frozen_side = copy.deepcopy(counts)  # 反向：改凍結檔端也必須報紅
    frozen_side[CORPUS_FB]["real_only"]["node_count"] = 61
    assert check_readme(text, manifest, frozen_side, edges) != []


def _run_selftests() -> None:
    tests = [
        _test_edge_types_and_patterns,
        _test_closed_by_skip_rule,
        _test_light_node_and_duplicates,
        _test_extraction,
        _test_classification,
        _test_edges_and_multisource,
        _test_association_union,
        _test_direction_from_table,
        _test_direction_fill_when_missing,
        _test_domain_dependency_name_resolution,
        _test_counts_and_conservation,
        _test_reference_total_two_ways_on_fixture,
        _test_coverage_guard,
        _test_readme_check,
    ]
    for test in tests:
        test()
        print(f"ok  {test.__name__}")
    print(f"selftest passed: {len(tests)} groups")
