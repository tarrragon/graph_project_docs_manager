#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""工作提交歸屬 trailer 提交後提示 hook。

職責：
    git commit 成功後，檢查最新提交訊息的歸屬 trailer，缺漏時以
    additionalContext 提示（exit 0，不阻擋、不自動 amend）。

格式要求：
    1. 必須有 Co-Authored-By trailer
    2. 若訊息含 Claude-Session 行，須為 trailer 且與 Co-Authored-By 相鄰

豁免：含 `Session:` trailer 的票務 CLI 提交、合併提交（多親代）、revert。

判定一律以 `git interpret-trailers --parse` 的輸出為準，不自寫 trailer 解析。

失敗語意：任何內部例外 -> 記錄日誌並 stderr 輸出一行，exit 0（提示類 hook 不阻擋）。
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).parent.parent))

from lib import (  # noqa: E402
    setup_hook_logging,
    run_hook_safely,
    read_json_from_stdin,
    run_git,
    get_project_root,
)

EXIT_SUCCESS = 0
CO_AUTHOR_KEY = "co-authored-by"
SESSION_KEY = "claude-session"
TICKET_CLI_KEY = "session"
CLAUDE_SESSION_PREFIX = "claude-session:"
COMMIT_SUCCESS_MARKERS = ("files changed", "file changed", "create mode",
                          "insertions(+)", "deletions(-)", "insertion(+)", "deletion(-)")


def _is_git_commit_command(command: str) -> bool:
    if "git commit" not in command:
        return False
    return not any(x in command for x in ("git log", "git show", "git diff", "git status"))


def _is_commit_successful(stdout: str, stderr: str = "") -> bool:
    combined = stdout + stderr
    if "nothing to commit" in combined or "Aborting" in combined:
        return False
    return any(m in stdout for m in COMMIT_SUCCESS_MARKERS)


def parse_trailer_keys(commit_msg: str) -> List[str]:
    """回傳 git 辨識出的 trailer key 清單（小寫、依序）。"""
    result = subprocess.run(
        ["git", "interpret-trailers", "--parse"],
        input=commit_msg, capture_output=True, text=True, timeout=5,
    )
    if result.returncode != 0:
        raise RuntimeError(f"interpret-trailers rc={result.returncode}: {result.stderr}")
    keys = []
    for line in result.stdout.splitlines():
        if ":" in line and not line.startswith((" ", "\t")):
            keys.append(line.split(":", 1)[0].strip().lower())
    return keys


def evaluate_trailers(commit_msg: str, parent_count: int) -> Optional[str]:
    """回傳提示文字；合規或豁免回傳 None。"""
    first_line = commit_msg.split("\n", 1)[0]
    if parent_count > 1 or first_line.startswith(("Merge ", "Revert ")):
        return None
    keys = parse_trailer_keys(commit_msg)
    if TICKET_CLI_KEY in keys:
        return None
    problems = []
    if CO_AUTHOR_KEY not in keys:
        problems.append("缺少 Co-Authored-By trailer")
    has_session_line = any(
        ln.strip().lower().startswith(CLAUDE_SESSION_PREFIX) for ln in commit_msg.splitlines()
    )
    if has_session_line:
        if SESSION_KEY not in keys:
            problems.append("Claude-Session 行未被 git 辨識為 trailer（需位於訊息最末段、與上方無空行）")
        elif CO_AUTHOR_KEY in keys and abs(keys.index(SESSION_KEY) - keys.index(CO_AUTHOR_KEY)) != 1:
            problems.append("Claude-Session 與 Co-Authored-By 不相鄰")
    if not problems:
        return None
    return (
        "[提交歸屬 trailer 提示]\n"
        f"最新提交：{'；'.join(problems)}。\n"
        "應補的行（置於訊息最末段，兩行相鄰、中間無空行）：\n"
        "  Co-Authored-By: <harness 歸屬指示給的值>\n"
        "  Claude-Session: <session 網址>（僅當歸屬指示提供網址時）\n"
        "本提示不阻擋；共用 checkout 下不建議 amend，請於下一次提交遵守。"
    )


def check_commit(input_data: dict, logger) -> Optional[str]:
    command = (input_data.get("tool_input") or {}).get("command", "")
    if not _is_git_commit_command(command):
        return None
    resp = input_data.get("tool_response") or {}
    if not _is_commit_successful(resp.get("stdout", ""), resp.get("stderr", "")):
        return None
    project_dir = get_project_root()
    msg = run_git(["git", "--no-optional-locks", "log", "-1", "--format=%B", "HEAD"],
                  cwd=project_dir, timeout=5, logger=logger) or ""
    parents = run_git(["git", "--no-optional-locks", "log", "-1", "--format=%P", "HEAD"],
                      cwd=project_dir, timeout=5, logger=logger) or ""
    return evaluate_trailers(msg, len(parents.split()))


def main() -> int:
    logger = setup_hook_logging("commit-attribution-trailer-check-hook")
    input_data = read_json_from_stdin(logger)
    if input_data is None or input_data.get("tool_name", "") != "Bash":
        return EXIT_SUCCESS
    try:
        msg = check_commit(input_data, logger)
    except Exception as e:
        logger.error("歸屬 trailer 檢查失敗: %s", e, exc_info=True)
        sys.stderr.write(f"[commit-attribution-trailer-check-hook] 檢查失敗（不阻擋）: {e}\n")
        return EXIT_SUCCESS
    if msg:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PostToolUse", "additionalContext": msg}},
            ensure_ascii=False, indent=2))
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(run_hook_safely(main, "commit-attribution-trailer-check-hook"))
