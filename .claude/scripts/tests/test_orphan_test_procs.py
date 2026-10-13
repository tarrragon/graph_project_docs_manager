"""orphan-test-procs.py 測試。

只終止本測試自己啟動並記下 PID 的替身；一律以 --root 指向暫存目錄，
使真實的測試執行器永遠不在認定範圍內。
"""
import importlib.util
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "orphan-test-procs.py"
LIFE = 30  # 替身存活上限（秒），保證測試失敗也會自行結束

# 替身本體：寫出 PID 後睡眠；ignore_term=1 時忽略 TERM
STAND_IN_SRC = (
    "import os,signal,sys,time\n"
    "if sys.argv[2]=='1': signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
    "open(sys.argv[1],'w').write(str(os.getpid()))\n"
    "time.sleep(%d)\n" % LIFE
)
# 中介程序：啟動替身（指定 argv0 與 cwd）後立即結束，替身被 launchd 收養
LAUNCHER_SRC = (
    "import subprocess,sys\n"
    "argv0,cwd,pidfile,ign=sys.argv[1:5]\n"
    "subprocess.Popen([argv0,'-c',%r,pidfile,ign],executable=sys.executable,"
    "cwd=cwd,start_new_session=True)\n" % STAND_IN_SRC
)


def _load():
    spec = importlib.util.spec_from_file_location("otp", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _alive(pid):
    out = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)],
                         capture_output=True, text=True).stdout.strip()
    return bool(out) and not out.startswith("Z")


def _wait_pid(pidfile, within=10.0):
    deadline = time.monotonic() + within
    while time.monotonic() < deadline:
        if pidfile.exists() and pidfile.read_text().strip():
            return int(pidfile.read_text())
        time.sleep(0.05)
    raise AssertionError("替身未寫出 PID")


def _wait_gone(pid, within=10.0):
    deadline = time.monotonic() + within
    while time.monotonic() < deadline and _alive(pid):
        time.sleep(0.05)
    return not _alive(pid)


def _ppid(pid):
    return int(subprocess.run(["ps", "-o", "ppid=", "-p", str(pid)],
                              capture_output=True, text=True).stdout.strip())


class Env:
    def __init__(self, tmp_path):
        self.root = (tmp_path / "proj").resolve()
        self.root.mkdir()
        self.outside = (tmp_path / "outside").resolve()
        self.outside.mkdir()
        self.tmp = tmp_path
        self.pids = []
        self.n = 0
        self.holders = []

    def orphan(self, argv0="flutter_tester", cwd=None, ign="0"):
        """啟動並等到被 launchd 收養的替身，回傳 PID。"""
        self.n += 1
        pidfile = self.tmp / ("pid%d" % self.n)
        subprocess.run([sys.executable, "-c", LAUNCHER_SRC, argv0,
                        str(cwd or self.root), str(pidfile), ign], check=True, timeout=15)
        pid = _wait_pid(pidfile)
        self.pids.append(pid)
        deadline = time.monotonic() + 10
        while _ppid(pid) != 1 and time.monotonic() < deadline:
            time.sleep(0.05)
        return pid

    def child_of_test(self, cwd=None):
        """父程序為本測試程序（非 1）的替身。"""
        self.n += 1
        pidfile = self.tmp / ("pid%d" % self.n)
        holder = subprocess.Popen(["flutter_tester", "-c", STAND_IN_SRC, str(pidfile), "0"],
                                  executable=sys.executable, cwd=str(cwd or self.root))
        self.holders.append(holder)
        pid = _wait_pid(pidfile)
        self.pids.append(pid)
        return pid

    def run(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), "--root", str(self.root), *args],
                              capture_output=True, text=True, timeout=60)


@pytest.fixture
def env(tmp_path):
    e = Env(tmp_path)
    yield e
    for pid in e.pids:
        try:
            os.kill(pid, signal.SIGKILL)  # 以記下的 PID 清理
        except (ProcessLookupError, PermissionError):
            pass
    for h in e.holders:
        h.wait()


def test_default_lists_without_killing(env):
    pid = env.orphan()
    res = env.run()
    assert res.returncode == 0
    assert str(pid) in res.stdout
    assert _alive(pid)


