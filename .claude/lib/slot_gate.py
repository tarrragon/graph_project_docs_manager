#!/usr/bin/env python3
"""
本機名額閘門（2026-10-14）

heavy 命令（全套件測試、編譯）以 flock 取得全機名額後才執行，由 run-with-timeout.py 呼叫。

- 名額由持有程序的 flock 綁定其存活期間；正常結束、逾時、被 SIGKILL 皆由核心釋放。
  鎖檔描述符預設不可繼承，子程序殘存不佔用名額。
- 鎖目錄：CLAUDE_SLOT_LOCK_DIR；未設則為 ~/.cache/claude-slot。刻意不用 TMPDIR／XDG_RUNTIME_DIR：
  它們是環境變數，不同 session 的值可能不同，名額會變成每份值一份；固定的共用 /tmp 路徑則可被其他
  本機使用者搶先建立或換成 symlink。
- 目錄以 0o700 建立，並以 lstat 驗證：必須是目錄（非 symlink）、屬於目前使用者、群組與其他人不可寫入
  （mode & 0o077 == 0）；任一不符即略過閘門。鎖檔與 holder 暫存檔以 O_NOFOLLOW 開啟。
- 以 CLAUDE_SLOT_LOCK_DIR 覆寫時，其父目錄須為本人擁有且不可被他人寫入：驗證只涵蓋最末層目錄，
  父目錄若可被他人改名或替換，驗證通過後的路徑仍可能被換掉。
- 等待以輪詢進行，不保證先到先得（釋放瞬間由先輪詢到的等待者取得）。
- 閘門的任何讀寫失敗只對 stderr 寫一行（開頭 run-with-timeout:）後略過閘門，不阻擋命令。
- 孤兒提示：heavy 命令取得名額後、啟動命令前，以子程序執行 orphan-test-procs.py（不帶 --kill，只列出）
  查詢本專案孤兒；有則於 stderr 印出數量與清理指令，無則不輸出；查詢失敗或逾時（ORPHAN_QUERY_TIMEOUT_SECONDS）
  只寫一行 stderr，不阻擋命令。light 命令不經過閘門，故不查詢。CLAUDE_ORPHAN_SCRIPT、
  CLAUDE_ORPHAN_QUERY_TIMEOUT 可覆寫查詢腳本與逾時（測試用）。
- 持有者的子程序不重複取得名額：持有者在持有期間把自己的 pid 放入環境變數 HELD_ENV（export_hold），
  子程序內的 run-with-timeout 經 is_heavy_command 判定為免排隊。標記僅在「該 pid 仍存在且名額確實全被占用」
  時有效（held_by_ancestor），殘留的過期標記不會讓 heavy 命令繞過閘門。
- CLAUDE_SLOT_WAIT_LIMIT、CLAUDE_SLOT_NOTICE_INTERVAL（秒）可覆寫等待上限與提示間隔（測試用）。
"""
import fcntl
import contextlib
import json
import os
import re
import stat
import subprocess
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
# 孤兒查詢的逾時：查詢只是提示，慢於此值寧可放棄也不拖慢 heavy 命令啟動
ORPHAN_QUERY_TIMEOUT_SECONDS = 5.0
ORPHAN_CLEANUP_COMMAND = "python3 .claude/scripts/orphan-test-procs.py --kill"
_ORPHAN_SUMMARY_RE = re.compile(r"^符合 (\d+) 略過 (\d+) 疑似殘留 (\d+)$", re.MULTILINE)
WAITED_REPORT_THRESHOLD = SLOT_POLL_INTERVAL


def _warn(message: str, label: str = "run-with-timeout") -> None:
    sys.stderr.write(f"{label}: {message}\n")


