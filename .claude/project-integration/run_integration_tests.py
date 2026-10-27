#!/usr/bin/env python3
"""逐檔執行 integration_test 下的 *_test.dart，彙總結束碼（合併閘門 flutter-integration 套件用）。

為何逐檔：同一次 `flutter test integration_test -d macos` 依序啟動兩個 macOS App 時，第二個確定性
無法啟動（2026-10-21 重現實驗 RED 5/5，逐檔 GREEN 10/10）。

結束碼：全部通過 0；任一檔失敗 1；找不到任何測試檔 2；總逾時 3。
總逾時：全部檔案共用 900 秒預算（merge_gate 的 SUITE_TIMEOUT_SECONDS 為全域 3600 秒、不支援逐套件
逾時，故在此實作）；超時以 killpg 終止整個程序群組（含 flutter_tester 與 App），並印 TIMEOUT_MESSAGE。
名額：閘門持有者的子程序，本腳本直接啟動 fvm，不經 run-with-timeout，故不會再取名額。
"""
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Callable, Iterable, List, Tuple

TEST_DIR = "integration_test"
TEST_SUFFIX = "_test.dart"
EXIT_FAILED = 1
EXIT_NO_TESTS = 2
EXIT_TIMEOUT = 3
TOTAL_TIMEOUT_SECONDS = 900
READER_JOIN_SECONDS = 5
# 逾時訊息字面；merge-gate.yaml 的 failure 正規式須含它
# i18n-exempt: 開發者工具 stderr 診斷，非 App UI
TIMEOUT_MESSAGE = f"[ERROR] integration 逾時（{TOTAL_TIMEOUT_SECONDS} 秒）"
# 啟動失敗字面（與 merge-gate.yaml 的 failure 正規式一致）；即使 flutter 結束碼為 0 也視為失敗
START_FAILURE_MARKERS = ("Unable to start the app", "Error waiting for a debug connection")


class SuiteTimeout(Exception):
    """總預算耗盡；子程序群組已被終止。"""


def discover_tests(root: Path) -> List[str]:
    """遞迴列舉 *_test.dart（與 flutter test integration_test 同規則），排序固定，回傳相對 root 的路徑。"""
    base = root / TEST_DIR
    return sorted(p.relative_to(root).as_posix() for p in base.rglob(f"*{TEST_SUFFIX}") if p.is_file())


def kill_group(proc: subprocess.Popen) -> None:
    """終止子程序所屬的整個程序群組（start_new_session 令 pgid == pid）。"""
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass  # 群組已不存在，無需終止


def run_streaming(test_file: str, deadline: float = float("inf"),
                  clock: Callable[[], float] = time.monotonic) -> Tuple[int, str]:
    """執行單檔並即時串流輸出，回傳 (結束碼, 完整輸出)；超過 deadline 則殺群組並拋 SuiteTimeout。"""
    proc = subprocess.Popen(["fvm", "flutter", "test", test_file, "-d", "macos"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace",
                            start_new_session=True)
    chunks: List[str] = []

    def pump() -> None:
        for line in proc.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            chunks.append(line)

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()
    try:
        code = proc.wait(timeout=max(0.0, deadline - clock()))
    except subprocess.TimeoutExpired:
        kill_group(proc)
        proc.wait()
        raise SuiteTimeout()
    kill_group(proc)  # 正常結束後清掃可能殘留的孫程序
    reader.join(timeout=READER_JOIN_SECONDS)
    return code, "".join(chunks)


def file_failed(returncode: int, output: str) -> bool:
    return returncode != 0 or any(m in output for m in START_FAILURE_MARKERS)


def run_all(files: Iterable[str], runner: Callable[[str], Tuple[int, str]] = run_streaming) -> int:
    """逐檔執行並彙總；失敗不中止後續檔（一次列出全部失敗），任一失敗整體非 0；逾時立即中止。"""
    files = list(files)
    if not files:
        # i18n-exempt: 開發者工具 stderr 診斷，非 App UI
        sys.stderr.write(f"[ERROR] {TEST_DIR} 下找不到 *{TEST_SUFFIX}，視為失敗\n")
        return EXIT_NO_TESTS
    failed = []
    for f in files:
        print(f"== integration: {f}", flush=True)
        try:
            code, output = runner(f)
        except SuiteTimeout:
            # i18n-exempt: 開發者工具 stderr 診斷，非 App UI
            sys.stderr.write(f"{TIMEOUT_MESSAGE}，卡在 {f}\n")
            return EXIT_TIMEOUT
        if file_failed(code, output):
            failed.append(f)
    if failed:
        # i18n-exempt: 開發者工具 stderr 診斷，非 App UI
        sys.stderr.write(f"[ERROR] integration 失敗 {len(failed)}/{len(files)}：{', '.join(failed)}\n")
        return EXIT_FAILED
    return 0


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    deadline = time.monotonic() + TOTAL_TIMEOUT_SECONDS
    return run_all(discover_tests(root), lambda f: run_streaming(f, deadline))


if __name__ == "__main__":
    sys.exit(main())
