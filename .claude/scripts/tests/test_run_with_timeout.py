"""run-with-timeout.py 測試：僅使用暫存目錄與會自行結束的替身程序。"""
import importlib.util
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "run-with-timeout.py"
STAND_IN_LIFETIME = 30  # 替身程序存活上限（秒），保證測試即使失敗也會自行收尾

# 替身：產生握住輸出管線的孫程序，把兩者 PID 寫入檔案後等待
PARENT_SRC = """
import os, signal, subprocess, sys, time
pidfile, ignore_term = sys.argv[1], sys.argv[2] == "1"
if ignore_term:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
grand = subprocess.Popen([sys.executable, "-c",
    "import signal,time\\nif %r: signal.signal(signal.SIGTERM, signal.SIG_IGN)\\ntime.sleep(LIFE)" % ignore_term])
open(pidfile, "w").write("%d %d" % (os.getpid(), grand.pid))
time.sleep(LIFE)
""".replace("LIFE", str(STAND_IN_LIFETIME))


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def _read_pids(pidfile: Path):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if pidfile.exists() and len(pidfile.read_text().split()) == 2:
            return [int(p) for p in pidfile.read_text().split()]
        time.sleep(0.05)
    raise AssertionError("替身未寫出 PID")


def _wait_dead(pids, within=8.0):
    deadline = time.monotonic() + within
    while time.monotonic() < deadline and any(_alive(p) for p in pids):
        time.sleep(0.05)
    return [p for p in pids if _alive(p)]


@pytest.fixture
def stand_in(tmp_path):
    parent = tmp_path / "parent.py"
    parent.write_text(PARENT_SRC)
    pidfile = tmp_path / "pids"
    yield parent, pidfile
    if pidfile.exists() and len(pidfile.read_text().split()) == 2:
        for pid in _read_pids(pidfile):
            try:
                os.kill(pid, signal.SIGKILL)  # 以記下的 PID 清理
            except ProcessLookupError:
                pass


def _cmd(parent, pidfile, ignore_term="0", seconds="1"):
    return [sys.executable, str(SCRIPT), seconds, "--",
            sys.executable, str(parent), str(pidfile), ignore_term]


def test_timeout_kills_child_and_grandchild_exit_124(stand_in):
    parent, pidfile = stand_in
    res = subprocess.run(_cmd(parent, pidfile), capture_output=True, timeout=25)
    assert res.returncode == 124
    assert _wait_dead(_read_pids(pidfile)) == []


