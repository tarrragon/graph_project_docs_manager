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
from pathlib import Path

from spec006_core import (  # noqa: F401  # re-export for spec007_freeze
    FileClassification,
    ReadResult,
    RESULT_USABLE,
    SchemaTypeTable,
    classify_file,
    classify_text,
    load_type_table,
    read_file,
    scan_markdown_files,
)
from spec006_freeze import _cmd_freeze_it1, _cmd_freeze_it2
from spec006_selftest import _run_selftests


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
