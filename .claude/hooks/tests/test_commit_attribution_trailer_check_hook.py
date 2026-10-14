"""commit-attribution-trailer-check-hook 單元測試（E2 正向對照 + 豁免對照）。"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

HOOK_PATH = Path(__file__).resolve().parent.parent / "commit-attribution-trailer-check-hook.py"


@pytest.fixture(scope="module")
def hook():
    spec = importlib.util.spec_from_file_location("attribution_hook", HOOK_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CO = "Co-Authored-By: Claude <noreply@anthropic.com>"
SES = "Claude-Session: https://claude.ai/code/session_abc"


def test_missing_co_author_prompts(hook):
    assert "Co-Authored-By" in hook.evaluate_trailers("feat: x\n\nbody\n", 1)


def test_only_session_line_prompts(hook):
    assert hook.evaluate_trailers(f"feat: x\n\nbody\n\n{SES}\n", 1) is not None


def test_co_author_only_ok(hook):
    assert hook.evaluate_trailers(f"feat: x\n\nbody\n\n{CO}\n", 1) is None


def test_adjacent_both_ok(hook):
    assert hook.evaluate_trailers(f"feat: x\n\nbody\n\n{CO}\n{SES}\n", 1) is None


def test_blank_line_between_prompts(hook):
    assert "Claude-Session" in hook.evaluate_trailers(f"feat: x\n\n{CO}\n\n{SES}\n", 1)


def test_session_not_last_paragraph_prompts(hook):
    assert hook.evaluate_trailers(f"feat: x\n\n{CO}\n{SES}\n\ntail text\n", 1) is not None


def test_ticket_cli_commit_exempt(hook):
    assert hook.evaluate_trailers("chore(1.0.0-W1-001): claim\n\nSession: 1234-uuid\n", 1) is None


def test_merge_exempt(hook):
    assert hook.evaluate_trailers("Merge branch 'x'\n", 2) is None
    assert hook.evaluate_trailers("feat: merged\n", 2) is None


def test_revert_exempt(hook):
    assert hook.evaluate_trailers('Revert "feat: x"\n\nThis reverts commit abc.\n', 1) is None
