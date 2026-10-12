#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""
Git Index Lock Cleanup Hook

Purpose: 在 git commit/add 前自動清理過期的 .git/index.lock
Source: IMP-046 — Hook/Agent 的 git 操作與主線程 commit 競爭 index.lock

Trigger: PreToolUse (Bash: git commit, git add)

邏輯:
1. 偵測 Bash 命令是否包含 git commit 或 git add
2. 以 rev-parse --git-path index.lock 解析鎖檔路徑（涵蓋 linked worktree）
   目標目錄取 payload 的 cwd（無則退回 get_project_root()）
   行為變更：非 0 位元組的舊鎖不再自動移除，須人工處理（可能含寫到一半的索引）
3. 存在且 0 位元組、超過 STALE_THRESHOLD_SECONDS 秒、無行程持有（lsof）三項皆成立才移除並輸出警告
4. 如果存在但很新，輸出警告但不移除（可能有正在進行的 git 操作）
"""

import logging
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

# 添加 lib 目錄到路徑
sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.hook_io import read_hook_input, write_hook_output, create_simple_output
from lib.git_utils import get_project_root
from lib import setup_hook_logging, run_hook_safely

# 超過此秒數的 index.lock 視為殘留，自動移除
STALE_THRESHOLD_SECONDS = 5

GIT_TIMEOUT_SECONDS = 5

HOOK_NAME = "git-index-lock-cleanup"


def is_git_write_command(tool_input: dict) -> bool:
    """判斷是否為 git 寫入操作命令。"""
    command = tool_input.get("command", "")
    return "git commit" in command or "git add" in command


def resolve_lock_path(project_root: str, logger: logging.Logger) -> str:
    """以 rev-parse --git-path index.lock 解析實際鎖檔路徑（涵蓋 linked worktree）。

    linked worktree 的 .git 是檔案，鎖檔位於 .git/worktrees/<name>/index.lock。
    解析逾時或失敗時退回 <root>/.git/index.lock 並留記錄（於 worktree 內即為無法解析）。
    """
    reason = ""
    try:
        r = subprocess.run(
            ["git", "-C", project_root, "rev-parse", "--git-path", "index.lock"],
            capture_output=True, text=True, timeout=GIT_TIMEOUT_SECONDS,
        )
        out = r.stdout.strip()
        if r.returncode == 0 and out:
            return out if os.path.isabs(out) else os.path.join(project_root, out)
        reason = f"rc={r.returncode} stderr={r.stderr.strip()[:200]}"
    except (OSError, subprocess.SubprocessError) as e:
        reason = f"{type(e).__name__}: {e}"
    fallback = os.path.join(project_root, ".git", "index.lock")
    msg = (
        f"[WARNING] 無法解析 index.lock 路徑（{reason}），"
        f"退回預設 {fallback}；若位於 linked worktree，該路徑可能不是實際鎖檔"
    )
    logger.warning(msg)
    sys.stderr.write(msg + "\n")
    return fallback


def is_held_by_process(lock_path: str, logger: logging.Logger) -> bool:
    """lsof 判斷是否有行程持有鎖檔。無法判定視為持有（fail-safe，不刪）。"""
    try:
        r = subprocess.run(
            ["lsof", "-t", "--", lock_path],
            capture_output=True, text=True, timeout=GIT_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.SubprocessError) as e:
        logger.info("lsof 無法執行，視為有行程持有: %s", e)
        return True
    if r.stdout.strip():
        return True
    # 未持有須同時：rc=1、stdout 空、stderr 空；其餘（含 rc=1 而 stderr 有內容）視為無法判定
    if r.returncode == 1 and not r.stderr.strip():
        return False
    logger.info("lsof 結果無法判定（rc=%s stderr=%s），視為持有", r.returncode, r.stderr.strip()[:200])
    return True


def check_and_cleanup_index_lock(logger: logging.Logger, cwd: Optional[str] = None) -> Optional[str]:
    """檢查並清理過期的 index.lock（0 位元組 + 鎖齡超閾值 + 無行程持有）。

    目標目錄優先取 PreToolUse payload 的 cwd（env CLAUDE_PROJECT_DIR 可能指向主 repo
    而命令實際在 worktree 執行）；payload 無 cwd 才退回 get_project_root() 並留記錄。

    行為變更：非 0 位元組的舊鎖不再自動移除，須人工處理（可能含寫到一半的索引）。

    Returns:
        警告訊息（如果有清理動作或 lock 存在），否則 None
    """
    if cwd:
        project_root = cwd
    else:
        project_root = get_project_root()
        logger.info("payload 無 cwd，退回 get_project_root(): %s", project_root)
    if not project_root:
        return None

    lock_path = resolve_lock_path(project_root, logger)

    if not os.path.exists(lock_path):
        return None

    try:
        st = os.stat(lock_path)
        lock_age = time.time() - st.st_mtime
        lock_size = st.st_size
        first_id = (st.st_ino, st.st_mtime_ns, st.st_size)
    except OSError as e:
        logger.warning("無法讀取 index.lock 資訊: %s", e)
        return None

    if lock_age > STALE_THRESHOLD_SECONDS:
        # 刪除須同時滿足：0 位元組、鎖齡超閾值（此分支）、無行程持有
        if lock_size != 0:
            msg = (
                f"[WARNING] {lock_path} 非 0 位元組（{lock_size} bytes），"
                f"不自動移除；請確認無 git 操作後手動處理"
            )
            logger.warning(msg)
            sys.stderr.write(msg + "\n")
            return msg
        if is_held_by_process(lock_path, logger):
            msg = f"[WARNING] {lock_path} 有行程持有（或無法判定），不自動移除"
            logger.warning(msg)
            sys.stderr.write(msg + "\n")
            return msg
        # 複核：lsof 期間鎖可能已被換成新鎖，身分不同即不刪
        try:
            st2 = os.stat(lock_path)
            second_id = (st2.st_ino, st2.st_mtime_ns, st2.st_size)
        except OSError as e:
            logger.info("刪除前複核時鎖檔已消失或不可讀: %s", e)
            return None
        if second_id != first_id:
            msg = f"[WARNING] {lock_path} 在判定期間被替換（inode/mtime/size 改變），不自動移除"
            logger.warning(msg)
            sys.stderr.write(msg + "\n")
            return msg
        try:
            os.remove(lock_path)
            msg = (
                f"[IMP-046] 自動移除過期的 {lock_path}"
                f"（0 位元組、已存在 {lock_age:.0f} 秒、閾值 {STALE_THRESHOLD_SECONDS} 秒、無行程持有）"
            )
            logger.info(msg)
            sys.stderr.write(msg + "\n")
            return msg
        except OSError as e:
            msg = f"[IMP-046] 無法移除 {lock_path}: {e}"
            logger.error(msg)
            return msg
    else:
        # lock 很新，可能有正在進行的 git 操作
        # PC-139: 外部 GUI app（Fork / GitKraken / SourceTree / VS Code Git）
        # 週期性 fork git status/diff 子進程也會短暫持有 index.lock，
        # 非自家 hook/Bash 串接所致；訊息提示 PM 同時檢查外部進程，避免誤判方向白等 lock 自清。
        msg = (
            f"[WARNING] {lock_path} 存在（{lock_age:.0f} 秒），"
            f"可能有其他 git 操作進行中，不自動移除。\n"
            f"來源排查：\n"
            f"  1. 自家 hook/Bash 串接 git 寫入（拆分為獨立呼叫，見 bash-tool-usage-rules.md 規則三）\n"
            f"  2. 外部 GUI app fork 子進程（Fork / GitKraken / SourceTree / VS Code Git）— PC-139\n"
            f"     偵測指令：ps aux | grep -iE \"(Fork|GitKraken|SourceTree)\\.app|VS.Code.*git\" | grep -v grep\n"
            f"  3. 確認無自家操作進行中後，可安全執行：rm {lock_path}\n"
            f"參見 .claude/error-patterns/process-compliance/PC-139-git-index-lock-source-misattribution-gui-app-fork.md"
        )
        logger.warning(msg)
        sys.stderr.write(msg + "\n")
        return msg


def main():
    logger = setup_hook_logging(HOOK_NAME)

    hook_input = read_hook_input()
    if not hook_input:
        write_hook_output(create_simple_output("approve"))
        return

    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    # 只處理 Bash 的 git 寫入命令
    if tool_name != "Bash" or not is_git_write_command(tool_input):
        write_hook_output(create_simple_output("approve"))
        return

    result_msg = check_and_cleanup_index_lock(logger, hook_input.get("cwd") or None)

    if result_msg:
        write_hook_output(create_simple_output("approve", result_msg))
    else:
        write_hook_output(create_simple_output("approve"))


if __name__ == "__main__":
    run_hook_safely(main, HOOK_NAME)
