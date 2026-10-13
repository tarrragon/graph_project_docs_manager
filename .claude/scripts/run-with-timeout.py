#!/usr/bin/env python3
"""以程序群組為單位的逾時包裝。

用法：run-with-timeout.py <秒數> -- <命令> [引數...]

結束碼：
- 124：逾時，整個程序群組已終止
- 126：命令無法執行（無執行權限、執行格式錯誤等啟動失敗）
- 127：找不到命令或其直譯器
- 128+訊號編號：子程序被訊號終止；或本腳本收到 TERM／INT／HUP，此時先終止整個群組
- 2：用法錯誤
- 其餘：原樣回傳子程序結束碼

命令自身也可能回 126 或 127；本腳本輸出的訊息一律以「run-with-timeout:」開頭，可據此區分。

命令在期限內結束後（不論結束碼），同一程序群組內仍存活的程序立即以 KILL 終止、無寬限；
已自行脫離群組的程序不在此列。
"""
import os
import signal
import subprocess
import sys
import time
from typing import List, Optional

TIMEOUT_EXIT_CODE = 124
COMMAND_NOT_FOUND_EXIT_CODE = 127
COMMAND_NOT_EXECUTABLE_EXIT_CODE = 126
# TERM 後給子程序清理的寬限秒數；過短會截斷正常收尾，過長拖慢逾時回應
GRACE_SECONDS = 3.0
POLL_INTERVAL = 0.05
FORWARDED_SIGNALS = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)
USAGE = (
    "用法：run-with-timeout.py <秒數> -- <命令> [引數...]\n"
    "結束碼：124 逾時／126 無法執行／127 找不到命令／其餘為命令自身結束碼\n"
)


def _signal_group(pgid: int, sig: int) -> None:
    """對整個群組送訊號；群組已不存在，或群組內沒有本程序可送訊號的成員時忽略。"""
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
        pass
    except PermissionError:
        # EPERM 表示群組內沒有本程序可送訊號的成員。已知成因：macOS 上群組僅剩未回收的殭屍。
        # 成員全屬其他使用者時同樣落入此處，本腳本不處理該情形。
        pass


def _group_alive(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        # macOS 上僅剩未回收的殭屍成員時回 EPERM；視為仍存在，由呼叫端回收領頭程序
        return True
    return True


def terminate_group(pgid: int, grace: float = GRACE_SECONDS, leader=None) -> None:
    """先 TERM，寬限後群組內仍有存活者則 KILL。leader 為群組領頭 Popen，用於回收殭屍。"""
    _signal_group(pgid, signal.SIGTERM)
    deadline = time.monotonic() + grace
    while time.monotonic() < deadline and _group_alive(pgid):
        if leader is not None:
            leader.poll()
        time.sleep(POLL_INTERVAL)
    _signal_group(pgid, signal.SIGKILL)


def _exit_code_of(returncode: int) -> int:
    return 128 - returncode if returncode < 0 else returncode


def _report_start_failure(name: str, error: OSError) -> int:
    """命令無法啟動時輸出單行訊息；找不到回 127，其餘啟動失敗回 126。"""
    if isinstance(error, FileNotFoundError):
        # shebang 指向不存在的直譯器時同樣是 ENOENT，此時 name 所指的檔案本身存在
        sys.stderr.write(
            f"run-with-timeout: 找不到命令或其直譯器：{name}（確認路徑、PATH 與 shebang）\n")
        return COMMAND_NOT_FOUND_EXIT_CODE
    sys.stderr.write(f"run-with-timeout: 無法執行命令：{name}（{error.strerror}）\n")
    return COMMAND_NOT_EXECUTABLE_EXIT_CODE


def run(seconds: float, command: List[str]) -> int:
    try:
        proc = subprocess.Popen(command, start_new_session=True)
    except OSError as error:
        return _report_start_failure(command[0], error)
    pgid = proc.pid

    def forward(signum, _frame):
        terminate_group(pgid, leader=proc)
        proc.wait()
        sys.exit(128 + signum)

    for sig in FORWARDED_SIGNALS:
        signal.signal(sig, forward)

    try:
        returncode = proc.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        terminate_group(pgid, leader=proc)
        proc.wait()
        return TIMEOUT_EXIT_CODE
    # 直接子程序已結束，清掉遺留的孫程序
    _signal_group(pgid, signal.SIGKILL)
    return _exit_code_of(returncode)


def main(argv: Optional[List[str]] = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) < 3 or args[1] != "--":
        sys.stderr.write(USAGE)
        return 2
    try:
        seconds = float(args[0])
    except ValueError:
        sys.stderr.write(f"run-with-timeout: 秒數不是數字：{args[0]}\n{USAGE}")
        return 2
    return run(seconds, args[2:])


if __name__ == "__main__":
    sys.exit(main())
