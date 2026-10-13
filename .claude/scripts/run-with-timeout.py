#!/usr/bin/env python3
"""以程序群組為單位的逾時包裝。

用法：run-with-timeout.py <秒數> -- <命令> [引數...]

結束碼：逾時 124；未逾時透傳子程序結束碼；子程序被訊號終止回 128+訊號編號。
"""
import os
import signal
import subprocess
import sys
import time
from typing import List, Optional

TIMEOUT_EXIT_CODE = 124
# TERM 後給子程序清理的寬限秒數；過短會截斷正常收尾，過長拖慢逾時回應
GRACE_SECONDS = 3.0
POLL_INTERVAL = 0.05
FORWARDED_SIGNALS = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)


def _signal_group(pgid: int, sig: int) -> None:
    """對整個群組送訊號；群組已不存在時忽略。"""
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
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


def run(seconds: float, command: List[str]) -> int:
    proc = subprocess.Popen(command, start_new_session=True)
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
        sys.stderr.write("用法：run-with-timeout.py <秒數> -- <命令> [引數...]\n")
        return 2
    return run(float(args[0]), args[2:])


if __name__ == "__main__":
    sys.exit(main())