def _load_module():
    spec = importlib.util.spec_from_file_location("rwt", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_contrast_kill_direct_child_only_leaves_grandchild(stand_in):
    """變異：群組終止改為只終止直接子程序，孫程序存活，
    即上一測試的斷言（_wait_dead == []）在此變異下會翻紅。"""
    parent, pidfile = stand_in
    mod = _load_module()
    mod.terminate_group = lambda pgid, grace=0, leader=None: os.kill(pgid, signal.SIGKILL)
    assert mod.run(1, [sys.executable, str(parent), str(pidfile), "0"]) == 124
    survivors = _wait_dead(_read_pids(pidfile), within=1.0)
    assert survivors, "變異版應遺留孫程序"


def test_passthrough_exit_code_and_output():
    res = subprocess.run(
        [sys.executable, str(SCRIPT), "10", "--", sys.executable, "-c",
         "import sys;print('out');sys.stderr.write('err\\n');sys.exit(7)"],
        capture_output=True, text=True, timeout=20)
    assert (res.returncode, res.stdout, res.stderr) == (7, "out\n", "err\n")


def test_command_not_found_exit_127_single_line_message():
    res = subprocess.run(
        [sys.executable, str(SCRIPT), "5", "--", "no-such-command-for-run-with-timeout"],
        capture_output=True, text=True, timeout=20)
    assert res.returncode == 127
    assert len(res.stderr.strip().splitlines()) == 1
    assert "Traceback" not in res.stderr


def _assert_single_line_no_traceback(stderr: str) -> None:
    assert len(stderr.strip().splitlines()) == 1
    assert "Traceback" not in stderr
    assert stderr.startswith("run-with-timeout:")


def test_not_executable_file_exit_126_single_line_message(tmp_path):
    target = tmp_path / "no-exec-bit"
    target.write_text("#!/bin/sh\nexit 0\n")
    target.chmod(0o644)
    res = subprocess.run([sys.executable, str(SCRIPT), "5", "--", str(target)],
                         capture_output=True, text=True, timeout=20)
    assert res.returncode == 126
    _assert_single_line_no_traceback(res.stderr)


def test_exec_format_error_exit_126_single_line_message(tmp_path):
    """有執行權限但無 shebang 的文字檔：啟動失敗不屬找不到也不屬權限不足。"""
    target = tmp_path / "no-shebang"
    target.write_text("not a program\n")
    target.chmod(0o755)
    res = subprocess.run([sys.executable, str(SCRIPT), "5", "--", str(target)],
                         capture_output=True, text=True, timeout=20)
    assert res.returncode == 126
    _assert_single_line_no_traceback(res.stderr)


def test_non_numeric_seconds_exit_2_without_traceback():
    res = subprocess.run([sys.executable, str(SCRIPT), "abc", "--", "true"],
                         capture_output=True, text=True, timeout=20)
    assert res.returncode == 2
    assert "Traceback" not in res.stderr
    assert "abc" in res.stderr


def test_child_killed_by_signal_exit_128_plus_signum():
    res = subprocess.run(
        [sys.executable, str(SCRIPT), "10", "--", sys.executable, "-c",
         "import os,signal;os.kill(os.getpid(),signal.SIGKILL)"],
        capture_output=True, timeout=20)
    assert res.returncode == 128 + signal.SIGKILL


def _wait_zombie(pid: int, within=10.0) -> None:
    """等到程序結束但未被回收（ps 狀態欄以 Z 開頭），逾期拋 AssertionError。

    以輪詢 ps 判定，因 os.waitid（WNOWAIT）在 macOS 的 Python 不提供。
    """
    deadline = time.monotonic() + within
    stat = ""
    while time.monotonic() < deadline:
        stat = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)],
                              capture_output=True, text=True).stdout.strip()
        if stat.startswith("Z"):
            return
        time.sleep(0.2)
    raise AssertionError(
        f"程序 {pid} 於 {within} 秒內未進入殭屍狀態"
        f"（最後 ps 狀態：{stat!r}，空字串表示程序已不存在）")


@pytest.fixture
def zombie_only_group():
    """領頭程序已結束但未回收的程序群組。"""
    proc = subprocess.Popen([sys.executable, "-c", "pass"], start_new_session=True)
    try:
        _wait_zombie(proc.pid)
        yield proc.pid
    finally:
        proc.wait()


def test_signal_zombie_only_group_does_not_raise(zombie_only_group):
    mod = _load_module()
    for sig in (signal.SIGTERM, signal.SIGKILL):
        mod._signal_group(zombie_only_group, sig)


def test_group_alive_on_zombie_only_group_reports_alive(zombie_only_group):
    """領頭程序尚未回收時群組仍算存在，由呼叫端回收後才轉為不存在。"""
    mod = _load_module()
    assert mod._group_alive(zombie_only_group) is True


@pytest.mark.skipif(
    sys.platform != "darwin",
    reason="僅於 macOS 實測到對殭屍群組送訊號回 EPERM；其他平台不保證拋例外，對照不成立")
def test_contrast_raw_killpg_on_zombie_only_group_raises(zombie_only_group):
    """對照：同一群組不經保護直接送訊號會拋 PermissionError。

    即移除 _signal_group 或 _group_alive 的 PermissionError 處理時，
    test_signal_zombie_only_group_does_not_raise 與
    test_group_alive_on_zombie_only_group_reports_alive 在 macOS 上會翻紅。
    """
    for sig in (0, signal.SIGKILL):
        with pytest.raises(PermissionError):
            os.killpg(zombie_only_group, sig)