# 持有名額的程序在持有期間放入環境，其子程序據此免重複取得（否則自我死鎖）
HELD_ENV = "CLAUDE_SLOT_HELD_BY"
# 持有期間子程序的名額等待上限（秒）：子程序認得標記時根本不等待，會等代表兩邊 slot_gate 版本不一致，
# 此時快速失敗，不讓持有者占住全機名額直到預設上限
HELD_CHILD_WAIT_LIMIT_SECONDS = 30


def _all_slots_busy(directory: str) -> bool:
    """每個名額的鎖檔目前都被某程序持有（不符合即立刻放回剛取得的鎖）。"""
    for index in range(SLOT_COUNT):
        try:
            fd = os.open(os.path.join(directory, f"heavy-slot-{index}.lock"), os.O_RDWR | os.O_NOFOLLOW)
        except OSError:
            return False  # 鎖檔不存在或不可開：沒有人持有
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return False
        except BlockingIOError:
            pass  # 此名額有人持有，檢查下一個
        finally:
            os.close(fd)
    return True


def held_by_ancestor() -> bool:
    """環境標記指向仍存在的程序，且名額確實被占用。標記格式錯誤或任何查驗失敗皆視為未持有。"""
    raw = os.environ.get(HELD_ENV)
    if not raw:
        return False
    try:
        return not _pid_gone(int(raw)) and _all_slots_busy(slot_dir())
    except (ValueError, OSError):
        return False  # 標記不是整數或目錄不可查：不免排隊，由正常取得流程處理


# 保存 export_hold 之前的 CLAUDE_SLOT_WAIT_LIMIT；空字串表示當時未設定
_LIMIT_BEFORE_ENV = "CLAUDE_SLOT_WAIT_LIMIT_BEFORE_HOLD"
_LIMIT_ENV = "CLAUDE_SLOT_WAIT_LIMIT"


@contextlib.contextmanager
def export_hold(hold: "SlotHold"):
    """持有期間把本程序 pid 放入環境供直接子層的 run-with-timeout 辨識，並把其等待上限降為
    HELD_CHILD_WAIT_LIMIT_SECONDS；離開時還原原值。

    標記只給直接子層：run-with-timeout 啟動被包裝命令時須以 child_env 去除，不得往下傳。
    """
    names = (HELD_ENV, _LIMIT_ENV, _LIMIT_BEFORE_ENV)
    previous = {n: os.environ.get(n) for n in names}
    os.environ[_LIMIT_BEFORE_ENV] = os.environ.get(_LIMIT_ENV, "")
    os.environ[HELD_ENV] = str(os.getpid())
    os.environ[_LIMIT_ENV] = str(HELD_CHILD_WAIT_LIMIT_SECONDS)
    try:
        yield hold
    finally:
        for n, v in previous.items():
            if v is None:
                os.environ.pop(n, None)
            else:
                os.environ[n] = v


def child_env(env: "os._Environ") -> dict:
    """被包裝命令的環境：去除持有標記，等待上限還原為持有前的值（持有前未設定則移除）。

    沒有持有標記時原樣複製。
    """
    out = dict(env)
    if HELD_ENV not in out:
        return out
    out.pop(HELD_ENV)
    before = out.pop(_LIMIT_BEFORE_ENV, None)
    if before:
        out[_LIMIT_ENV] = before
    elif before is not None:
        out.pop(_LIMIT_ENV, None)
    return out


def is_heavy_command(command: List[str]) -> bool:
    """依 test_command_parse 判定；判定本身失敗時保守視為 heavy（只多排隊）。

    祖先程序已持有名額時回 False：呼叫端據此略過取得，避免對同一名額自我死鎖。
    """
    if held_by_ancestor():
        return False
    try:
        from lib.test_command_parse import WEIGHT_HEAVY, classify_argv_weight
        return classify_argv_weight(command) == WEIGHT_HEAVY
    except Exception as exc:  # 任何判定失敗都不得讓包裝程序以 traceback 結束
        _warn(f"heavy 判定失敗，視為 heavy：{exc}")
        return True