def test_kill_terminates_matching_orphan_positive_control(env):
    pid = env.orphan()
    res = env.run("--kill")
    assert res.returncode == 0
    assert _wait_gone(pid)


def test_kill_escalates_to_sigkill_when_term_ignored(env):
    pid = env.orphan(ign="1")
    assert env.run("--kill").returncode == 0
    assert _wait_gone(pid)


def test_negative_parent_not_init_survives(env):
    pid = env.child_of_test()
    assert _ppid(pid) != 1
    env.run("--kill")
    assert _alive(pid)


def test_negative_cwd_outside_project_survives(env):
    pid = env.orphan(cwd=env.outside)
    env.run("--kill")
    assert _alive(pid)


def test_negative_command_not_in_list_survives(env):
    pid = env.orphan(argv0="not_a_runner")
    env.run("--kill")
    assert _alive(pid)


def test_deleted_cwd_orphan_is_skipped_and_reported(env):
    gone = env.root / "wt-gone"
    gone.mkdir()
    pid = env.orphan(cwd=gone)
    gone.rmdir()
    res = env.run("--kill")
    assert res.returncode == 0
    assert _alive(pid)
    assert "cwd" in res.stdout and str(pid) in res.stdout


def test_no_orphans_exit_0_and_idempotent(env):
    first, second = env.run("--kill"), env.run("--kill")
    assert (first.returncode, second.returncode) == (0, 0)
    assert first.stdout == second.stdout


def test_repeat_after_kill_is_stable(env):
    pid = env.orphan()
    env.run("--kill")
    assert _wait_gone(pid)
    a, b = env.run("--kill"), env.run("--kill")
    assert a.returncode == b.returncode == 0
    assert a.stdout == b.stdout


def test_send_signal_tolerates_missing_and_eperm():
    mod = _load()

    def raiser(exc):
        def fake(pid, sig):
            raise exc
        return fake

    real = os.kill
    try:
        for exc in (ProcessLookupError(), PermissionError()):
            os.kill = raiser(exc)
            mod._send(12345, signal.SIGTERM)  # 不得拋出
    finally:
        os.kill = real


def test_survivor_after_nonpositive_zombie_check():
    """殭屍（ps 狀態 Z）不算存活，kill 流程不會等它。"""
    mod = _load()
    proc = subprocess.Popen([sys.executable, "-c", "pass"])
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline and mod._is_alive(proc.pid):
            time.sleep(0.05)
        assert mod._is_alive(proc.pid) is False
    finally:
        proc.wait()


# ---- 0.5.0-W1-187.10：認定表、終止結果、失敗可見性 ----

SPACE = "/Users/me/My Projects/app/.venv/bin"
RUNNER_CASES = [
    # (命令列, 是否認定)
    ("/opt/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester --a", True),
    ("flutter_tester", True),
    ("/usr/bin/python3 -m pytest tests/ -q", True),
    ("python -m pytest", True),
    ("/opt/homebrew/bin/python3.12 /repo/.venv/bin/pytest -x", True),
    ("/repo/.venv/bin/python /repo/.venv/bin/py.test", True),
    ("node /repo/node_modules/.bin/jest --runInBand", True),
    ("node /repo/node_modules/jest/bin/jest.js", True),
    ("/usr/local/bin/node /repo/node_modules/vitest/vitest.mjs run", True),
    ("/usr/local/bin/node /repo/node_modules/.bin/vitest", True),
    (SPACE + "/python -m pytest tests", True),
    ("/Users/me/My Dir/flutter_tester --x", True),
    ("node /Users/me/My Dir/node_modules/.bin/jest", True),
    # 不該認定
    ("vim pytest.ini", False),
    ("grep pytest file.txt", False),
    ("/usr/bin/grep -r jest .", False),
    ("python other.py pytest", False),
    ("python3 -c import pytest", False),
    ("python -m http.server", False),
    ("node server.js --jest", False),
    ("tail -f /var/log/vitest.log", False),
    ("/usr/bin/python3", False),
    ("", False),
]


@pytest.mark.parametrize("command,expected", RUNNER_CASES)
def test_is_runner_table(command, expected):
    assert _load().is_runner(command) is expected


