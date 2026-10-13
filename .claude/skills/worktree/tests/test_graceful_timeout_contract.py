"""逾時終止 helper 的契約測試。

hook 與 ticket_system 各有一份 _run_with_graceful_timeout（單檔腳本無法共用模組），
本檔以檔案路徑載入兩份，參數化跑同一組案例，固定兩者行為一致：
逾時先 SIGTERM（git 自行清鎖）、忽略 SIGTERM 者於寬限後被 SIGKILL、
孫程序握住輸出管線時耗時仍有上界、input 照常傳入。

持鎖情境使用暫存 repo 的真 git 加慢 clean filter；git 實驗只在 tmp_path。
耗時上界採寬鬆門檻（孫程序 sleep 30、斷言 15 秒內返回），以免機器負載造成誤判。
"""

import importlib.util
import subprocess
import sys
import time
from pathlib import Path

import pytest

_SKILLS = Path(__file__).resolve().parents[2]
_HOOK_FILE = _SKILLS / "worktree" / "hooks" / "worktree-auto-commit-hook.py"
_GIT_OPS_FILE = _SKILLS / "ticket" / "ticket_system" / "lib" / "git_ops.py"

_SLOW_SECONDS = 30
_BOUND_SECONDS = 15


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def helpers():
    hook = _load("contract_worktree_hook", _HOOK_FILE)
    git_ops = _load("contract_ticket_git_ops", _GIT_OPS_FILE)
    return {
        "hook": hook._run_with_graceful_timeout,
        "ticket": git_ops._run_with_graceful_timeout,
    }


@pytest.fixture(params=["hook", "ticket"])
def run(request, helpers):
    return helpers[request.param]


@pytest.fixture
def slow_filter_repo(tmp_path, monkeypatch):
    """含慢 clean filter 的暫存 repo；git add 期間持有 index.lock。"""
    monkeypatch.setenv("GIT_CEILING_DIRECTORIES", str(tmp_path.parent))
    repo = tmp_path / "repo"
    repo.mkdir()
    for cmd in (
        ["git", "init", "-q"],
        ["git", "config", "filter.slow.clean", f"sleep {_SLOW_SECONDS}; cat"],
    ):
        subprocess.run(cmd, cwd=repo, check=True)
    (repo / ".gitattributes").write_text("*.dat filter=slow\n")
    (repo / "payload.dat").write_text("x\n")
    return repo


def _lock(repo):
    return repo / ".git" / "index.lock"


def _wait_for_lock(repo):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if _lock(repo).exists():
            return
        time.sleep(0.05)


class TestRealGitLock:
    def test_sigterm_clears_index_lock_with_bounded_wait(self, run, slow_filter_repo):
        start = time.monotonic()
        with pytest.raises(subprocess.TimeoutExpired):
            run(["git", "add", "payload.dat"], 2, cwd=slow_filter_repo, text=True)
        assert time.monotonic() - start < _BOUND_SECONDS
        assert not _lock(slow_filter_repo).exists()

    def test_lock_is_held_before_timeout(self, run, slow_filter_repo):
        """對照：確認情境確實持鎖，鎖檔消失是 SIGTERM 的效果而非從未存在。"""
        proc = subprocess.Popen(
            ["git", "add", "payload.dat"],
            cwd=slow_filter_repo,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            _wait_for_lock(slow_filter_repo)
            assert _lock(slow_filter_repo).exists()
        finally:
            proc.kill()
            proc.wait()


_IGNORE_SIGTERM = (
    "import signal, time\n"
    "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
    "time.sleep(60)\n"
)


class TestEscalationAndBounds:
    def test_ignoring_sigterm_is_killed_after_grace(self, run):
        start = time.monotonic()
        with pytest.raises(subprocess.TimeoutExpired):
            run([sys.executable, "-c", _IGNORE_SIGTERM], 1, grace=1, text=True)
        assert time.monotonic() - start < _BOUND_SECONDS

    def test_grandchild_holding_pipe_does_not_extend_wait(self, run):
        start = time.monotonic()
        with pytest.raises(subprocess.TimeoutExpired):
            run(
                ["sh", "-c", f"sleep {_SLOW_SECONDS} & sleep {_SLOW_SECONDS * 2}"],
                1,
                grace=1,
                text=True,
            )
        assert time.monotonic() - start < _BOUND_SECONDS


class TestNormalPath:
    def test_input_is_passed_to_stdin(self, run):
        result = run(["cat"], 10, input="hello", text=True)
        assert (result.returncode, result.stdout) == (0, "hello")

    def test_completed_process_fields(self, run):
        result = run(["sh", "-c", "echo out; echo err >&2; exit 3"], 10, text=True)
        assert (result.returncode, result.stdout, result.stderr) == (3, "out\n", "err\n")

    def test_timeout_none_waits_for_completion(self, run):
        result = run(["echo", "ok"], None, text=True)
        assert result.stdout == "ok\n"
