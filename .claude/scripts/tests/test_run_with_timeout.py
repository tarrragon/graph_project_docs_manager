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
