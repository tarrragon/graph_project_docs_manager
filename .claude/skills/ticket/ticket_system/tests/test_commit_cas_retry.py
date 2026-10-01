"""單一路徑隔離提交的 CAS 重試與檔案日誌（0.4.1-W1-026）。

競爭構造：包裝 git_ops._prevalidate_guard_env（update-ref 前一刻呼叫），
在其中由另一個 commit 推進 HEAD，使 update-ref 的 old_head 過期。
E1 對照：同 fixture 無競爭時不重試、不寫日誌。
"""
import re
import subprocess
from pathlib import Path

import pytest

from ticket_system.lib import git_ops, git_utils

_TID = "0.0.0-W0-001"
_LOG_DIR = Path(".claude") / "hook-logs" / "ticket-commit-retry"


def _git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=str(cwd), check=True, capture_output=True, text=True
    ).stdout


def _read_log(repo: Path) -> str:
    d = repo / _LOG_DIR
    return "".join(p.read_text() for p in sorted(d.glob("*.log"))) if d.exists() else ""


@pytest.fixture
def repo(tmp_path, monkeypatch):
    _git(tmp_path, "init", "-q", "-b", "main")
    _git(tmp_path, "config", "user.email", "t@example.com")
    _git(tmp_path, "config", "user.name", "t")
    md = tmp_path / f"{_TID}.md"
    md.write_text("v1\n")
    _git(tmp_path, "add", md.name)
    _git(tmp_path, "commit", "-q", "-m", "init")
    md.write_text("v2\n")
    monkeypatch.setattr(git_utils, "_COMMIT_RETRY_BACKOFF_SECONDS", (0.01,))
    monkeypatch.setattr(git_utils, "_COMMIT_RETRY_BUDGET_SECONDS", 1.0)
    real_sleep = git_ops.time.sleep
    monkeypatch.setattr(git_ops.time, "sleep", lambda s: real_sleep(min(s, 0.01)))
    return tmp_path


def _advance_head_times(monkeypatch, repo: Path, times: int) -> None:
    """update-ref 前一刻由他方 commit 推進 HEAD，共 ``times`` 次。"""
    original = git_ops._prevalidate_guard_env
    state = {"n": 0}

    def racing(repo_root, commit_sha, old_head):
        if state["n"] < times:
            state["n"] += 1
            other = repo / f"other-{state['n']}.txt"
            other.write_text("x\n")
            _git(repo, "add", other.name)
            _git(repo, "commit", "-q", "-m", f"competing {state['n']}")
        return original(repo_root, commit_sha, old_head)

    monkeypatch.setattr(git_ops, "_prevalidate_guard_env", racing)


def _run(repo: Path):
    return git_utils.auto_commit_ticket_md_with_retry(
        str(repo / f"{_TID}.md"), _TID, "Solution"
    )


def test_control_no_race_no_retry_no_log(repo):
    result = _run(repo)
    assert result["status"] == "committed"
    assert result["attempts"] == 1
    assert _read_log(repo) == ""


def test_head_advanced_retries_and_commit_content_correct(repo, monkeypatch):
    _advance_head_times(monkeypatch, repo, 1)
    result = _run(repo)
    assert result["status"] == "committed"
    assert result["attempts"] == 2
    assert _git(repo, "show", f"HEAD:{_TID}.md") == "v2\n"
    # 他方提交仍在歷史中，重試提交疊在其上
    assert _git(repo, "log", "--format=%s", "-3").splitlines()[1] == "competing 1"
    assert _git(repo, "show", "--name-only", "--format=", "HEAD").split() == [f"{_TID}.md"]


def test_retry_event_logged_with_fields(repo, monkeypatch):
    _advance_head_times(monkeypatch, repo, 1)
    _run(repo)
    log = _read_log(repo)
    assert re.search(r"retry .*ticket=" + re.escape(_TID), log)
    assert "reason=cas_rejected" in log
    assert re.search(r"waited_s=\d+(\.\d+)?", log)
    assert re.search(r"attempt=1\b", log)


def test_cas_rejection_does_not_sleep_inside_single_git_call(repo, monkeypatch):
    """CAS 拒絕以同一 old_head 內層重試必敗，不應在內層睡眠。"""
    sleeps = []
    monkeypatch.setattr(git_ops.time, "sleep", lambda s: sleeps.append(s))
    _advance_head_times(monkeypatch, repo, 1)
    _run(repo)
    assert 1 not in sleeps  # _RETRY_WAIT_SECONDS 的內層等待


def test_residual_ref_lock_exhausts_logs_and_reports(repo, capsys):
    lock = repo / ".git" / "refs" / "heads" / "main.lock"
    lock.write_text("residue\n")
    failed = git_utils.commit_ticket_md_reporting(
        "append-log", str(repo / f"{_TID}.md"), _TID, "Solution"
    )
    assert failed is True
    log = _read_log(repo)
    assert "final_failure" in log
    assert "main.lock" in log
    assert re.search(r"attempt=\d+", log)
    assert re.search(r"waited_s=\d+(\.\d+)?", log)


def test_control_no_lock_writes_no_failure_record(repo):
    failed = git_utils.commit_ticket_md_reporting(
        "append-log", str(repo / f"{_TID}.md"), _TID, "Solution"
    )
    assert failed is False
    assert "final_failure" not in _read_log(repo)


def test_exhausted_stderr_lists_path_and_remedy(repo, monkeypatch, capsys):
    _advance_head_times(monkeypatch, repo, 10_000)
    failed = git_utils.commit_ticket_md_reporting(
        "append-log", str(repo / f"{_TID}.md"), _TID, "Solution"
    )
    err = capsys.readouterr().err
    assert failed is True
    assert str(repo / f"{_TID}.md") in err
    assert f"git add {repo / (_TID + '.md')}" in err
    assert "git commit" in err
    assert "ticket track commit" in err
    assert "final_failure" in _read_log(repo)


def test_log_write_failure_goes_to_stderr_and_keeps_commit_result(repo, monkeypatch, capsys):
    # 日誌目錄位置被檔案佔住 -> makedirs 失敗
    blocker = repo / ".claude"
    blocker.write_text("not a dir\n")
    _advance_head_times(monkeypatch, repo, 1)
    result = _run(repo)
    assert result["status"] == "committed"
    assert _git(repo, "show", f"HEAD:{_TID}.md") == "v2\n"
    assert "日誌寫入失敗" in capsys.readouterr().err
