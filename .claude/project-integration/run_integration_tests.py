#!/usr/bin/env python3
"""逐檔執行 integration_test 下的 *_test.dart，彙總結束碼（合併閘門 flutter-integration 套件用）。

為何逐檔：同一次 `flutter test integration_test -d macos` 依序啟動兩個 macOS App 時，第二個確定性
無法啟動（2026-10-21 重現實驗 RED 5/5，逐檔 GREEN 10/10）。

結束碼：全部通過 0；任一檔失敗 1；找不到任何測試檔 2。
名額：閘門持有者的子程序，本腳本直接啟動 fvm，不經 run-with-timeout，故不會再取名額。
"""
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable, List, Tuple

TEST_DIR = "integration_test"
TEST_SUFFIX = "_test.dart"
EXIT_FAILED = 1
EXIT_NO_TESTS = 2
# 啟動失敗字面（與 merge-gate.yaml 的 failure 正規式一致）；即使 flutter 結束碼為 0 也視為失敗
START_FAILURE_MARKERS = ("Unable to start the app", "Error waiting for a debug connection")


def discover_tests(root: Path) -> List[str]:
    """遞迴列舉 *_test.dart（與 flutter test integration_test 同規則），排序固定，回傳相對 root 的路徑。"""
    base = root / TEST_DIR
    return sorted(p.relative_to(root).as_posix() for p in base.rglob(f"*{TEST_SUFFIX}") if p.is_file())


def run_streaming(test_file: str) -> Tuple[int, str]:
    """執行單檔並即時串流輸出，回傳 (結束碼, 完整輸出)。"""
    proc = subprocess.Popen(["fvm", "flutter", "test", test_file, "-d", "macos"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
    chunks = []
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        chunks.append(line)
    return proc.wait(), "".join(chunks)


def file_failed(returncode: int, output: str) -> bool:
    return returncode != 0 or any(m in output for m in START_FAILURE_MARKERS)


def run_all(files: Iterable[str], runner: Callable[[str], Tuple[int, str]] = run_streaming) -> int:
    """逐檔執行並彙總；失敗不中止後續檔（一次列出全部失敗），任一失敗整體非 0。"""
    files = list(files)
    if not files:
        # i18n-exempt: 開發者工具 stderr 診斷，非 App UI
        sys.stderr.write(f"[ERROR] {TEST_DIR} 下找不到 *{TEST_SUFFIX}，視為失敗\n")
        return EXIT_NO_TESTS
    failed = []
    for f in files:
        print(f"== integration: {f}", flush=True)
        code, output = runner(f)
        if file_failed(code, output):
            failed.append(f)
    if failed:
        # i18n-exempt: 開發者工具 stderr 診斷，非 App UI
        sys.stderr.write(f"[ERROR] integration 失敗 {len(failed)}/{len(files)}：{', '.join(failed)}\n")
        return EXIT_FAILED
    return 0


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    return run_all(discover_tests(root))


if __name__ == "__main__":
    sys.exit(main())