def _fake_world(mod, monkeypatch, root, *, alive=True, same=True):
    """不送任何真實訊號的世界：一個假程序，存活與身份由參數決定。"""
    fake = mod.Proc(999999, 1, "S", "flutter_tester")
    sent = []
    monkeypatch.setattr(mod, "list_processes", lambda: [fake])
    monkeypatch.setattr(mod, "process_cwd", lambda pid: str(root))
    monkeypatch.setattr(mod, "_send", lambda pid, sig: sent.append((pid, sig)))
    monkeypatch.setattr(mod, "_is_alive", lambda pid: alive)
    monkeypatch.setattr(mod, "_same_identity", lambda p: same, raising=False)
    monkeypatch.setattr(mod, "GRACE_SECONDS", 0.05)
    return fake, sent


def test_kill_reports_survivor_and_exits_nonzero(tmp_path, monkeypatch, capsys):
    mod = _load()
    _fake_world(mod, monkeypatch, tmp_path)
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    out = capsys.readouterr().out
    assert rc == 1
    assert "未能終止 999999" in out and "已終止" not in out


def test_kill_skips_signal_when_identity_changed(tmp_path, monkeypatch):
    mod = _load()
    _, sent = _fake_world(mod, monkeypatch, tmp_path, same=False)
    mod.main(["--kill", "--root", str(tmp_path)])
    assert sent == []


def test_identity_changed_between_term_and_kill_sends_no_kill(tmp_path, monkeypatch):
    mod = _load()
    fake, sent = _fake_world(mod, monkeypatch, tmp_path)
    answers = iter([True, False])  # TERM 前相符，KILL 前已不符
    monkeypatch.setattr(mod, "_same_identity", lambda p: next(answers), raising=False)
    mod.terminate(fake, grace=0.05)
    assert signal.SIGKILL not in [s for _, s in sent]


@pytest.mark.parametrize("failing", ["ps", "git"])
def test_external_command_failure_is_visible(tmp_path, monkeypatch, capsys, failing):
    mod = _load()
    real = subprocess.run

    def fake_run(cmd, *a, **kw):
        if cmd[0] == failing:
            return subprocess.CompletedProcess(cmd, 1, "", "boom")
        return real(cmd, *a, **kw)

    monkeypatch.setattr(mod.subprocess, "run", fake_run)
    rc = mod.main(["--root", str(tmp_path)] if failing == "ps" else [])
    cap = capsys.readouterr()
    assert rc == 2
    assert "boom" in cap.err
    assert "符合 0" not in cap.out


def test_root_given_does_not_expand_worktrees(tmp_path):
    mod = _load()
    repo = tmp_path / "repo"
    repo.mkdir()
    git = ["git", "-C", str(repo)]
    subprocess.run(git + ["init", "-q"], check=True)
    subprocess.run(git + ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q",
                          "--allow-empty", "-m", "i"], check=True)
    subprocess.run(git + ["worktree", "add", "-q", str(tmp_path / "wt")], check=True)
    assert mod.project_roots(str(repo)) == [os.path.realpath(repo)]


def test_root_flag_hidden_from_help():
    res = subprocess.run([sys.executable, str(SCRIPT), "--help"],
                         capture_output=True, text=True, timeout=30)
    assert "--kill" in res.stdout and "--root" not in res.stdout


def test_skip_reason_deleted_cwd_prints_path(env):
    gone = env.root / "wt-gone2"
    gone.mkdir()
    pid = env.orphan(cwd=gone)
    gone.rmdir()
    res = env.run()
    line = [l for l in res.stdout.splitlines() if str(pid) in l][0]
    assert "cwd 已刪除" in line and str(gone) in line


def test_list_mode_wording_consistent_and_states_nothing_killed(env):
    pid = env.orphan()
    res = env.run()
    assert f"符合 {pid}" in res.stdout and "孤兒" not in res.stdout
    assert "未終止任何程序" in res.stdout


def test_negative_control_asserts_exit_code_and_output(env):
    pid = env.orphan(cwd=env.outside)
    res = env.run("--kill")
    assert _alive(pid)
    assert res.returncode == 0
    assert str(pid) not in res.stdout and "已終止" not in res.stdout
    assert "符合 0 略過 0" in res.stdout
