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


# ---- 認定表、終止結果、失敗可見性 ----

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
    ("python3 -mpytest", True),
    # 執行檔路徑含空白：ps 無法分辨詞界，保守不認定（漏認）
    (SPACE + "/python -m pytest tests", False),
    ("/Users/me/My Dir/flutter_tester --x", False),
    ("node /Users/me/My Dir/node_modules/.bin/jest", False),
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
    # 首詞為絕對路徑的普通程式，後接執行器路徑
    ("/usr/bin/vim /repo/.venv/bin/pytest", False),
    ("/usr/bin/less /repo/node_modules/.bin/jest", False),
    ("/usr/bin/git add /repo/tools/pytest", False),
    ("/usr/bin/grep /repo/pytest /tmp/file", False),
    ("/usr/bin/find /repo/node_modules/.bin/jest", False),
    ("/usr/bin/ssh host /usr/bin/python3 -m pytest", False),
    ("/usr/bin/sudo /usr/bin/python3 -m pytest", False),
    ("/bin/cat /x/pytest", False),
    # 直譯器後的腳本不是執行器，其後的路徑不看
    ("python3 /repo/run /data/pytest", False),
    ("python3 /repo/manage /srv/logs/jest", False),
    ("node /repo/server /var/data/vitest.ts", False),
    ("python /opt/app/serve /x/.venv/bin/pytest", False),
    # 目錄名以執行器名結尾且後接空白
    ("/Users/me/pytest runs/bin/python server.py", False),
    ("/Users/me/pytest runs/tool --flag", False),
    ("/Users/me/flutter_tester backup/run.sh", False),
    # 次詞為含斜線的直譯器路徑，但首詞是真實執行器：認定
    ("/repo/.venv/bin/pytest /repo/tests/python", True),
    ("pytest /repo/scripts/python3", True),
    ("jest /repo/src/node", True),
    # 帶值選項：遇到即不認定（兩個方向）
    ("python3 -W /repo/pytest other.py", False),
    ("node --require /repo/node_modules/.bin/jest server.js", False),
    ("python3 -W ignore -m pytest", False),
    ("python3 -X dev /repo/.venv/bin/pytest", False),
    ("node --require x.js /repo/node_modules/.bin/jest", False),
    ("node --import x.mjs /repo/node_modules/.bin/vitest", False),
    ("node --loader x.mjs /repo/node_modules/.bin/jest", False),
    ("node -r x.js /repo/node_modules/.bin/jest", False),
]


@pytest.mark.parametrize("command,expected", RUNNER_CASES)
def test_is_runner_table(command, expected, monkeypatch):
    mod = _load()
    # 除明列的半截路徑外，視所有絕對路徑檔案為存在
    missing = {"/Users/me/pytest", "/Users/me/flutter_tester"}
    monkeypatch.setattr(mod, "_is_regular_file", lambda path: path not in missing)
    assert mod.is_runner(command) is expected


def test_absolute_first_token_must_exist(tmp_path):
    mod = _load()
    real = tmp_path / "pytest"
    real.write_text("")
    assert mod.is_runner(f"{real} -x") is True
    assert mod.is_runner(f"{tmp_path}/gone/pytest -x") is False
    assert mod.is_runner(f"{tmp_path} /pytest") is False
    # 目錄不是一般檔案
    (tmp_path / "jest").mkdir()
    assert mod.is_runner(f"{tmp_path}/jest") is False


def _fake_world(mod, monkeypatch, root, *, alive=True, same=True):
    """不送任何真實訊號的世界：一個假程序，存活與身份由參數決定。"""
    fake = mod.Proc(999999, 1, "S", "flutter_tester")
    sent = []
    monkeypatch.setattr(mod, "list_processes", lambda: [fake])
    monkeypatch.setattr(mod, "process_cwd", lambda pid: str(root))
    monkeypatch.setattr(mod, "_send", lambda pid, sig: sent.append((pid, sig)))
    monkeypatch.setattr(mod, "_is_alive", alive if callable(alive) else (lambda pid: alive))
    monkeypatch.setattr(mod, "_same_identity", lambda p: same)
    monkeypatch.setattr(mod, "GRACE_SECONDS", 0.05)
    monkeypatch.setattr(mod, "POLL_INTERVAL", 0.001)
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
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    assert sent == []
    assert rc == 0


def test_identity_changed_between_term_and_kill_sends_no_kill(tmp_path, monkeypatch):
    mod = _load()
    fake, sent = _fake_world(mod, monkeypatch, tmp_path)
    answers = iter([True, False])  # TERM 前相符，KILL 前已不符
    monkeypatch.setattr(mod, "_same_identity", lambda p: next(answers))
    result = mod.terminate(fake, grace=0.05)
    assert sent == [(999999, signal.SIGTERM)]
    assert result == "changed_after_term"


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


# ---- KILL 後的存活判定、結果回報 ----