def test_wrapper_term_ends_whole_group(stand_in):
    parent, pidfile = stand_in
    wrapper = subprocess.Popen(_cmd(parent, pidfile, seconds="20"),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        pids = _read_pids(pidfile)
        wrapper.send_signal(signal.SIGTERM)
        wrapper.wait(timeout=15)
        assert _wait_dead(pids) == []
    finally:
        if wrapper.poll() is None:
            wrapper.kill()


def test_term_ignoring_child_is_killed_within_bound(stand_in):
    parent, pidfile = stand_in
    start = time.monotonic()
    res = subprocess.run(_cmd(parent, pidfile, "1"), capture_output=True, timeout=25)
    elapsed = time.monotonic() - start
    assert res.returncode == 124
    assert _wait_dead(_read_pids(pidfile)) == []
    assert elapsed < 1 + 3.0 + 5  # 逾時 + 寬限 + 餘裕


# ---- 程序群組登記（寫入端；讀取端見 test_orphan_test_procs.py）----

REG_FIELDS = {"pgid", "leader_start", "wrapper_pid", "wrapper_start", "cwd", "command"}
LIST_REG_SRC = ("import os,sys,time;time.sleep(1);d=os.environ['CLAUDE_PROC_REGISTRY_DIR'];"
                "print(len([n for n in os.listdir(d) if n.endswith('.json')]))")


def _reg_files(d: Path):
    return sorted(p for p in d.iterdir() if p.name.endswith(".json")) if d.exists() else []


def _env(d: Path):
    return {**os.environ, "CLAUDE_PROC_REGISTRY_DIR": str(d)}


def _wait_reg(d: Path, within=10.0):
    deadline = time.monotonic() + within
    while time.monotonic() < deadline:
        if _reg_files(d):
            return _reg_files(d)[0]
        time.sleep(0.05)
    raise AssertionError("登記未出現")


def test_registry_written_during_run_and_removed_after_normal_exit(tmp_path):
    reg = tmp_path / "reg"
    res = subprocess.run([sys.executable, str(SCRIPT), "10", "--", sys.executable, "-c", LIST_REG_SRC],
                         capture_output=True, text=True, timeout=20, env=_env(reg))
    assert (res.returncode, res.stdout.strip()) == (0, "1")  # 執行期間登記存在
    assert _reg_files(reg) == []


def test_registry_removed_after_timeout(stand_in, tmp_path):
    parent, pidfile = stand_in
    reg = tmp_path / "reg"
    res = subprocess.run(_cmd(parent, pidfile), capture_output=True, timeout=25, env=_env(reg))
    assert res.returncode == 124
    assert _reg_files(reg) == []


def test_registry_removed_after_term_and_content_has_fields(stand_in, tmp_path):
    import json
    parent, pidfile = stand_in
    reg = tmp_path / "reg"
    wrapper = subprocess.Popen(_cmd(parent, pidfile, seconds="20"), env=_env(reg),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        pids = _read_pids(pidfile)
        data = json.loads(_wait_reg(reg).read_text())
        assert set(data) == REG_FIELDS
        assert data["pgid"] == pids[0] and data["wrapper_pid"] == wrapper.pid
        wrapper.send_signal(signal.SIGTERM)
        wrapper.wait(timeout=15)
        assert _wait_dead(pids) == []
        assert _reg_files(reg) == []
    finally:
        if wrapper.poll() is None:
            wrapper.kill()


def test_registry_remains_after_wrapper_sigkill(stand_in, tmp_path):
    parent, pidfile = stand_in
    reg = tmp_path / "reg"
    wrapper = subprocess.Popen(_cmd(parent, pidfile, seconds="20"), env=_env(reg),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pids = _read_pids(pidfile)
    _wait_reg(reg)
    wrapper.kill()
    wrapper.wait(timeout=10)
    assert len(_reg_files(reg)) == 1
    for pid in pids:
        assert _alive(pid)  # 群組存活，等待清理指令處理


def test_unwritable_registry_does_not_affect_command_or_exit_code(tmp_path):
    blocker = tmp_path / "file"
    blocker.write_text("x")
    reg = blocker / "sub"  # 父層是檔案，無法建立目錄
    res = subprocess.run([sys.executable, str(SCRIPT), "10", "--", sys.executable, "-c",
                          "print('ran');import sys;sys.exit(7)"],
                         capture_output=True, text=True, timeout=20, env=_env(reg))
    assert (res.returncode, res.stdout.strip()) == (7, "ran")
    assert res.stderr.startswith("run-with-timeout:") and len(res.stderr.strip().splitlines()) == 1
    assert "Traceback" not in res.stderr


def test_registry_filename_contains_wrapper_start_time(stand_in, tmp_path):
    import re
    parent, pidfile = stand_in
    reg = tmp_path / "reg"
    wrapper = subprocess.Popen(_cmd(parent, pidfile, seconds="20"), env=_env(reg),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        _read_pids(pidfile)
        path = _wait_reg(reg)
        start = _load_module().process_start(wrapper.pid)
        assert path.name == "wrapper-%d-%s.json" % (wrapper.pid, re.sub(r"[^0-9A-Za-z]+", "-", start))
    finally:
        wrapper.kill()
        wrapper.wait()


def test_process_start_ignores_timezone_env(monkeypatch):
    mod = _load_module()
    monkeypatch.setenv("TZ", "Asia/Tokyo")
    tokyo = mod.process_start(os.getpid())
    monkeypatch.setenv("TZ", "America/Los_Angeles")
    assert tokyo is not None and mod.process_start(os.getpid()) == tokyo


@pytest.mark.parametrize("failing", ["replace", "dump"])
def test_interrupted_registry_write_leaves_no_temp_file(failing, tmp_path, monkeypatch, capsys):
    mod = _load_module()
    reg = tmp_path / "reg"
    monkeypatch.setenv("CLAUDE_PROC_REGISTRY_DIR", str(reg))
    if failing == "replace":
        monkeypatch.setattr(mod.os, "replace", lambda a, b: (_ for _ in ()).throw(OSError("中斷")))
    else:
        monkeypatch.setattr(mod.json, "dump", lambda *a, **k: (_ for _ in ()).throw(OSError("中斷")))
    assert mod.register_group(os.getpid(), ["x"]) is None
    assert list(reg.iterdir()) == []
    assert capsys.readouterr().err.startswith("run-with-timeout:")


# ---- 訊號處理器安裝時機、內部例外清理、清理期間再收訊號（0.5.0-W1-187.9）----

# 在子程序啟動回傳後立即制造指定事件，模擬「啟動之後、處理器生效之前」的空窗
HARNESS_SRC = """
import importlib.util, os, signal, subprocess, sys
spec = importlib.util.spec_from_file_location("rwt", sys.argv[1])
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
mode, pidfile = sys.argv[2], sys.argv[3]
real_popen, fired = subprocess.Popen, []
def popen(*a, **k):
    proc = real_popen(*a, **k)
    if not fired:
        fired.append(1)
        open(pidfile, "w").write("%d" % proc.pid)
        if mode == "signal":
            os.kill(os.getpid(), signal.SIGTERM)
    return proc
subprocess.Popen = popen
if mode == "raise":
    def boom(*a, **k): raise RuntimeError("內部例外")
    mod.register_group = boom
sys.exit(mod.run(30, [sys.executable, "-c", "import time; time.sleep(%d)" % LIFE]))
""".replace("LIFE", str(STAND_IN_LIFETIME))


def _run_harness(tmp_path, mode):
    harness = tmp_path / "harness.py"
    harness.write_text(HARNESS_SRC)
    pidfile = tmp_path / "hpid"
    res = subprocess.run([sys.executable, str(harness), str(SCRIPT), mode, str(pidfile)],
                         capture_output=True, text=True, timeout=25)
    child = int(pidfile.read_text())
    try:
        assert _wait_dead([child]) == [], "子程序群組未被終止"
    finally:
        try:
            os.killpg(child, signal.SIGKILL)  # 測試失敗時的收尾
        except (ProcessLookupError, PermissionError):
            pass
    return res


def test_signal_between_spawn_and_handler_still_kills_group(tmp_path):
    res = _run_harness(tmp_path, "signal")
    assert res.returncode == 128 + signal.SIGTERM


def test_internal_exception_after_spawn_kills_group(tmp_path):
    res = _run_harness(tmp_path, "raise")
    assert res.returncode != 0 and "內部例外" in res.stderr


def test_term_during_timeout_cleanup_keeps_exit_124(tmp_path):
    """子程序收到逾時 TERM 時寫標記並忽略之，標記出現即確定清理中，再送 TERM。"""
    marker = tmp_path / "got-term"
    src = ("import signal,time;"
           "signal.signal(signal.SIGTERM, lambda *a: open(%r,'w').write('x'));"
           "time.sleep(%d)" % (str(marker), STAND_IN_LIFETIME))
    wrapper = subprocess.Popen([sys.executable, str(SCRIPT), "1", "--", sys.executable, "-c", src],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.monotonic() + 20
        while not marker.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert marker.exists()
        wrapper.send_signal(signal.SIGTERM)
        assert wrapper.wait(timeout=15) == 124
    finally:
        if wrapper.poll() is None:
            wrapper.kill()


def test_usage_message_prefixed_and_lists_exit_codes():
    res = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True, timeout=20)
    assert res.returncode == 2
    assert res.stderr.startswith("run-with-timeout:")
    assert "2" in res.stderr and "128" in res.stderr
