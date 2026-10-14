"""pre-test-hook 封堵的端到端測試：subprocess 執行 hook、stdin 餵 payload、解析 stdout。

環境變數 PRE_TEST_HOOK_UNDER_TEST 可指向另一份 hook 腳本（用於對舊實作驗證鑑別力）；
該腳本所在目錄的上一層須有 lib/。
"""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

DEFAULT_HOOK = Path(__file__).parent.parent / "pre-test-hook.py"
HOOK = Path(os.environ.get("PRE_TEST_HOOK_UNDER_TEST", str(DEFAULT_HOOK)))
WRAP = "python3 .claude/scripts/run-with-timeout.py 600 -- "


def _decision(tool_name, tool_input):
    payload = {"tool_name": tool_name, "tool_input": tool_input}
    proc = subprocess.run(
        [sys.executable, str(HOOK)], input=json.dumps(payload),
        capture_output=True, text=True, timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    lines = [ln for ln in proc.stdout.splitlines() if ln.strip().startswith("{")]
    if not lines:
        return None, ""
    out = json.loads(lines[-1]).get("hookSpecificOutput", {})
    return out.get("permissionDecision"), out.get("permissionDecisionReason", "")


def test_e2e_bare_heavy_denied_with_copyable_wrapper():
    decision, reason = _decision("Bash", {"command": "fvm flutter test"})
    assert decision == "deny"
    assert "run-with-timeout.py 600 -- fvm flutter test" in reason


def test_e2e_wrapped_same_command_not_denied():
    decision, _ = _decision("Bash", {"command": WRAP + "fvm flutter test"})
    assert decision != "deny"


def test_e2e_mcp_without_paths_denied():
    decision, reason = _decision("mcp__dart__run_tests", {})
    assert decision == "deny"
    assert "run-with-timeout.py" in reason


def test_e2e_mcp_with_paths_not_denied():
    decision, _ = _decision(
        "mcp__dart__run_tests",
        {"roots": [{"root": "file:///x", "paths": ["test/a_test.dart"]}]})
    assert decision != "deny"


def test_e2e_single_file_pytest_not_denied():
    decision, _ = _decision("Bash", {"command": "uv run pytest -q tests/test_x.py"})
    assert decision != "deny"


@pytest.mark.parametrize("command", [
    "(cd .claude/hooks && uv run pytest -q tests/test_x.py)",
    "(cd /some/snapshot/.claude/hooks && python3 ../scripts/run-with-timeout.py 2400 -- uv run pytest -q -rfE)",
    "git status",
])
def test_e2e_other_forms_not_denied(command):
    decision, _ = _decision("Bash", {"command": command})
    assert decision != "deny"
