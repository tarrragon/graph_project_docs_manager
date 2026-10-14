"""Bash PostToolUse tool_response 的成功判定（共用）。

平台事件依據（官方 hooks 文件）：PostToolUse 只在工具呼叫成功完成後觸發，Bash 命令
失敗（shell 層結束碼非 0）改走 PostToolUseFailure 事件，payload 無 tool_response。
因此在 PostToolUse 內收到的 Bash 命令，shell 層結束碼必為 0；本專案未註冊
PostToolUseFailure，未被遮蔽的失敗命令不會到達任何 PostToolUse hook。

真實 tool_response 只有 stdout、stderr、interrupted、isImage、noOutputExpected，
沒有 exit_code（文件未列）。以 get("exit_code", -1) 判定成功會恆走失敗分支。

判定順序：
1. exit_code 存在（相容舊形狀或未來平台補上）：沿用原判定，0 或 75 才算成功。
   75 為 ticket CLI 的 auto-commit 失敗專用碼；真實 PostToolUse 不會出現，僅供相容 payload。
2. exit_code 缺席：interrupted 為 True 即未成功。
3. stdout 須含呼叫端命令自身的成功回音。此步驟的用途是涵蓋複合命令中被管線或分號遮蔽的
   失敗（如 `ticket ... | tail` 整體結束碼為 0），不是推斷 shell 層結束碼。

已知誤判（推斷式判定的固有限度）：
- 命令的成功回音文字被改寫後，成功命令被判為未成功（漏報成功）。
- 被遮蔽的失敗命令 stdout 偶然含相同字樣，被判為成功（漏報失敗）。
- 未遮蔽的失敗命令根本不觸發 PostToolUse，由 PostToolUseFailure 事件負責，不在本模組範圍。
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
