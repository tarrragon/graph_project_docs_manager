"""ticket CLI 完成類命令的共用判定（供 hook 以 token 位置辨識，非子字串比對）。

判定與 acceptance-gate-hook 的 `_statement_complete_verb` 同一規則：語句去掉
env/nohup/time 等前綴後，以 `ticket track <完成類動詞>` 開頭。引號內字面與
heredoc 內文由 parse_command_statements 收斂，不會被誤判為命令。

失敗語意由呼叫端決定：解析失敗時 `parse_command_statements` 回傳 None，
`has_complete_command` 同樣回傳 None 以保留該訊號。
"""

from typing import List, Optional

from .git_command_parse import parse_command_statements, skip_prefix_wrapper_count

COMPLETE_VERBS = ("complete", "finish", "batch-complete")


def complete_statement_args(tokens: List[str]) -> Optional[List[str]]:
    """若語句為完成類命令，回傳動詞之後的 token；否則回傳 None。"""
    i = skip_prefix_wrapper_count(tokens)
    if (
        len(tokens) >= i + 3
        and tokens[i] == "ticket"
        and tokens[i + 1] == "track"
        and tokens[i + 2] in COMPLETE_VERBS
    ):
        return tokens[i + 3:]
    return None


def is_complete_statement(tokens: List[str]) -> bool:
    """語句（去前綴後）是否以 ticket track <完成類動詞> 開頭。"""
    return complete_statement_args(tokens) is not None


def has_complete_command(command: str) -> Optional[bool]:
    """命令中是否含完成類命令。無法解析（未閉合引號）時回傳 None。"""
    statements = parse_command_statements(command)
    if statements is None:
        return None
    return any(is_complete_statement(t) for t in statements)
