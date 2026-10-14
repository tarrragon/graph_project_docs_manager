#!/usr/bin/env python3
"""ticket_command_parse 單元測試。

驗證項目：
1. find_complete_invocations（任意位置掃描）：
   - 被辨識：前綴包裝、串接、shell -c 巢狀、絕對路徑的 ticket、未知包裝器
   - 不被辨識：echo、printf、command -v 位置的語句、引號內字面、非完成類動詞
   - 失敗語意：未閉合引號回傳 None（呼叫端自行 fail-closed）
2. 既有函式 complete_statement_args／is_complete_statement／has_complete_command 行為不變
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from lib.ticket_command_parse import (
    complete_statement_args,
    find_complete_invocations,
    has_complete_command,
    is_complete_statement,
)

TID = "0.5.0-W1-001"


def _verbs(command):
    found = find_complete_invocations(command)
    assert found is not None
    return [verb for verb, _ in found]


class TestRecognized:
    """正向對照：這些命令必須被辨識為完成類命令。"""

    def test_direct(self):
        assert _verbs(f"ticket track complete {TID}") == ["complete"]

    def test_finish_and_batch_complete(self):
        assert _verbs(f"ticket track finish {TID}") == ["finish"]
        assert _verbs(f"ticket track batch-complete {TID} {TID}") == ["batch-complete"]

    def test_args_after_verb(self):
        found = find_complete_invocations(f"ticket track complete {TID} --force")
        assert found == [("complete", [TID, "--force"])]

    def test_known_prefix_wrapper(self):
        assert _verbs(f"env FOO=1 nohup ticket track complete {TID}") == ["complete"]

    def test_unlisted_prefix_wrapper(self):
        # 前綴白名單之外的包裝器（現行位置判定漏判的集合）
        assert _verbs(f"timeout 30 ticket track complete {TID}") == ["complete"]
        assert _verbs(f"ionice -c3 caffeinate ticket track complete {TID}") == ["complete"]

    def test_chained_after_other_statement(self):
        assert _verbs(f"git status && ticket track complete {TID}") == ["complete"]
        assert _verbs(f"echo hi; ticket track complete {TID}") == ["complete"]
        assert _verbs(f"cat x | ticket track complete {TID}") == ["complete"]

    def test_control_flow_block(self):
        assert _verbs(f"for i in 1; do ticket track complete {TID}; done") == ["complete"]
        assert _verbs(f"if true; then ticket track complete {TID}; fi") == ["complete"]

    def test_shell_c_nested(self):
        assert _verbs(f"bash -c 'ticket track complete {TID}'") == ["complete"]
        assert _verbs(f"sh -c \"cd x && ticket track finish {TID}\"") == ["finish"]
        assert _verbs(f"bash -lc 'ticket track complete {TID}'") == ["complete"]

    def test_shell_c_nested_twice(self):
        inner = f"sh -c \"ticket track complete {TID}\""
        assert _verbs(f"bash -c '{inner}'") == ["complete"]

    def test_absolute_path_ticket(self):
        assert _verbs(f"/usr/local/bin/ticket track complete {TID}") == ["complete"]
        assert _verbs(f"~/.local/bin/ticket track complete {TID}") == ["complete"]

    def test_multiple_invocations(self):
        found = find_complete_invocations(
            f"ticket track complete {TID} && ticket track finish {TID}.1"
        )
        assert [v for v, _ in found] == ["complete", "finish"]


class TestNotRecognized:
    """反向對照：動詞字樣只是輸出文字、查詢或引號內字面時不辨識。"""

    def test_echo(self):
        assert _verbs(f"echo ticket track complete {TID}") == []

    def test_printf(self):
        assert _verbs(f"printf '%s' ticket track complete {TID}") == []
        assert _verbs(f"printf %s ticket track complete {TID}") == []

    def test_command_v(self):
        assert _verbs("command -v ticket track complete") == []

    def test_echo_does_not_hide_later_statement(self):
        assert _verbs(f"echo ticket track complete; ticket track complete {TID}") == ["complete"]

    def test_quoted_literal(self):
        assert _verbs(f"ticket track create --why 'ticket track complete {TID}'") == []

    def test_other_verbs(self):
        assert _verbs(f"ticket track claim {TID}") == []
        assert _verbs(f"ticket track query {TID}") == []

    def test_empty(self):
        assert find_complete_invocations("") == []

    def test_no_ticket(self):
        assert _verbs("git status && ls") == []


class TestFailureSemantics:
    def test_unclosed_quote_returns_none(self):
        assert find_complete_invocations("ticket track complete 'abc") is None

    def test_nested_unparseable_returns_none(self):
        assert find_complete_invocations("bash -c \"ticket track complete 'abc\"") is None


class TestExistingFunctionsUnchanged:
    """既有函式維持命令位置判定，另有 hook 引用，行為不得改變。"""

    def test_complete_statement_args(self):
        assert complete_statement_args(["ticket", "track", "complete", TID]) == [TID]
        assert complete_statement_args(["nohup", "ticket", "track", "finish", TID]) == [TID]
        assert complete_statement_args(["ticket", "track", "claim", TID]) is None

    def test_position_only_not_scan(self):
        # 位置判定不辨識 timeout 包裝；掃描函式才辨識（兩者刻意不同）
        assert is_complete_statement(["timeout", "30", "ticket", "track", "complete", TID]) is False
        assert is_complete_statement(["ticket", "track", "complete", TID]) is True

    def test_has_complete_command(self):
        assert has_complete_command(f"git x && ticket track complete {TID}") is True
        assert has_complete_command(f"bash -c 'ticket track complete {TID}'") is False
        assert has_complete_command("ticket track complete 'abc") is None
