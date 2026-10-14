"""
confabulation-audit-hook 測試（0.5.0-W1-164.3）

唯讀 git 呼叫須帶 --no-optional-locks 且位於子命令之前，降低與並行 session 的取鎖面。
"""

import importlib.util
import logging
import subprocess
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

_HOOKS_DIR = Path(__file__).parent.parent
if str(_HOOKS_DIR) not in sys.path:
    sys.path.insert(0, str(_HOOKS_DIR))

_spec = importlib.util.spec_from_file_location(
    "confabulation_audit_hook", _HOOKS_DIR / "confabulation-audit-hook.py"
)
_hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hook)


def test_check_dirty_worktree_status_has_no_optional_locks_before_subcommand():
    fake = MagicMock(returncode=0, stdout="", stderr="")
    with patch.object(_hook.subprocess, "run", return_value=fake) as run:
        _hook.check_dirty_worktree("/tmp")
    argv = run.call_args.args[0]
    assert "--no-optional-locks" in argv
    assert argv.index("--no-optional-locks") < argv.index("status")


def test_run_command_timeout_logs_and_keeps_return_value(caplog):
    err = subprocess.TimeoutExpired(cmd="git", timeout=1)
    with patch.object(_hook.subprocess, "run", side_effect=err):
        with caplog.at_level(logging.WARNING, logger=_hook.HOOK_NAME):
            result = _hook.run_command(["git", "status"], timeout=1)
    assert result == (1, "")
    assert "run_command" in caplog.text and "timeout" in caplog.text and "git status" in caplog.text


def test_run_command_oserror_logs_distinguishable_reason(caplog):
    with patch.object(_hook.subprocess, "run", side_effect=FileNotFoundError("git")):
        with caplog.at_level(logging.WARNING, logger=_hook.HOOK_NAME):
            result = _hook.run_command(["git", "status"])
    assert result == (1, "")
    assert "FileNotFoundError" in caplog.text and "timeout" not in caplog.text


def test_run_command_success_writes_no_failure_log(caplog):
    fake = MagicMock(returncode=0, stdout="ok\n", stderr="")
    with patch.object(_hook.subprocess, "run", return_value=fake):
        with caplog.at_level(logging.WARNING, logger=_hook.HOOK_NAME):
            result = _hook.run_command(["git", "status"])
    assert result == (0, "ok")
    assert caplog.text == ""