def slot_dir() -> str:
    return os.environ.get("CLAUDE_SLOT_LOCK_DIR") or os.path.join(
        os.path.expanduser("~"), ".cache", "claude-slot")


def _owner_uid() -> int:
    return os.getuid()


def _prepare_dir(directory: str) -> None:
    """建立（0o700）並驗證鎖目錄；不符安全條件拋 PermissionError，呼叫端據此略過閘門。"""
    os.makedirs(directory, mode=0o700, exist_ok=True)
    info = os.lstat(directory)  # lstat 不跟隨 symlink
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
        raise PermissionError(f"{directory} 不是一般目錄（symlink 或其他類型），不使用")
    if info.st_uid != _owner_uid():
        raise PermissionError(f"{directory} 不屬於目前使用者，不使用")
    if info.st_mode & 0o077:
        raise PermissionError(f"{directory} 權限允許群組或其他人存取（{info.st_mode & 0o777:o}），不使用")


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


def _current_load() -> str:
    """當下 load（每次印出時重新取，不沿用持有者記錄的值）。"""
    try:
        return "/".join(f"{x:.2f}" for x in os.getloadavg())
    except OSError:
        return "不可得"


def describe_holder(directory: str) -> str:
    """讀出第一個可讀的持有者資訊；持有者 pid 已不存在時標示資訊過期。"""
    for index in range(SLOT_COUNT):
        try:
            with open(_holder_path(directory, index)) as fh:
                info = json.load(fh)
            text = (f"持有者 pid={info['pid']} cwd={info['cwd']} 命令={' '.join(info['command'])} "
                    f"開始={info['started']} load={_current_load()}")
            if _pid_gone(int(info["pid"])):
                text += "（資訊過期：該 pid 已不存在，名額應很快釋放）"
            return text
        except (OSError, ValueError, KeyError, TypeError):
            continue  # 持有者剛取得、尚未寫出資訊，或資訊檔已隨持有者結束移除
    return "持有者資訊暫不可讀"


def _write_holder(directory: str, index: int, command: List[str]) -> Optional[str]:
    path = _holder_path(directory, index)
    tmp = f"{path}.{os.getpid()}.tmp"
    try:
        entry = {"pid": os.getpid(), "cwd": os.getcwd(), "command": command,
                 "started": time.strftime("%Y-%m-%d %H:%M:%S"),
                 "load": "/".join(f"{x:.2f}" for x in os.getloadavg())}
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as fh:
            json.dump(entry, fh)
        os.replace(tmp, path)
        return path
    except OSError as exc:
        _warn(f"無法寫入名額持有者資訊（不影響命令）：{exc}")
        try:
            os.unlink(tmp)
        except OSError:
            pass  # 暫存檔未建立或已改名，無需清理
        return None


def _remove_stale_tmp(directory: str) -> None:
    """刪除持有者 pid 已不存在的 holder 暫存檔（寫入中途被 SIGKILL 的殘留）。"""
    try:
        names = os.listdir(directory)
    except OSError:
        return
    for name in names:
        if not (name.startswith("heavy-slot-") and name.endswith(".tmp")):
            continue
        try:
            pid = int(name[:-len(".tmp")].rsplit(".", 1)[1])
        except (ValueError, IndexError):
            continue
        if _pid_gone(pid):
            try:
                os.unlink(os.path.join(directory, name))
            except OSError:
                pass  # 已被他方清除


