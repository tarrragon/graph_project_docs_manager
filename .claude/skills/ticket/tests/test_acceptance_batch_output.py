"""check-acceptance --all 輸出需分開呈現「本次變更數」與「目前已勾選數／總數」。

回歸：部分已勾的票執行 --all，舊輸出「全部 (1/2)」把本次變更數放在分子，
讀者誤讀為只勾了 1 項。
"""

import argparse
import sys
from pathlib import Path
from unittest import mock

_SKILL_ROOT = Path(__file__).resolve().parents[1]
if str(_SKILL_ROOT) not in sys.path:
    sys.path.insert(0, str(_SKILL_ROOT))

from ticket_system.commands import track_acceptance  # noqa: E402


def _run_batch(acceptance, uncheck, capsys):
    args = argparse.Namespace(ticket_id="T-1")
    ticket = {"acceptance": acceptance}
    with mock.patch.object(track_acceptance, "resolve_ticket_path", return_value=Path("/x.md")), \
         mock.patch.object(track_acceptance, "save_ticket"), \
         mock.patch("ticket_system.lib.git_utils.commit_ticket_md_reporting", return_value=False):
        track_acceptance._execute_batch_check_acceptance(
            args, "0.0.1", ticket, acceptance, uncheck
        )
    return capsys.readouterr().out


def test_partial_checked_all_reports_changed_and_current_total(capsys):
    out = _run_batch(["[x] a", "[ ] b"], False, capsys)
    assert "本次變更 1 項" in out
    assert "目前 2/2" in out
    assert "(1/2)" not in out and "1/2 項" not in out


def test_none_checked_all_reports_same_numbers(capsys):
    out = _run_batch(["[ ] a", "[ ] b"], False, capsys)
    assert "本次變更 2 項" in out
    assert "目前 2/2" in out


def test_uncheck_all_reports_changed_and_remaining_checked(capsys):
    out = _run_batch(["[x] a", "[ ] b"], True, capsys)
    assert "本次變更 1 項" in out
    assert "目前已勾選 0/2" in out
