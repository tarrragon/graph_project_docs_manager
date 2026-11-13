#!/usr/bin/env python3
"""逐檔執行 integration_test 下的 *_test.dart，彙總結束碼（合併閘門 flutter-integration 套件用）。

為何逐檔：同一次 `flutter test integration_test -d macos` 依序啟動兩個 macOS App 時，第二個確定性
無法啟動（2026-10-21 重現實驗 RED 5/5，逐檔 GREEN 10/10）。

結束碼：全部通過 0；任一檔失敗 1；找不到任何測試檔 2；單檔逾時 3。
單檔逾時：每個檔各自有 300 秒上限、各自起算，前一檔耗時不扣後一檔（merge_gate 的 SUITE_TIMEOUT_SECONDS
為全域 3600 秒、不支援逐套件逾時，故在此實作）；超時以 killpg 終止整個程序群組（含 flutter_tester 與
App），並印含檔名的 TIMEOUT_MESSAGE。改自舊的 900 秒全檔共用預算：檔數增至 12 後總預算失準，
高負載下連續兩次逾時（ffe408c4cc55、e9c8ebfc606f）。
上限依據（.claude/logs/merge-gate-failures/ 的 bebcfabc933a、ffe408c4cc55 兩份 integration log）：
flutter 輸出的單檔測試時間最大為 app_test 約 55 秒（含冷建置的首檔），其餘 0～28 秒；12 檔全跑完的
總耗時 473～660 秒，平均單檔含建置與 pub 解析約 40～55 秒；swap 高時耗時約加倍，故取 300 秒
（約觀測最大單檔的 2～3 倍）。
收集範圍：只收 integration_test 頂層的 *_test.dart，與 CI（.github/workflows/macos-integration.yml 的
`integration_test/*_test.dart` 非遞迴 glob）一致。integration_test/perf/ 是 Profiler 探針，需 profile 模式與
driver，不屬逐檔 `flutter test` 範圍；手動執行：
`fvm flutter drive --profile -d macos --driver=test_driver/perf_driver.dart
--target=integration_test/perf/ticket_list_perf_test.dart`（見該檔檔頭）。
名額：閘門持有者的子程序，本腳本直接啟動 fvm，不經 run-with-timeout，故不會再取名額。
"""
import argparse
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Callable, Iterable, List, Optional, Tuple

TEST_DIR = "integration_test"
TEST_SUFFIX = "_test.dart"
EXIT_FAILED = 1
EXIT_NO_TESTS = 2
EXIT_TIMEOUT = 3
EXIT_USAGE = 64  # sysexits EX_USAGE；避開 1/2/3 已用值，--help 與未知參數共用
FILE_TIMEOUT_SECONDS = 300
READER_JOIN_SECONDS = 5
# 逾時訊息字面；merge-gate.yaml 的 failure 正規式須含它
# i18n-exempt: 開發者工具 stderr 診斷，非 App UI
TIMEOUT_MESSAGE = f"[ERROR] integration 逾時（單檔 {FILE_TIMEOUT_SECONDS} 秒）"
# 啟動失敗字面（與 merge-gate.yaml 的 failure 正規式一致）；即使 flutter 結束碼為 0 也視為失敗
START_FAILURE_MARKERS = ("Unable to start the app", "Error waiting for a debug connection")


class SuiteTimeout(Exception):
    """單檔逾時；子程序群組已被終止。"""


def discover_tests(root: Path) -> List[str]:
    """非遞迴列舉 integration_test 頂層的 *_test.dart（與 CI 的 `integration_test/*_test.dart` glob 一致），
    排序固定，回傳相對 root 的路徑。子目錄（如 perf/ 探針）不收集。"""
    base = root / TEST_DIR
    return sorted(p.relative_to(root).as_posix() for p in base.glob(f"*{TEST_SUFFIX}") if p.is_file())


def kill_group(proc: subprocess.Popen) -> None:
    """終止子程序所屬的整個程序群組（start_new_session 令 pgid == pid）。"""
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass  # 群組已不存在，無需終止


def run_streaming(test_file: str, deadline: float = float("inf"),
                  clock: Callable[[], float] = time.monotonic) -> Tuple[int, str]:
    """執行單檔並即時串流輸出，回傳 (結束碼, 完整輸出)；超過 deadline（呼叫端每檔各自給）則殺群組並拋 SuiteTimeout。"""
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


def make_runner(stream: Optional[Callable] = None, clock: Callable[[], float] = time.monotonic,
                limit: float = FILE_TIMEOUT_SECONDS) -> Callable[[str], Tuple[int, str]]:
    """每個檔呼叫時才以 clock() + limit 起算 deadline，前一檔耗時不影響後一檔。"""
    def runner(test_file: str) -> Tuple[int, str]:
        return (stream or run_streaming)(test_file, clock() + limit)
    return runner


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


class _UsageParser(argparse.ArgumentParser):
    """用法錯誤改用 EXIT_USAGE（argparse 預設 2 會與 EXIT_NO_TESTS 混淆）。"""

    def error(self, message: str) -> None:
        self.print_usage(sys.stderr)
        sys.stderr.write(f"{self.prog}: error: {message}\n")
        raise SystemExit(EXIT_USAGE)


def parse_args(argv: Optional[List[str]]) -> int:
    """解析參數；本腳本無參數。--help 回傳 EXIT_USAGE，未知參數拋 SystemExit(EXIT_USAGE)，無參數回傳 0。"""
    # i18n-exempt: 開發者工具用法說明，非 App UI
    parser = _UsageParser(description="逐檔執行 integration_test（不接受任何參數）", add_help=False)
    # i18n-exempt: 開發者工具用法說明，非 App UI
    parser.add_argument("-h", "--help", action="store_true", help="顯示用法後結束（結束碼 64，不執行測試）")
    if parser.parse_args(argv).help:
        parser.print_help()
        return EXIT_USAGE
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    usage_code = parse_args(argv)
    if usage_code:
        return usage_code
    root = Path(__file__).resolve().parents[2]
    return run_all(discover_tests(root), make_runner())


if __name__ == "__main__":
    sys.exit(main())