def _try_acquire(directory: str) -> Optional[Tuple[int, int]]:
    """依序嘗試各名額；回 (fd, index) 或 None。"""
    for index in range(SLOT_COUNT):
        fd = os.open(os.path.join(directory, f"heavy-slot-{index}.lock"), os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
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
                 interrupted: Callable[[], Optional[int]],
                 label: str = "run-with-timeout") -> Tuple[Optional[SlotHold], Optional[int]]:
    """排隊取得名額；回 (SlotHold 或 None, 提前結束碼或 None)。

    interrupted 回傳等待期間收到的訊號編號（無則 None）。label 為提示行前綴，讓不同呼叫端的等待提示可區分來源。持有者為 None 且無結束碼表示閘門失效而略過。
    """
    directory = slot_dir()
    limit = _env_seconds("CLAUDE_SLOT_WAIT_LIMIT", SLOT_WAIT_LIMIT_SECONDS)
    interval = _env_seconds("CLAUDE_SLOT_NOTICE_INTERVAL", SLOT_NOTICE_INTERVAL_SECONDS)
    waited_since = time.monotonic()
    next_notice = waited_since
    while True:
        try:
            _prepare_dir(directory)
            got = _try_acquire(directory)
        except OSError as exc:
            _warn(f"名額閘門無法使用，略過排隊（不影響命令）：{exc}", label)
            return None, None
        if got is not None:
            fd, index = got
            waited = time.monotonic() - waited_since
            if waited >= WAITED_REPORT_THRESHOLD:
                _warn(f"取得名額，已等待 {waited:.1f} 秒", label)
            _remove_stale_tmp(directory)
            return SlotHold(fd, _write_holder(directory, index, command)), None
        signum = interrupted()
        if signum is not None:
            return None, 128 + signum
        now = time.monotonic()
        if now - waited_since >= limit:
            _warn(f"等待名額超過 {limit:g} 秒，放棄執行。{describe_holder(directory)}", label)
            return None, SLOT_WAIT_EXIT_CODE
        if now >= next_notice:
            _warn(f"等待名額：{describe_holder(directory)}；已等待 {now - waited_since:.0f} 秒", label)
            next_notice = now + interval
        time.sleep(SLOT_POLL_INTERVAL)


def _orphan_script() -> str:
    return os.environ.get("CLAUDE_ORPHAN_SCRIPT") or os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "orphan-test-procs.py")


def count_orphans() -> Tuple[int, int]:
    """列出本專案孤兒，回 (可清理, 疑似殘留)；可清理 = 符合 + 可終止的登記群組。

    疑似殘留不會被 --kill 處理，故分開計數。任何失敗拋 RuntimeError 並附原因。
    """
    timeout = _env_seconds("CLAUDE_ORPHAN_QUERY_TIMEOUT", ORPHAN_QUERY_TIMEOUT_SECONDS)
    try:
        res = subprocess.run([sys.executable, _orphan_script()], capture_output=True, text=True,
                             timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"查詢逾時（{timeout:g} 秒）")
    except OSError as exc:
        raise RuntimeError(f"無法執行查詢：{exc}")
    found = _ORPHAN_SUMMARY_RE.findall(res.stdout)
    if res.returncode not in (0, 1) or not found:
        raise RuntimeError(f"查詢失敗（結束碼 {res.returncode}，無法解析輸出）")
    matched, _skipped, suspects = (int(x) for x in found[-1])
    registered = sum(1 for line in res.stdout.splitlines() if line.startswith("登記可終止"))
    return matched + registered, suspects


def report_orphans() -> None:
    """有孤兒則印出數量；可清理者附清理指令，疑似殘留者要求人工核對。永不拋例外。"""
    try:
        cleanable, suspects = count_orphans()
    except Exception as exc:  # 提示性查詢，任何失敗都不得影響命令
        _warn(f"孤兒程序查詢失敗，略過提示（不影響命令）：{exc}")
        return
    parts = []
    if cleanable:
        parts.append(f"可清理 {cleanable} 個孤兒測試程序（會佔用記憶體），清理：{ORPHAN_CLEANUP_COMMAND}")
    if suspects:
        parts.append(f"疑似殘留 {suspects} 棵程序樹，清理指令不會處理，需人工核對後逐一終止"
                     "（列表見 orphan-test-procs.py 不帶參數的輸出）")
    if parts:
        _warn("偵測到" + "；".join(parts))
