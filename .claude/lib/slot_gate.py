#!/usr/bin/env python3
"""
本機名額閘門（2026-10-14）

heavy 命令（全套件測試、編譯）以 flock 取得全機名額後才執行，由 run-with-timeout.py 呼叫。

- 名額由持有程序的 flock 綁定其存活期間；正常結束、逾時、被 SIGKILL 皆由核心釋放。
  鎖檔描述符預設不可繼承，子程序殘存不佔用名額。
- 鎖目錄：CLAUDE_SLOT_LOCK_DIR；未設則為固定路徑 /tmp/claude-slot-<uid>。刻意不用
  tempfile.gettempdir()：不同 session 的 TMPDIR 可能不同，名額會變成每個 TMPDIR 一份。
- 等待以輪詢進行，不保證先到先得（釋放瞬間由先輪詢到的等待者取得）。
- 閘門的任何讀寫失敗只對 stderr 寫一行（開頭 run-with-timeout:）後略過閘門，不阻擋命令。
- CLAUDE_SLOT_WAIT_LIMIT、CLAUDE_SLOT_NOTICE_INTERVAL（秒）可覆寫等待上限與提示間隔（測試用）。
"""
import fcntl
import json
import os
import sys
import time
from typing import Callable, List, Optional, Tuple

SLOT_WAIT_EXIT_CODE = 125
# 同時執行的 heavy 命令數（全機）；2026-10-14 swap 耗盡事件後定為 1
SLOT_COUNT = 1
# 排隊上限：超過代表持有者異常久，與其無限掛起不如回報讓呼叫端決策
SLOT_WAIT_LIMIT_SECONDS = 3600.0
SLOT_NOTICE_INTERVAL_SECONDS = 30.0
SLOT_POLL_INTERVAL = 0.1
WAITED_REPORT_THRESHOLD = SLOT_POLL_INTERVAL


def _warn(message: str) -> None:
    sys.stderr.write(f"run-with-timeout: {message}\n")


def is_heavy_command(command: List[str]) -> bool:
    """依 test_command_parse 判定；判定本身失敗時保守視為 heavy（只多排隊）。"""
    try:
        from lib.test_command_parse import WEIGHT_HEAVY, classify_argv_weight
        return classify_argv_weight(command) == WEIGHT_HEAVY
    except Exception as exc:  # 任何判定失敗都不得讓包裝程序以 traceback 結束
        _warn(f"heavy 判定失敗，視為 heavy：{exc}")
        return True


def slot_dir() -> str:
    return os.environ.get("CLAUDE_SLOT_LOCK_DIR") or f"/tmp/claude-slot-{os.getuid()}"


def _env_seconds(name: str, default: float) -> float:
    try:
        return float(os.environ[name])
    except (KeyError, ValueError):
        return default


def _holder_path(directory: str, index: int) -> str:
    return os.path.join(directory, f"heavy-slot-{index}.holder.json")


def _pid_gone(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    except (PermissionError, OSError):
        return False  # EPERM 表示程序存在
    return False


def describe_holder(directory: str) -> str:
    """讀出第一個可讀的持有者資訊；持有者 pid 已不存在時標示資訊過期。"""
    for index in range(SLOT_COUNT):
        try:
            with open(_holder_path(directory, index)) as fh:
                info = json.load(fh)
            text = (f"持有者 pid={info['pid']} cwd={info['cwd']} 命令={' '.join(info['command'])} "
                    f"開始={info['started']} load={info['load']}")
            if _pid_gone(int(info["pid"])):
                text += "（資訊過期：該 pid 已不存在，名額應很快釋放）"
            return text
        except (OSError, ValueError, KeyError, TypeError):
            continue  # 持有者剛取得、尚未寫出資訊，或資訊檔已隨持有者結束移除
    return "持有者資訊暫不可讀"


def _write_holder(directory: str, index: int, command: List[str]) -> Optional[str]:
    path = _holder_path(directory, index)
    try:
        entry = {"pid": os.getpid(), "cwd": os.getcwd(), "command": command,
                 "started": time.strftime("%Y-%m-%d %H:%M:%S"),
                 "load": "/".join(f"{x:.2f}" for x in os.getloadavg())}
        with open(path, "w") as fh:  # 讀者容忍半寫入內容（describe_holder 攔 ValueError）
            json.dump(entry, fh)
        return path
    except OSError as exc:
        _warn(f"無法寫入名額持有者資訊（不影響命令）：{exc}")
        return None


def _try_acquire(directory: str) -> Optional[Tuple[int, int]]:
    """依序嘗試各名額；回 (fd, index) 或 None。"""
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


def acquire_slot(command: List[str],
                 interrupted: Callable[[], Optional[int]]) -> Tuple[Optional[SlotHold], Optional[int]]:
    """排隊取得名額；回 (SlotHold 或 None, 提前結束碼或 None)。

    interrupted 回傳等待期間收到的訊號編號（無則 None）。持有者為 None 且無結束碼表示閘門失效而略過。
    """
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
            _warn(f"名額閘門無法使用，略過排隊（不影響命令）：{exc}")
            return None, None
        if got is not None:
            fd, index = got
            waited = time.monotonic() - waited_since
            if waited >= WAITED_REPORT_THRESHOLD:
                _warn(f"取得名額，已等待 {waited:.1f} 秒")
            return SlotHold(fd, _write_holder(directory, index, command)), None
        signum = interrupted()
        if signum is not None:
            return None, 128 + signum
        now = time.monotonic()
        if now - waited_since >= limit:
            _warn(f"等待名額超過 {limit:g} 秒，放棄執行。{describe_holder(directory)}")
            return None, SLOT_WAIT_EXIT_CODE
        if now >= next_notice:
            _warn(f"等待名額：{describe_holder(directory)}；已等待 {now - waited_since:.0f} 秒")
            next_notice = now + interval
        time.sleep(SLOT_POLL_INTERVAL)