def _killable_world(mod, monkeypatch, tmp_path, polls_after_kill):
    """TERM 無效；KILL 送出後再被查詢 polls_after_kill 次仍存活，之後消失。"""
    state = {"left": polls_after_kill}
    sent = []

    def alive(pid):
        if signal.SIGKILL not in [s for _, s in sent]:
            return True
        state["left"] -= 1
        return state["left"] >= 0

    fake, sent_ref = _fake_world(mod, monkeypatch, tmp_path, alive=alive)
    sent.extend(sent_ref)
    monkeypatch.setattr(mod, "_send", lambda pid, sig: (sent.append((pid, sig)), sent_ref.append((pid, sig))))
    return fake, sent


def test_slow_exit_after_kill_is_reported_terminated(tmp_path, monkeypatch, capsys):
    mod = _load()
    monkeypatch.setattr(mod, "KILL_WAIT_SECONDS", 2.0, raising=True)
    _killable_world(mod, monkeypatch, tmp_path, polls_after_kill=5)
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "已終止 999999" in out and "未能終止" not in out


def test_alive_past_kill_deadline_is_failure(tmp_path, monkeypatch, capsys):
    mod = _load()
    monkeypatch.setattr(mod, "KILL_WAIT_SECONDS", 0.05, raising=True)
    _killable_world(mod, monkeypatch, tmp_path, polls_after_kill=10 ** 9)
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    out = capsys.readouterr().out
    assert rc == 1
    assert "未能終止 999999" in out and "已終止" not in out


def test_vanished_before_signal_reports_absent_not_terminated(tmp_path, monkeypatch, capsys):
    mod = _load()
    _, sent = _fake_world(mod, monkeypatch, tmp_path, alive=False, same=False)
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    out = capsys.readouterr().out
    assert rc == 0 and sent == []
    assert "已不存在 999999" in out and "已終止" not in out


def test_ps_failure_during_terminate_is_error_exit_2(tmp_path, monkeypatch, capsys):
    mod = _load()
    fake = mod.Proc(999999, 1, "S", "flutter_tester")
    sent = []
    monkeypatch.setattr(mod, "list_processes", lambda: [fake])
    monkeypatch.setattr(mod, "process_cwd", lambda pid: str(tmp_path))
    monkeypatch.setattr(mod, "_send", lambda pid, sig: sent.append((pid, sig)))
    real = subprocess.run

    def fake_run(cmd, *a, **kw):
        if cmd[0] == "ps":
            return subprocess.CompletedProcess(cmd, 1, "", "boom")
        return real(cmd, *a, **kw)

    monkeypatch.setattr(mod.subprocess, "run", fake_run)
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    cap = capsys.readouterr()
    assert rc == 2 and sent == []
    assert "boom" in cap.err and "已終止" not in cap.out


def test_identity_changed_after_term_is_failure_with_distinct_message(tmp_path, monkeypatch, capsys):
    mod = _load()
    _fake_world(mod, monkeypatch, tmp_path)
    answers = iter([True, False])
    monkeypatch.setattr(mod, "_same_identity", lambda p: next(answers))
    rc = mod.main(["--kill", "--root", str(tmp_path)])
    out = capsys.readouterr().out
    assert rc == 1
    assert "TERM 後身份已變" in out and "送訊號前身份已變" not in out


def test_identity_changed_before_signal_message_distinct(tmp_path, monkeypatch, capsys):
    mod = _load()
    _fake_world(mod, monkeypatch, tmp_path, same=False)
    mod.main(["--kill", "--root", str(tmp_path)])
    assert "送訊號前身份已變" in capsys.readouterr().out


# ---- 真實的 _same_identity（不經替換）----

def _command_of(pid):
    return subprocess.run(["ps", "-o", "command=", "-p", str(pid)],
                          capture_output=True, text=True).stdout.strip()


def test_real_same_identity_true_for_matching_orphan(env):
    mod = _load()
    pid = env.orphan()
    assert mod._same_identity(mod.Proc(pid, 1, "S", _command_of(pid))) is True


def test_real_same_identity_false_when_command_differs(env):
    mod = _load()
    pid = env.orphan()
    assert mod._same_identity(mod.Proc(pid, 1, "S", "some other command")) is False


def test_real_same_identity_false_when_parent_not_init(env):
    mod = _load()
    pid = env.child_of_test()
    assert mod._same_identity(mod.Proc(pid, 1, "S", _command_of(pid))) is False


def test_real_same_identity_false_for_missing_pid(env):
    mod = _load()
    pid = env.orphan()
    os.kill(pid, signal.SIGKILL)
    assert _wait_gone(pid)
    assert mod._same_identity(mod.Proc(pid, 1, "S", "flutter_tester")) is False


def test_help_lists_unsupported_forms():
    res = subprocess.run([sys.executable, str(SCRIPT), "--help"],
                         capture_output=True, text=True, timeout=30)
    for phrase in ("路徑含空白", "帶值選項", "工作程序"):
        assert phrase in res.stdout


def test_test_file_has_no_ticket_ids():
    import re
    assert not re.search(r"\d+\.\d+\.\d+-W\d+-\d+", Path(__file__).read_text())
