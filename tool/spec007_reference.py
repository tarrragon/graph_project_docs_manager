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
  compute   只讀 manifest 與型別表重算 expected；不帶 --out-dir 時與現有檔案比對，並核對 README 凍結資訊
執行時機：凍結時離線執行，CI 不執行。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from spec007_extract import (  # noqa: E402
    FIXTURE_DIR,
)
from spec007_graph import (  # noqa: E402
    compute_expected,
    expected_files,
    write_json,
)
from spec007_freeze import (  # noqa: E402
    _cmd_freeze,
)
from spec007_readme_check import (  # noqa: E402
    README_NAME,
    check_readme,
)
from spec007_selftest import (  # noqa: E402
    _run_selftests,
)


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
        # 只比對值（corpora）；header 的 reference_version 隨參照實作升版，凍結檔不重寫
        if frozen["corpora"] != json.loads(json.dumps(data))["corpora"]:
            bad.append(name)
    readme_problems = check_readme(
        (fixture_dir / README_NAME).read_text(encoding="utf-8"),
        manifest,
        json.loads((fixture_dir / "expected_counts.json").read_text(encoding="utf-8"))["corpora"],
        json.loads((fixture_dir / "expected_edges.json").read_text(encoding="utf-8"))["corpora"],
    )
    print("recompute matches frozen values" if not bad else f"mismatch: {bad}")
    print("README matches frozen values" if not readme_problems else "README mismatch:")
    for problem in readme_problems:
        print(f"  {problem}")
    sys.exit(1 if bad or readme_problems else 0)



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
