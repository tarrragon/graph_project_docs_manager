"""handoff-cleanup-hook 以真實 payload 形狀觸發的測試。

真實 Bash PostToolUse 的 tool_response 只有 stdout、stderr、interrupted、isImage、
noOutputExpected，沒有 exit_code。斷言具體副作用：handoff 檔是否被刪。
"""
import importlib.util
import sys
from io import StringIO
from pathlib import Path
from unittest.mock import patch

import pytest

CLAUDE_DIR = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(CLAUDE_DIR))

TID = "0.1.0-W41-002"


def _load():
    path = CLAUDE_DIR / "skills" / "ticket" / "hooks" / "handoff-cleanup-hook.py"
    spec = importlib.util.spec_from_file_location("handoff_cleanup_hook_real", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


hook = _load()


def real_response(stdout, interrupted=False):
    return {"stdout": stdout, "stderr": "", "interrupted": interrupted,
            "isImage": False, "noOutputExpected": False}


def run(tmp_path, tool_response, command=f"ticket track complete {TID}"):
    pending = tmp_path / ".claude" / "handoff" / "pending"
    pending.mkdir(parents=True)
    (tmp_path / ".claude" / "hook-logs" / "handoff-cleanup").mkdir(parents=True)
    f = pending / f"{TID}.json"
    f.write_text("{}", encoding="utf-8")
    data = {"tool_name": "Bash", "tool_input": {"command": command},
            "tool_response": tool_response}
    with patch.object(hook, "read_json_from_stdin", return_value=data), \
         patch.object(hook, "is_subagent_environment", return_value=False), \
         patch.object(hook, "get_project_root", return_value=tmp_path), \
         patch("sys.stdout", StringIO()):
        rc = hook.main()
    return rc, f


def test_real_payload_success_deletes_handoff(tmp_path):
    rc, f = run(tmp_path, real_response(f"[OK] 已完成 Ticket {TID}"))
    assert rc == 0
    assert not f.exists()


def test_real_payload_finish_deletes_handoff(tmp_path):
    rc, f = run(tmp_path, real_response(f"[OK] 已完成 Ticket {TID}"),
                command=f"ticket track finish {TID}")
    assert rc == 0 and not f.exists()


def test_real_payload_failure_keeps_handoff(tmp_path):
    rc, f = run(tmp_path, real_response("[Error] 無法完成"))
    assert rc == 0 and f.exists()


def test_interrupted_keeps_handoff(tmp_path):
    rc, f = run(tmp_path, real_response(f"[OK] 已完成 {TID}", interrupted=True))
    assert rc == 0 and f.exists()


@pytest.mark.parametrize("code,deleted", [(0, True), (75, True), (1, False)])
def test_legacy_exit_code_compat(tmp_path, code, deleted):
    resp = dict(real_response(f"[OK] 已完成 {TID}"), exit_code=code)
    rc, f = run(tmp_path, resp)
    assert rc == 0 and (not f.exists()) is deleted


@pytest.mark.parametrize("resp", ["[OK] 已完成", None, 42, ["x"]])
def test_non_dict_response_fail_open(tmp_path, resp):
    rc, f = run(tmp_path, resp)
    assert rc == 0 and f.exists()
