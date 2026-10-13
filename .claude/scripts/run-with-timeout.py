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

程序群組登記（供 orphan-test-procs.py --kill 依來源終止本腳本被強制終止後遺留的群組）：
- 位置：環境變數 CLAUDE_PROC_REGISTRY_DIR；未設則為系統暫存目錄下的
  claude-run-with-timeout-<uid>/（不在任何 repo 內，故不納入版控）。
  位置與工作目錄無關：主專案與各 git worktree 共用同一個目錄，
  清理端以登記中的工作目錄判斷是否屬於該專案範圍。
- 檔案：wrapper-<本腳本PID>-<啟動時間（非英數字元以 - 取代）>.json，內容為 JSON 物件，欄位：
  pgid、leader_start（群組領頭程序的 ps lstart）、wrapper_pid、wrapper_start、cwd、command（list）。
  先寫同目錄暫存檔再 os.replace 改名。
- 正常結束、逾時、收到轉送訊號三條路徑皆移除登記；被 SIGKILL 時登記留存。
- 登記的任何讀寫失敗只對 stderr 寫一行（開頭 run-with-timeout:）後繼續，不影響命令執行與結束碼。
"""
import json
import os
import re
import tempfile
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


def registry_dir() -> str:
    override = os.environ.get("CLAUDE_PROC_REGISTRY_DIR")
    if override:
        return override
    return os.path.join(tempfile.gettempdir(), f"claude-run-with-timeout-{os.getuid()}")


def process_start(pid: int) -> Optional[str]:
    """ps 的 lstart（秒級）；程序不存在或 ps 失敗回 None。"""
    try:
        res = subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True,
                             text=True, env={**os.environ, "LC_ALL": "C", "TZ": "UTC"})
    except OSError:
        return None
    out = res.stdout.strip()
    return out if res.returncode == 0 and out else None


def _write_atomically(path: str, entry: dict) -> None:
    """寫同目錄暫存檔再改名；任何失敗皆清除暫存檔後重新拋出。"""
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(entry, fh)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass  # 暫存檔已不存在（例如已改名）；原例外照常拋出
        raise


def register_group(pgid: int, command: List[str]) -> Optional[str]:
    """寫入登記並回傳登記檔路徑；任何失敗回 None（只寫 stderr 一行）。"""
    try:
        leader_start = process_start(pgid)
        wrapper_start = process_start(os.getpid())
        if leader_start is None or wrapper_start is None:
            raise OSError("取不到啟動時間")
        entry = {"pgid": pgid, "leader_start": leader_start, "wrapper_pid": os.getpid(),
                 "wrapper_start": wrapper_start, "cwd": os.getcwd(), "command": command}
        directory = registry_dir()
        os.makedirs(directory, mode=0o700, exist_ok=True)
        # 檔名含啟動時間：PID 繞回時不覆蓋舊登記
        stamp = re.sub(r"[^0-9A-Za-z]+", "-", wrapper_start)
        path = os.path.join(directory, f"wrapper-{os.getpid()}-{stamp}.json")
        _write_atomically(path, entry)
        return path
    except (OSError, ValueError) as exc:
        sys.stderr.write(f"run-with-timeout: 無法寫入程序群組登記（不影響命令）：{exc}\n")
        return None


def unregister_group(path: Optional[str]) -> None:
    if path is None:
        return
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    except OSError as exc:
        sys.stderr.write(f"run-with-timeout: 無法移除程序群組登記（不影響命令）：{exc}\n")


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
    registration: List[Optional[str]] = [None]  # 先裝訊號處理器再登記，避免登記期間收到訊號而漏轉送

    def forward(signum, _frame):
        terminate_group(pgid, leader=proc)
        proc.wait()
        unregister_group(registration[0])
        sys.exit(128 + signum)

    for sig in FORWARDED_SIGNALS:
        signal.signal(sig, forward)
    registration[0] = register_group(pgid, command)

    try:
        returncode = proc.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        terminate_group(pgid, leader=proc)
        proc.wait()
        unregister_group(registration[0])
        return TIMEOUT_EXIT_CODE
    # 直接子程序已結束，清掉遺留的孫程序
    _signal_group(pgid, signal.SIGKILL)
    unregister_group(registration[0])
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
