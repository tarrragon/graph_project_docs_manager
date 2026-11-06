"""SPEC-006 參照實作內嵌單元測試，由 spec006_reference 的 selftest 子命令呼叫。
"""

from __future__ import annotations

from pathlib import Path

from spec006_core import (
    RESULT_EMPTY_OR_NON_MAP,
    RESULT_NO_FRONTMATTER,
    RESULT_UNCLOSED,
    RESULT_USABLE,
    RESULT_YAML_ERROR,
    SchemaTypeTable,
    UNREADABLE_ENCODING,
    UNREADABLE_MISSING,
    classify_file,
    classify_text,
    contains_excluded_line_separator,
    load_type_table,
    naive_split_classify,
    read_file,
    scan_markdown_files,
)


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
