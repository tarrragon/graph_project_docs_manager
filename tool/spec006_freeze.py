"""SPEC-006 參照實作離線凍結子命令 freeze-it1／freeze-it2，由 spec006_reference 拆出。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from spec006_core import (
    FRONTMATTER_DELIMITER,
    FileClassification,
    RESULT_EMPTY_OR_NON_MAP,
    RESULT_NO_FRONTMATTER,
    RESULT_UNCLOSED,
    RESULT_USABLE,
    SchemaTypeTable,
    classify_file,
    classify_text,
    contains_excluded_line_separator,
    naive_split_classify,
    read_file,
    scan_markdown_files,
    strip_bom,
)


# 五個框架語料專案（SPEC-006 D3；與 docs/system-layer.md §5 量測範圍一致）。
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
