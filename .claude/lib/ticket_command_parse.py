"""ticket CLI 完成類命令的共用判定（供 hook 以 token 位置辨識，非子字串比對）。

判定與 acceptance-gate-hook 的 `_statement_complete_verb` 同一規則：語句去掉
env/nohup/time 等前綴後，以 `ticket track <完成類動詞>` 開頭。引號內字面與
heredoc 內文由 parse_command_statements 收斂，不會被誤判為命令。

失敗語意由呼叫端決定：解析失敗時 `parse_command_statements` 回傳 None，
`has_complete_command` 同樣回傳 None 以保留該訊號。
"""

import os
from typing import List, Optional, Tuple

from .git_command_parse import (
    SCAN_OUTPUT_COMMANDS,
    SHELLS,
    UnparseableCommand,
    is_stdin_shell,
    nested_script,
    parse_command_statements,
    raise_if_pipes_into_shell,
    skip_prefix_wrapper_count,
    skip_wrappers,
    tokenize_command,
)

COMPLETE_VERBS = ("complete", "finish", "batch-complete")

# shell -c 巢狀字串的遞迴深度上限
_MAX_SCAN_NESTING = 5


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


def _scan_statement(statement: List[str], depth: int) -> Optional[List[Tuple[str, List[str]]]]:
    """單一語句的任意位置掃描；巢狀腳本無法解析時回傳 None。"""
    if skip_wrappers(statement) is None:
        return []  # `command -v` 為查詢，不是執行
    if "<<<" in statement and any(is_stdin_shell(statement, i) for i in range(len(statement))):
        return None  # here-string 餵 stdin shell：腳本執行期才產生，靜態不可解析
    found: List[Tuple[str, List[str]]] = []
    for i, tok in enumerate(statement):
        if os.path.basename(tok) in SCAN_OUTPUT_COMMANDS:
            break  # echo、printf 之後只是輸出文字
        if (
            os.path.basename(tok) == "ticket"
            and len(statement) >= i + 3
            and statement[i + 1] == "track"
            and statement[i + 2] in COMPLETE_VERBS
        ):
            found.append((statement[i + 2], statement[i + 3:]))
            break  # 其餘 token 是該命令的參數
        script = nested_script(statement, i)
        if script:
            nested = _scan_command(script, depth + 1)
            if nested is None:
                return None
            found.extend(nested)
            if os.path.basename(tok) not in SHELLS:
                break  # eval、env -S 等的腳本已含其後全部 token
    return found


def _scan_command(command: str, depth: int) -> Optional[List[Tuple[str, List[str]]]]:
    if depth > _MAX_SCAN_NESTING:
        return None
    statements = parse_command_statements(command)
    tokens = tokenize_command(command) if command else []
    if statements is None or tokens is None:
        return None
    try:
        raise_if_pipes_into_shell(tokens)  # 管線餵 stdin shell，同 git 解析器 fail-closed
    except UnparseableCommand:
        return None
    found: List[Tuple[str, List[str]]] = []
    for statement in statements:
        part = _scan_statement(statement, depth)
        if part is None:
            return None
        found.extend(part)
    return found


def find_complete_invocations(command: str) -> Optional[List[Tuple[str, List[str]]]]:
    """任意位置掃描完成類命令，回傳 (動詞, 動詞之後的 token) 清單。

    與 `has_complete_command` 的差別：不要求 `ticket track` 位於命令位置，語句
    中任何位置的 `ticket track <完成類動詞>`（ticket 可為絕對路徑）皆算，涵蓋
    前綴包裝白名單以外的包裝器；shell -c／eval 巢狀字串遞迴解析。例外：echo、
    printf 之後的 token 與 `command -v` 語句不是執行，不辨識。管線或 here-string
    餵給 stdin shell（`echo ... | bash`、`bash <<< ...`）腳本內容靜態不可解析，
    回傳 None。已知誤判：動詞
    字樣作為其他命令的參數（如 `grep ticket track complete f`），呼叫端需以
    狀態條件緩衝。

    Returns:
        - `None`：命令（或巢狀腳本）無法解析、或巢狀過深；呼叫端自行決定
          fail-open 或 fail-closed，不可與空清單混淆。
        - 清單：可能為空（可解析但無完成類命令）。
    """
    return _scan_command(command, 0)


def has_complete_command(command: str) -> Optional[bool]:
    """命令中是否含完成類命令。無法解析（未閉合引號）時回傳 None。"""
    statements = parse_command_statements(command)
    if statements is None:
        return None
    return any(is_complete_statement(t) for t in statements)
