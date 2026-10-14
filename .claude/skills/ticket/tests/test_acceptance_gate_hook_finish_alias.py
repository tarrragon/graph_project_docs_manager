"""acceptance-gate-hook 辨識 finish 別名與 heredoc 誤判（0.5.0-W1-270.2）。"""
import importlib.util
import subprocess
from pathlib import Path
from unittest.mock import patch

import pytest

TICKET_ID = "0.0.0-W1-900"
BODY = """---
id: 0.0.0-W1-900
title: t
type: IMP
status: in_progress
version: 0.0.0
priority: P2
acceptance:
- '{mark} a'
- '{mark} b'
---

## Solution

x
"""


def _load():
    path = Path(__file__).resolve().parents[1] / "hooks" / "acceptance-gate-hook.py"
    spec = importlib.util.spec_from_file_location("acceptance_gate_hook_fa", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _git(cwd, *args):
    subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True)


def _write_ticket(root: Path, mark: str):
    d = root / "docs" / "work-logs" / "v0.0.0" / "tickets"
    d.mkdir(parents=True, exist_ok=True)
    (d / (TICKET_ID + ".md")).write_text(BODY.format(mark=mark), encoding="utf-8")


@pytest.mark.parametrize("cmd", [
    "ticket track complete X",
    "ticket track finish X",
    "ticket track batch-complete X",
    "env A=1 nohup ticket track finish X",
    "git add a && ticket track finish X",
])
def test_completion_commands_recognized(cmd):
    assert _load().is_complete_command(cmd) is True


@pytest.mark.parametrize("cmd", [
    'ticket track create --why "run ticket track finish later"',
    "ticket track append-log X --section S \"$(cat <<'EOF'\nticket track finish X\nEOF\n)\"",
    "ticket track append-log X --section S \"$(cat <<'EOF'\nticket track complete X\nEOF\n)\"",
    "echo hi",
])
def test_non_completion_commands_ignored(cmd):
    assert _load().is_complete_command(cmd) is False


def test_unparsable_command_fail_closed():
    # 未閉合引號：解析失敗時退回字面比對，完成類命令仍視為完成命令
    assert _load().is_complete_command("ticket track finish X 'oops") is True


def test_chained_write_detection_with_finish():
    m = _load()
    assert m.detect_chained_pre_complete_write(
        "ticket track set-acceptance X --check 1 && ticket track finish X") is True
    assert m.detect_chained_pre_complete_write("ticket track finish X") is False


def _run_main(module, command):
    payload = {"tool_name": "Bash", "tool_input": {"command": command}}
    with patch.object(module, "read_json_from_stdin", return_value=payload), \
         patch.object(module, "save_check_log"):
        return module.main()


def test_finish_blocked_when_acceptance_unchecked_E2(tmp_path, monkeypatch, capsys):
    """正向對照：IMP 驗收未勾選時 finish 被擋（修正前 Fast-path skip 放行）。"""
    module = _load()
    from lib import hook_base
    root = (tmp_path / "repo").resolve()
    root.mkdir()
    _git(root, "init", "-q")
    (root / "CLAUDE.md").write_text("x", encoding="utf-8")
    _write_ticket(root, "[ ]")
    monkeypatch.delenv("HOOK_TEST_ISOLATION", raising=False)
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(root))
    monkeypatch.chdir(root)
    hook_base.clear_project_root_cache()
    try:
        _run_main(module, "ticket track finish " + TICKET_ID)
    finally:
        hook_base.clear_project_root_cache()
    out = capsys.readouterr().out
    assert "deny" in out or "block" in out.lower(), out


def test_finish_in_linked_worktree_reads_main_ticket(tmp_path, monkeypatch):
    """組合情境：主倉庫未勾選，worktree 內 finish 進完整驗收並以主倉庫票面判定。"""
    module = _load()
    from lib import hook_base
    main = (tmp_path / "main").resolve()
    main.mkdir()
    _git(main, "init", "-q")
    _git(main, "config", "user.email", "t@example.com")
    _git(main, "config", "user.name", "t")
    (main / "CLAUDE.md").write_text("x", encoding="utf-8")
    _write_ticket(main, "[ ]")
    _git(main, "add", "-A")
    _git(main, "commit", "-q", "-m", "init")
    wt = (tmp_path / "wt").resolve()
    _git(main, "worktree", "add", "-q", "-b", "feat", str(wt))
    monkeypatch.delenv("HOOK_TEST_ISOLATION", raising=False)
    monkeypatch.delenv("CLAUDE_PROJECT_DIR", raising=False)
    monkeypatch.chdir(wt)
    hook_base.clear_project_root_cache()
    seen = {}

    def spy(ticket_id, project_dir, logger, command=""):
        seen["dir"] = project_dir
        return module.AcceptanceCheckResult(False, True, None, False, [])

    try:
        with patch.object(module, "check_acceptance_status", side_effect=spy):
            _run_main(module, "ticket track finish " + TICKET_ID)
    finally:
        hook_base.clear_project_root_cache()
    assert seen.get("dir") == main
