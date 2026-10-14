"""Bash PostToolUse tool_response 的成功判定（共用）。

平台真實 payload 的 tool_response 只有 stdout、stderr、interrupted、isImage、
noOutputExpected 五個鍵，沒有 exit_code。以 get("exit_code", -1)
判定成功會恆走失敗分支。本模組在 exit_code 缺席時改以 interrupted 與成功標記判定；
exit_code 存在（相容舊形狀或未來平台補上）時沿用原判定。
"""

from typing import Any, Iterable

# ticket CLI 寫入命令「動作已完成、僅 auto-commit 失敗」的專用退出碼（sysexits EX_TEMPFAIL）
EXIT_AUTO_COMMIT_FAILED = 75
_OK_EXIT_CODES = (0, EXIT_AUTO_COMMIT_FAILED)


def is_bash_success(
    tool_response: Any,
    success_markers: Iterable[str],
    ignore_case: bool = False,
) -> bool:
    """判定 Bash 命令是否成功。

    Args:
        tool_response: PostToolUse 的 tool_response；非 dict 一律視為未成功
        success_markers: 呼叫端命令自身的成功回音；stdout 含任一即符合
        ignore_case: 標記比對是否忽略大小寫
    """
    if not isinstance(tool_response, dict):
        return False
    if "exit_code" in tool_response:
        if tool_response["exit_code"] not in _OK_EXIT_CODES:
            return False
    elif tool_response.get("interrupted") is True:
        return False
    stdout = tool_response.get("stdout", "")
    if not isinstance(stdout, str):
        return False
    if ignore_case:
        stdout = stdout.lower()
        return any(m.lower() in stdout for m in success_markers)
    return any(m in stdout for m in success_markers)
