#!/usr/bin/env python3
"""以程序群組為單位的逾時包裝。

用法：run-with-timeout.py <秒數> -- <命令> [引數...]

結束碼：
- 124：逾時，整個程序群組已終止
- 126：命令無法執行（無執行權限、執行格式錯誤等啟動失敗）
- 127：找不到命令或其直譯器
- 128+訊號編號：子程序被訊號終止；或本腳本收到 TERM／INT／HUP／QUIT，此時先終止整個群組
- 125：heavy 命令等待本機名額超過上限（SLOT_WAIT_LIMIT_SECONDS），stderr 指名持有者；命令未執行
- 2：用法錯誤
- 其餘：原樣回傳子程序結束碼

命令自身也可能回 126 或 127；本腳本輸出的訊息（含用法訊息）一律以「run-with-timeout:」開頭，可據此區分。

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
- 正常結束、逾時、收到轉送訊號、內部例外四條路徑皆移除登記；被 SIGKILL 時登記留存。
- 登記的任何讀寫失敗只對 stderr 寫一行（開頭 run-with-timeout:）後繼續，不影響命令執行與結束碼。

本機名額閘門（2026-10-14）：
- 命令經 lib.test_command_parse.classify_argv_weight 判為 heavy（未指定具體測試檔的 flutter／dart test、
  integration_test、flutter build、xcodebuild、未指定具體測試檔的 pytest；launcher 開頭而判不出 runner 者
  保守視為 heavy）時，先以 flock 取得全機名額（SLOT_COUNT 個）才啟動命令；light 命令不排隊。
- 逾時計時從取得名額、啟動命令之後才開始，排隊時間不計入。
- 等待期間每 SLOT_NOTICE_INTERVAL_SECONDS 秒於 stderr 印出持有者的 pid、cwd、命令、開始時間與當下 load。
- 名額由本程序持有的 flock 綁定其存活期間：正常結束、逾時、被 SIGKILL 皆由核心釋放，不依賴任何 hook；
  鎖檔描述符不會被子程序繼承（子程序殘存不佔用名額）。
- 鎖與持有者資訊放在 CLAUDE_SLOT_LOCK_DIR；未設則與程序群組登記同一目錄（見上）。
  CLAUDE_SLOT_WAIT_LIMIT、CLAUDE_SLOT_NOTICE_INTERVAL（秒）可覆寫等待上限與提示間隔（測試用）。
- 閘門的任何讀寫失敗只對 stderr 寫一行後略過閘門直接執行命令（fail-open，不阻擋命令）。
"""
import fcntl
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
SLOT_WAIT_EXIT_CODE = 125
# 同時執行的 heavy 命令數（全機）；2026-10-14 swap 耗盡事件後定為 1
SLOT_COUNT = 1
# 排隊上限：超過代表持有者異常久，與其無限掛起不如回報讓呼叫端決策
SLOT_WAIT_LIMIT_SECONDS = 3600.0
SLOT_NOTICE_INTERVAL_SECONDS = 30.0
SLOT_POLL_INTERVAL = 0.1
# TERM 後給子程序清理的寬限秒數；過短會截斷正常收尾，過長拖慢逾時回應
GRACE_SECONDS = 3.0
POLL_INTERVAL = 0.05
FORWARDED_SIGNALS = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP, signal.SIGQUIT)
USAGE = (
    "run-with-timeout: 用法：run-with-timeout.py <秒數> -- <命令> [引數...]\n"
    "結束碼：124 逾時／126 無法執行／127 找不到命令／2 用法錯誤／"
    "125 等候名額逾上限／128+訊號編號 被訊號終止／其餘為命令自身結束碼\n"
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


class _SignalRecorder:
    """轉送訊號只記錄、不在處理器內清理：清理由主流程在輪詢中執行。

    處理器內不做等待與離開，故清理期間再收到訊號不會蓋掉結束碼，也不爭用鎖。
    """

    def __init__(self) -> None:
        self.received: Optional[int] = None

    def install(self) -> None:
        for sig in FORWARDED_SIGNALS:
            signal.signal(sig, self._record)

    def _record(self, signum, _frame) -> None:
        if self.received is None:
            self.received = signum


def _wait_or_signal(proc, seconds: float, recorder: _SignalRecorder) -> Optional[int]:
    """等直接子程序結束；逾時回 None，收到轉送訊號時提早回 None（由呼叫端查 recorder）。"""
    deadline = time.monotonic() + seconds
    while recorder.received is None:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        try:
            return proc.wait(timeout=min(POLL_INTERVAL, remaining))
        except subprocess.TimeoutExpired:
            continue
    return None


def is_heavy_command(command: List[str]) -> bool:
    """依 lib.test_command_parse 判定；模組載入失敗時保守視為 heavy（只多排隊）。"""
    try:
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        from lib.test_command_parse import WEIGHT_HEAVY, classify_argv_weight
    except ImportError as exc:
        sys.stderr.write(f"run-with-timeout: 無法載入 heavy 判定，視為 heavy：{exc}\n")
        return True
    return classify_argv_weight(command) == WEIGHT_HEAVY


def slot_dir() -> str:
    return os.environ.get("CLAUDE_SLOT_LOCK_DIR") or registry_dir()


def _env_seconds(name: str, default: float) -> float:
    try:
        return float(os.environ[name])
    except (KeyError, ValueError):
        return default


def _holder_path(directory: str, index: int) -> str:
    return os.path.join(directory, f"heavy-slot-{index}.holder.json")


def _describe_holder(directory: str) -> str:
    """讀出第一個可讀的持有者資訊；讀不到時說明原因而不拋例外。"""
    for index in range(SLOT_COUNT):
        try:
            with open(_holder_path(directory, index)) as fh:
                info = json.load(fh)
            return (f"持有者 pid={info['pid']} cwd={info['cwd']} 命令={' '.join(info['command'])} "
                    f"開始={info['started']} load={info['load']}")
        except (OSError, ValueError, KeyError, TypeError):
            continue  # 持有者剛取得、尚未寫出資訊，或資訊檔已隨持有者結束移除
    return "持有者資訊暫不可讀"


def _write_holder(directory: str, index: int, command: List[str]) -> Optional[str]:
    path = _holder_path(directory, index)
    entry = {"pid": os.getpid(), "cwd": os.getcwd(), "command": command,
             "started": time.strftime("%Y-%m-%d %H:%M:%S"),
             "load": "/".join(f"{x:.2f}" for x in os.getloadavg())}
    try:
        _write_atomically(path, entry)
        return path
    except OSError as exc:
        sys.stderr.write(f"run-with-timeout: 無法寫入名額持有者資訊（不影響命令）：{exc}\n")
        return None


def _try_acquire(directory: str):
    """依序嘗試各名額；回 (fd, index) 或 None。鎖檔描述符預設不可繼承，子程序不會持有。"""
    for index in range(SLOT_COUNT):
        fd = os.open(os.path.join(directory, f"heavy-slot-{index}.lock"), os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return fd, index
        except BlockingIOError:
            os.close(fd)
    return None


class SlotHold:
    """持有中的名額；release 先移除持有者資訊再關閉鎖檔描述符。"""

    def __init__(self, fd: int, holder_path: Optional[str]) -> None:
        self.fd = fd
        self.holder_path = holder_path

    def release(self) -> None:
        if self.holder_path is not None:
            try:
                os.unlink(self.holder_path)
            except OSError:
                pass  # 資訊檔已不存在；鎖由 close 釋放，不影響正確性
        os.close(self.fd)


def acquire_slot(command: List[str], recorder: "_SignalRecorder"):
    """排隊取得名額；回 (SlotHold 或 None, 提前結束碼或 None)。None 持有者表示閘門失效而略過。"""
    directory = slot_dir()
    limit = _env_seconds("CLAUDE_SLOT_WAIT_LIMIT", SLOT_WAIT_LIMIT_SECONDS)
    interval = _env_seconds("CLAUDE_SLOT_NOTICE_INTERVAL", SLOT_NOTICE_INTERVAL_SECONDS)
    waited_since = time.monotonic()
    next_notice = waited_since
    while True:
        try:
            os.makedirs(directory, mode=0o700, exist_ok=True)
            got = _try_acquire(directory)
        except OSError as exc:
            sys.stderr.write(f"run-with-timeout: 名額閘門無法使用，略過排隊（不影響命令）：{exc}\n")
            return None, None
        if got is not None:
            fd, index = got
            waited = time.monotonic() - waited_since
            if waited >= SLOT_POLL_INTERVAL:
                sys.stderr.write(f"run-with-timeout: 取得名額，已等待 {waited:.1f} 秒\n")
            return SlotHold(fd, _write_holder(directory, index, command)), None
        if recorder.received is not None:
            return None, 128 + recorder.received
        now = time.monotonic()
        if now - waited_since >= limit:
            sys.stderr.write(f"run-with-timeout: 等待名額超過 {limit:g} 秒，放棄執行。"
                             f"{_describe_holder(directory)}\n")
            return None, SLOT_WAIT_EXIT_CODE
        if now >= next_notice:
            sys.stderr.write(f"run-with-timeout: 等待名額：{_describe_holder(directory)}；"
                             f"已等待 {now - waited_since:.0f} 秒\n")
            next_notice = now + interval
        time.sleep(SLOT_POLL_INTERVAL)


def run(seconds: float, command: List[str]) -> int:
    recorder = _SignalRecorder()
    recorder.install()  # 先於等待名額與啟動子程序安裝，期間的訊號都不會走預設終止動作
    hold = None
    if is_heavy_command(command):
        hold, early = acquire_slot(command, recorder)
        if early is not None:
            return early
    try:
        return _run_command(seconds, command, recorder)
    finally:
        if hold is not None:
            hold.release()


def _run_command(seconds: float, command: List[str], recorder: _SignalRecorder) -> int:
    try:
        proc = subprocess.Popen(command, start_new_session=True)
    except OSError as error:
        return _report_start_failure(command[0], error)
    pgid = proc.pid
    registration: Optional[str] = None
    finished = False
    code = TIMEOUT_EXIT_CODE
    try:
        registration = register_group(pgid, command)
        returncode = _wait_or_signal(proc, seconds, recorder)
        if returncode is not None:
            finished = True
            code = _exit_code_of(returncode)
        elif recorder.received is not None:
            code = 128 + recorder.received
    finally:
        # 正常結束只清孫程序；逾時、收到訊號、內部例外皆終止整個群組
        if finished:
            _signal_group(pgid, signal.SIGKILL)
        else:
            terminate_group(pgid, leader=proc)
            proc.wait()
        unregister_group(registration)
    return code


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
