"""session-context-guard-hook：完成命令辨識（含 finish 別名）。

E2：斷言計數檔的實際計數值與 exit code，不以輸出字樣判定。
"""

import importlib.util
import io
import json
import sys
from pathlib import Path

import pytest

_HOOKS_DIR = Path(__file__).parent.parent
if str(_HOOKS_DIR) not in sys.path:
    sys.path.insert(0, str(_HOOKS_DIR))

_spec = importlib.util.spec_from_file_location(
    "session_context_guard_hook", _HOOKS_DIR / "session-context-guard-hook.py"
)
_hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hook)


@pytest.fixture
def counter(tmp_path, monkeypatch):
    f = tmp_path / "counter"
    monkeypatch.setattr(_hook, "get_counter_file", lambda *a, **kw: f)
    return f


def _run(monkeypatch, command, stdout="Ticket X 已完成"):
    payload = {
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "tool_response": {"stdout": stdout},
    }
    monkeypatch.setattr(sys, "stdin", io.StringIO(json.dumps(payload)))
    return _hook.main()


def _count(counter):
    return int(counter.read_text()) if counter.exists() else 0


@pytest.mark.parametrize("command", [
    "ticket track complete T-1",
    "ticket track finish T-1",
    "ticket track batch-complete T-1 T-2",
    "FOO=1 ticket track finish T-1",
    "cd /x && ticket track finish T-1",
])
def test_completion_commands_increment(monkeypatch, counter, command):
    assert _run(monkeypatch, command) == 0
    assert _count(counter) == 1


@pytest.mark.parametrize("command", [
    'ticket track append-log T-1 --section S "ticket track finish T-2"',
    "cat <<'EOF'\nticket track complete T-2\nEOF",
    'ticket track finish "unterminated',
])
def test_non_command_text_does_not_increment(monkeypatch, counter, command):
    assert _run(monkeypatch, command) == 0
    assert _count(counter) == 0


def test_failure_marker_absent_does_not_increment(monkeypatch, counter):
    assert _run(monkeypatch, "ticket track finish T-1", stdout="error") == 0
    assert _count(counter) == 0
