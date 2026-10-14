#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""
Git Index Lock Cleanup Hook

Purpose: 每次 Bash 呼叫前自動清理過期的 index.lock
Source: IMP-046 — Hook/Agent 的 git 操作與主線程 commit 競爭 index.lock
        觸發不依子命令；目標含 cwd、git -C 路徑、ticket track commit --worktree

邏輯:
1. 目標集合 = payload cwd + 命令中 git -C 路徑 + ticket track commit --worktree 的值
   （命令不含 git/ticket 字樣時只查 cwd，不載入 git_command_parse）
2. 鎖路徑以檔案系統上溯 .git（目錄或 gitdir 檔）解析，失敗才退回 rev-parse
3. 刪除須同時：0 位元組、鎖齡超閾值、無行程持有、刪除前複核身分未變
4. 刪除前先寫線索行（IDXLOCK-EVIDENCE）到本專案主倉的 hook-logs，記錄失敗不阻止清理
5. 未達閾值的新鎖只寫日誌，不輸出 stderr
本 hook 不在任何其他 repo 建立目錄或寫入檔案（-C 指向他 repo 時只檢查與清理鎖）。
fail-open：自身異常不阻擋 Bash 呼叫。
"""

import json
import logging
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Optional

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

MAX_TARGETS = 8
MAX_ASCEND_LEVELS = 64
FOUND_BY_CMD_MAX_CHARS = 200
EVIDENCE_PREFIX = "IDXLOCK-EVIDENCE"
EVIDENCE_FILENAME = "evidence.log"

# git 全域選項中帶獨立值的（掃描 -C 時需跳過其值）
_GIT_OPTS_WITH_VALUE = frozenset({"-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"})
_SECRET_KEY_RE = re.compile(r"(TOKEN|SECRET|PASSWORD|KEY|AUTH)", re.IGNORECASE)
_ENV_ASSIGN_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)=(\S+)")
_BEARER_RE = re.compile(r"(Bearer|Basic)\s+\S+", re.IGNORECASE)


# ===== 目標集合 =====

def _resolve_path(path: str, cwd: str) -> str:
    expanded = os.path.expanduser(path)
    return os.path.normpath(expanded if os.path.isabs(expanded) else os.path.join(cwd, expanded))


def _dash_c_paths(statement: List[str]) -> List[str]:
    """回傳語句中 git 全域選項區段內所有 -C 的值。"""
    paths: List[str] = []
    for i, tok in enumerate(statement):
        if tok != "git":
            continue
        j = i + 1
        while j < len(statement) and statement[j].startswith("-"):
            if statement[j] == "-C" and j + 1 < len(statement):
                paths.append(statement[j + 1])
                j += 2
            elif statement[j] in _GIT_OPTS_WITH_VALUE:
                j += 2
            else:
                j += 1
        break
    return paths


def _worktree_values(statement: List[str]) -> List[str]:
    """ticket track commit 語句中 --worktree 的值（兩種寫法）。"""
    if "ticket" not in statement or "commit" not in statement:
        return []
    values: List[str] = []
    for i, tok in enumerate(statement):
        if tok == "--worktree" and i + 1 < len(statement):
            values.append(statement[i + 1])
        elif tok.startswith("--worktree="):
            values.append(tok.split("=", 1)[1])
    return values


def extract_target_dirs(command: str, cwd: str, logger: logging.Logger) -> List[str]:
    """目標集合：cwd + git -C 路徑 + ticket --worktree 值，有序去重，上限 MAX_TARGETS。"""
    targets = [cwd]
    if "git" in command or "ticket" in command:
        from lib.git_command_parse import parse_command_statements  # 延遲載入
        statements = parse_command_statements(command)
        if statements is None:
            logger.info("命令無法 tokenize，只查 cwd")
            statements = []
        for stmt in statements:
            for raw in _dash_c_paths(stmt) + _worktree_values(stmt):
                path = _resolve_path(raw, cwd)
                if os.path.isdir(path):
                    targets.append(path)
                else:
                    logger.debug("目標目錄不存在，略過: %s", path)
    return list(dict.fromkeys(targets))[:MAX_TARGETS]


# ===== 鎖路徑上溯 =====

def find_gitdir(start: str) -> Optional[str]:
    """由 start 往上找 .git；目錄即 gitdir，檔案則讀 'gitdir: <path>'。"""
    cur = os.path.abspath(start)
    for _ in range(MAX_ASCEND_LEVELS):
        dot_git = os.path.join(cur, ".git")
        if os.path.isdir(dot_git):
            return dot_git
        if os.path.isfile(dot_git):
            try:
                with open(dot_git, encoding="utf-8") as f:
                    first = f.readline().strip()
            except OSError:
                return None
            if not first.startswith("gitdir:"):
                return None
            target = first[len("gitdir:"):].strip()
            return target if os.path.isabs(target) else os.path.normpath(os.path.join(cur, target))
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent
    return None


def resolve_lock_path(project_root: str, logger: logging.Logger) -> str:
    """鎖檔路徑：先檔案系統上溯，失敗才以 rev-parse --git-path index.lock 解析並留記錄。

    rev-parse 也失敗時退回 <root>/.git/index.lock 並輸出 WARNING。
    """
    gitdir = find_gitdir(project_root)
    if gitdir:
        return os.path.join(gitdir, "index.lock")
    reason = ""
    try:
        r = subprocess.run(
            ["git", "-C", project_root, "rev-parse", "--git-path", "index.lock"],
            capture_output=True, text=True, timeout=GIT_TIMEOUT_SECONDS,
        )
        out = r.stdout.strip()
        if r.returncode == 0 and out:
            logger.info("fallback=rev-parse 上溯未找到 .git: %s", project_root)
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


# ===== 線索記錄 =====

def sanitize_command(command: str) -> str:
    """去換行、遮罩機密、截斷。"""
    flat = " ".join(command.split())
    flat = _ENV_ASSIGN_RE.sub(
        lambda m: f"{m.group(1)}=***" if _SECRET_KEY_RE.search(m.group(1)) else m.group(0), flat)
    flat = _BEARER_RE.sub(lambda m: f"{m.group(1)} ***", flat)
    return flat[:FOUND_BY_CMD_MAX_CHARS]


def _kv(key: str, value) -> str:
    text = str(value)
    if not text or any(c in text for c in ' \t=\"'):
        text = json.dumps(text, ensure_ascii=False)
    return f"{key}={text}"


def _iso(ts: float) -> str:
    return datetime.fromtimestamp(ts).astimezone().isoformat(timespec="seconds")


def read_reflog_last_ts(gitdir: str) -> Optional[int]:
    """讀 <gitdir>/logs/HEAD 末行 committer 時間戳；讀不到回 None。"""
    try:
        with open(os.path.join(gitdir, "logs", "HEAD"), "rb") as f:
            f.seek(0, os.SEEK_END)
            f.seek(max(0, f.tell() - 4096))
            lines = f.read().decode("utf-8", "replace").strip().splitlines()
        head = lines[-1].split("\t", 1)[0]
        return int(head.rsplit(">", 1)[1].split()[0])
    except (OSError, IndexError, ValueError):
        return None


def find_main_root(project_root: str) -> Optional[str]:
    """本專案主倉：由專案根的 gitdir（含 linked worktree 的 commondir）推得。"""
    gitdir = find_gitdir(project_root)
    if not gitdir:
        return None
    common = gitdir
    try:
        with open(os.path.join(gitdir, "commondir"), encoding="utf-8") as f:
            rel = f.read().strip()
        common = os.path.normpath(rel if os.path.isabs(rel) else os.path.join(gitdir, rel))
    except OSError:
        pass
    if os.path.basename(common) != ".git":
        return None
    return os.path.dirname(common)


def build_evidence_line(lock_path: str, st: os.stat_result, ctx: dict, location_note: str) -> str:
    gitdir = os.path.dirname(lock_path)
    try:
        index_mtime = _iso(os.stat(os.path.join(gitdir, "index")).st_mtime)
    except OSError:
        index_mtime = "none"
    reflog_ts = read_reflog_last_ts(gitdir)
    if reflog_ts is None:
        reflog_new, reflog_raw = "unknown", "unknown"
    else:
        reflog_new, reflog_raw = ("yes" if reflog_ts > st.st_mtime else "no"), reflog_ts
    try:
        load = f"{os.getloadavg()[0]:.2f}"
    except OSError:
        load = "unknown"
    fields = [
        ("ts", _iso(time.time())), ("lock_path", lock_path), ("size", st.st_size),
        ("lock_mtime", _iso(st.st_mtime)), ("lock_age_s", f"{time.time() - st.st_mtime:.0f}"),
        ("hook_cwd", ctx.get("cwd", "")),
        # found_by_cmd 是「發現鎖的那次呼叫」，不是造成鎖的命令
        ("found_by_cmd", sanitize_command(ctx.get("command", ""))),
        ("index_mtime", index_mtime), ("reflog_new", reflog_new), ("reflog_last_ts", reflog_raw),
        ("loadavg_1m", load), ("session_id", ctx.get("session_id") or "none"),
    ]
    if location_note:
        fields.append(("evidence_location", location_note))
    return " ".join([EVIDENCE_PREFIX] + [_kv(k, v) for k, v in fields])


def write_evidence(lock_path: str, st: os.stat_result, ctx: dict, logger: logging.Logger) -> None:
    """先記後刪的記錄步驟；任何失敗只寫 stderr 與日誌，不拋出。"""
    try:
        project_root = str(get_project_root())
        main_root = find_main_root(project_root)
        note = ""
        if main_root is None:
            main_root, note = project_root, "fallback reason=main-root-unresolved"
        line = build_evidence_line(lock_path, st, ctx, note)
        log_dir = os.path.join(main_root, ".claude", "hook-logs", HOOK_NAME)
        os.makedirs(log_dir, exist_ok=True)
        with open(os.path.join(log_dir, EVIDENCE_FILENAME), "a", encoding="utf-8") as f:
            f.write(line + "\n")
        logger.info(line)
    except Exception as e:  # 記錄失敗不得阻止清理
        msg = f"[WARNING] 線索記錄失敗（不影響清理）: {type(e).__name__}: {e}"
        logger.error(msg)
        sys.stderr.write(msg + "\n")


# ===== 單一鎖處理 =====

def _warn(msg: str, logger: logging.Logger) -> str:
    logger.warning(msg)
    sys.stderr.write(msg + "\n")
    return msg


def cleanup_lock(lock_path: str, ctx: dict, logger: logging.Logger) -> Optional[str]:
    """對單一鎖檔套用四項刪除條件；回傳需呈現的訊息（無則 None）。"""
    if not os.path.exists(lock_path):
        return None
    try:
        st = os.stat(lock_path)
    except OSError as e:
        logger.warning("無法讀取 index.lock 資訊: %s", e)
        return None
    lock_age = time.time() - st.st_mtime
    first_id = (st.st_ino, st.st_mtime_ns, st.st_size)

    if lock_age <= STALE_THRESHOLD_SECONDS:
        # 新鎖可能是進行中的 git 操作；PC-139: 外部 GUI app 也會短暫持鎖。只寫日誌不擾動 stderr
        logger.info(
            "%s 存在（%.0f 秒），可能有其他 git 操作進行中（含外部 GUI app 如 Fork/GitKraken/SourceTree/"
            "VS Code，見 PC-139-git-index-lock-source-misattribution-gui-app-fork），不自動移除；"
            "偵測：ps aux | grep -iE \"(Fork|GitKraken|SourceTree)\\.app|VS.Code.*git\" | grep -v grep",
            lock_path, lock_age)
        return None
    if st.st_size != 0:
        return _warn(f"[WARNING] {lock_path} 非 0 位元組（{st.st_size} bytes），"
                     f"不自動移除；請確認無 git 操作後手動處理", logger)
    if is_held_by_process(lock_path, logger):
        return _warn(f"[WARNING] {lock_path} 有行程持有（或無法判定），不自動移除", logger)
    try:
        st2 = os.stat(lock_path)
    except OSError as e:
        logger.info("刪除前複核時鎖檔已消失或不可讀: %s", e)
        return None
    if (st2.st_ino, st2.st_mtime_ns, st2.st_size) != first_id:
        return _warn(f"[WARNING] {lock_path} 在判定期間被替換（inode/mtime/size 改變），不自動移除", logger)

    write_evidence(lock_path, st, ctx, logger)  # 先記後刪
    try:
        os.remove(lock_path)
    except FileNotFoundError:
        logger.info("%s 已被他人清除", lock_path)
        return None
    except OSError as e:
        msg = f"[IMP-046] 無法移除 {lock_path}: {e}"
        logger.error(msg)
        return msg
    msg = (f"[IMP-046] 自動移除過期的 {lock_path}"
           f"（0 位元組、已存在 {lock_age:.0f} 秒、閾值 {STALE_THRESHOLD_SECONDS} 秒、無行程持有）")
    logger.info(msg)
    sys.stderr.write(msg + "\n")
    return msg


def check_and_cleanup_index_lock(
    logger: logging.Logger, cwd: Optional[str] = None,
    command: str = "", session_id: Optional[str] = None,
) -> Optional[str]:
    """對目標集合逐一解析鎖路徑並清理；回傳訊息（多筆以換行合併），無則 None。

    cwd 取 payload cwd（無則退回 get_project_root() 並留記錄）。
    非 0 位元組的舊鎖不自動移除（可能含寫到一半的索引）。
    """
    if not cwd:
        cwd = str(get_project_root())
        logger.info("payload 無 cwd，退回 get_project_root(): %s", cwd)
    if not cwd:
        return None
    ctx = {"cwd": cwd, "command": command, "session_id": session_id}
    messages: List[str] = []
    seen = set()
    for target in extract_target_dirs(command, cwd, logger):
        try:
            lock_path = resolve_lock_path(target, logger)
            real = os.path.realpath(lock_path)
            if real in seen:
                continue
            seen.add(real)
            msg = cleanup_lock(lock_path, ctx, logger)
        except Exception as e:  # 單一目標失敗不影響其他目標
            msg = None
            logger.error("目標 %s 處理失敗: %s: %s", target, type(e).__name__, e)
            sys.stderr.write(f"[WARNING] index.lock 目標處理失敗 {target}: {e}\n")
        if msg:
            messages.append(msg)
    return "\n".join(messages) if messages else None


def main():
    logger = setup_hook_logging(HOOK_NAME)

    hook_input = read_hook_input()
    if not hook_input or hook_input.get("tool_name", "") != "Bash":
        write_hook_output(create_simple_output("approve"))
        return

    command = (hook_input.get("tool_input") or {}).get("command", "")
    result_msg = check_and_cleanup_index_lock(
        logger, hook_input.get("cwd") or None, command, hook_input.get("session_id"))

    if result_msg:
        write_hook_output(create_simple_output("approve", result_msg))
    else:
        write_hook_output(create_simple_output("approve"))


if __name__ == "__main__":
    run_hook_safely(main, HOOK_NAME)
