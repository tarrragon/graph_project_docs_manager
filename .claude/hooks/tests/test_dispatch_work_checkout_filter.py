"""並行期判定依派發登記條目的工作位置過濾（work_checkout）。

以真實 git 建主 repo 與 linked worktree，不 mock git。
"""
import json
import subprocess
from pathlib import Path

import pytest

from lib import dispatch_tracker, hook_base
from lib.dispatch_tracker import filter_dispatches_for_checkout
from lib.hook_base import has_parallel_dispatch


def _git(cwd, *args):
    subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True)


@pytest.fixture
def repos(tmp_path, monkeypatch):
    main = (tmp_path / "main").resolve()
    main.mkdir()
    _git(main, "init", "-q")
    _git(main, "config", "user.email", "t@example.com")
    _git(main, "config", "user.name", "t")
    (main / "CLAUDE.md").write_text("x", encoding="utf-8")
    _git(main, "add", "CLAUDE.md")
    _git(main, "commit", "-q", "-m", "init")
    wt = (tmp_path / "wt").resolve()
    _git(main, "worktree", "add", "-q", "-b", "feat", str(wt))
    monkeypatch.delenv("HOOK_TEST_ISOLATION", raising=False)
    monkeypatch.delenv("CLAUDE_PROJECT_DIR", raising=False)
    hook_base.clear_project_root_cache()
    dispatch_tracker.reset_cache()
    yield main, wt
    hook_base.clear_project_root_cache()
    dispatch_tracker.reset_cache()


def _write(main, entries):
    p = main / ".claude" / "dispatch-active.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"dispatches": entries}), encoding="utf-8")
    dispatch_tracker.reset_cache()


def _entry(loc=None):
    e = {
        "agent_description": "d",
        "tool_use_id": "t",
        "agent_id": "a",
        "ticket_id": "",
        "files": [],
        "branch_name": "",
        "dispatched_at": "2099-01-01T00:00:00+00:00",
    }
    if loc is not None:
        e["work_checkout"] = str(loc)
    return e


def test_main_ignores_entry_working_in_other_worktree(repos, monkeypatch):
    main, wt = repos
    _write(main, [_entry(wt)])
    monkeypatch.chdir(main)
    assert has_parallel_dispatch() is False


def test_main_counts_entry_working_in_main(repos, monkeypatch):
    main, wt = repos
    _write(main, [_entry(main)])
    monkeypatch.chdir(main)
    assert has_parallel_dispatch() is True


def test_worktree_ignores_entry_working_in_main(repos, monkeypatch):
    main, wt = repos
    _write(main, [_entry(main)])
    monkeypatch.chdir(wt)
    assert has_parallel_dispatch() is False


def test_worktree_counts_entry_working_in_itself(repos, monkeypatch):
    main, wt = repos
    _write(main, [_entry(wt)])
    monkeypatch.chdir(wt)
    assert has_parallel_dispatch() is True


def test_legacy_entry_without_field_counts_everywhere(repos, monkeypatch):
    main, wt = repos
    _write(main, [_entry()])
    monkeypatch.chdir(main)
    assert has_parallel_dispatch() is True
    monkeypatch.chdir(wt)
    assert has_parallel_dispatch() is True


def test_identity_reads_all_entries_unfiltered(repos):
    """身分判定走 get_active_dispatches，不受過濾影響。"""
    main, wt = repos
    _write(main, [_entry(wt), _entry(main), _entry()])
    assert len(dispatch_tracker.get_active_dispatches(main)) == 3


def test_filter_none_checkout_and_empty_location_kept():
    ds = [_entry(), {"work_checkout": ""}]
    assert filter_dispatches_for_checkout(ds, Path("/x")) == ds
    assert filter_dispatches_for_checkout([_entry("/y")], None) == [_entry("/y")]


def test_record_dispatch_persists_work_checkout(repos):
    main, wt = repos
    dispatch_tracker.record_dispatch(main, "desc", work_checkout=str(wt))
    got = dispatch_tracker.get_active_dispatches(main)
    assert got[0]["work_checkout"] == str(wt)
