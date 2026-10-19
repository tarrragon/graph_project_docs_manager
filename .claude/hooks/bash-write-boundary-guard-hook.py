#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///

"""
Bash Write Boundary Guard Hook - PreToolUse Hook

main-thread-edit-restriction-hook.py 僅註冊於 PreToolUse 的 Edit/Write/MultiEdit
matcher，禁止主線程（PM）寫入 test/、lib/、*.dart。該限制可被 Bash 寫入操作
（heredoc / cat > / cat >> / tee / sed -i / python 內嵌腳本 open() / cp / mv）
完全繞過，繞過後無留痕、無法事後偵測（來源分析結論：職責邊界執法類 guard，
繞過後不可事後偵測，須以 PreToolUse 層攔截，不能靠事後補救）。本 hook 是該
缺口的補網。

觸發時機: 執行 Bash 工具時
行為: 偵測到明確寫入 test/、lib/、*.dart 的 Bash 語法 → 轉呼
      lib/path_permission.check_file_permission() 判斷 → 不允許則 DENY（exit 2）；
      未偵測到明確寫入目標 → 一律 ALLOW（保守白名單策略，fail-open）。

兩層檢查：
- 第一層（主線程與代理人皆適用，不受開發分支跳過影響）：候選路徑以 payload cwd
  解析、換算成所在 checkout 根目錄的相對路徑，落在 lib/、test/、integration_test/、
  .claude/** 即 DENY。豁免：建置快取（.venv、__pycache__ 等）、.claude 本地執行期
  產物（hook-logs、dispatch-active.json 等，清單對齊 .gitignore）、.git/、
  checkout 外路徑（暫存區、/dev/null）、git mv。ticket／doc CLI 自寫檔不經 shell
  重導向，命令文字無目標路徑，不受影響。
- 第二層（僅主線程；與 main-thread-edit-restriction-hook.py 一致）：轉呼
  check_file_permission，開發分支（feat/*、fix/* 等）跳過
- 失敗語意 fail_closed：解析例外或分派層逾時時擋下
- 殘留風險清單（靜態解析 fail-open，未偵測）：
  直譯器內動態組成的路徑；先寫腳本到 checkout 外再執行的兩步驟；
  bash -c／eval 字串內的寫入；$VAR／命令替換／~ 組成的路徑；
  awk -i inplace、ruby、install、truncate、patch、tar -C、dd of=、rsync、ln -s、
  touch、curl -o 與版本控制的還原類子命令（命令集合為列舉式）
- 不含跨專案判斷：Bash command 無單一 file_path，無法用
  find_target_repo() 判斷目標 repo；candidate path 皆以當前
  CLAUDE_PROJECT_DIR 正規化，跨專案 Bash 寫入若剛好命中
  test/lib/dart pattern 仍會被攔（已知的偏保守行為，優先度低於
  漏放）

偵測形態：
- cat > path / cat >> path（含 heredoc 重導向 `cat > path <<'EOF' ... EOF`）
- tee path / tee -a path
- sed -i ... path / sed --in-place ... path（原地編輯目標）
- python -c / python3 heredoc 內嵌腳本中的 open('path', ...) 呼叫
- cp src dst / mv src dst（目的地路徑）
- 一般輸出重導向 > path / >> path（排除檔案描述符重導向 2>、&>）

解析方式：
命令以單趟字元走訪切成「陳述 -> token」，每個字元只看一次，整體 O(n)，
不使用有回溯風險的複合正則（sed 判定用的正則曾兩度因回溯耗時形成逾時繞過）。
- heredoc 正文與引號內文字不是命令：不進入 token 走訪，描述寫入的文字不誤擋
- 例外：陳述的命令為 python* 時，其原文與 heredoc 正文掃描 open() 呼叫；
  命令為 sh/bash/zsh 時，heredoc 正文會被執行，遞迴解析（深度 2）
- bash -c '...' 字串內的寫入不在本 hook 範圍

FP 邊界（fail-open，保守白名單原則）：
抽出候選路徑後僅在正規化後命中 test/、lib/、*.dart 才轉呼判斷邏輯；
未命中或無法辨識寫入語法一律放行，不做「default deny」。
不設命令長度上限：解析為線性，長度上限只會增加誤擋面（大型 heredoc 正文
合法存在），不增加防護。
"""

import os
import posixpath
import re
import sys
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).parent))         # .claude/hooks/
sys.path.insert(0, str(Path(__file__).parent.parent))   # .claude/       (lib.*)

from lib import setup_hook_logging, run_hook_safely, read_json_from_stdin, is_subagent_environment, emit_hook_output
from lib.git_utils import get_current_branch, is_allowed_branch
from lib.path_permission import check_file_permission, normalize_path

EXIT_ALLOW = 0
EXIT_BLOCK = 2

_MAX_HEREDOC_RECURSION = 2


# ============================================================================
# 命令解析：單趟 token 走訪（O(n)）
# ============================================================================

# 無特殊意義的連續字元，整段一次吃掉（字元集互斥，無回溯）
_PLAIN_RUN = re.compile(r"[^'\"\\\s;|&()`<>#]+")

# python open('path', ...) / open("path", ...)
# 字串可帶 1-2 字元前綴（f、r、rb 等）；第二個參數（模式）可為位置或 mode= 關鍵字
_OPEN_CALL_PATTERN = re.compile(
    r"open\(\s*[A-Za-z]{0,2}(['\"])([^'\"]+)\1(?:\s*,\s*(?:mode\s*=\s*)?[A-Za-z]{0,2}(['\"])([^'\"]*)\3)?"
)

# Path('x').write_text(...) / write_bytes(...)（含 pathlib.Path 前綴）
_PATH_WRITE_PATTERN = re.compile(
    r"Path\(\s*[A-Za-z]{0,2}(['\"])([^'\"]+)\1\s*\)\s*\.write_(?:text|bytes)\("
)


def _python_write_targets(text: str) -> List[str]:
    """python 原文中的寫入目標：open() 僅在模式含 w／a／x／+ 時算寫入（沒給模式為唯讀）。"""
    out = [m.group(2) for m in _OPEN_CALL_PATTERN.finditer(text)
           if m.group(4) and any(ch in m.group(4) for ch in "waxWAX+")]
    out.extend(m.group(2) for m in _PATH_WRITE_PATTERN.finditer(text))
    return out

_PYTHON_NAME = re.compile(r"python[\d.]*")
_SHELL_NAMES = frozenset({"sh", "bash", "zsh"})
_HEREDOC_DELIM_STOP = frozenset(" \t\r\n;|&()<>")


class _Statement:
    """一個以 | ; & 換行 ( ) 切出的陳述。"""

    __slots__ = ("tokens", "targets", "bodies", "start", "end", "pre")

    def __init__(self, start: int) -> None:
        self.tokens: List[str] = []    # 引號已剝除的 token（不含重導向目標）
        self.targets: List[str] = []   # 輸出重導向目標
        self.bodies: List[str] = []    # 此陳述宣告的 heredoc 正文
        self.start = start
        self.end = start
        self.pre = ""                  # 此陳述之前累積的括號邊界字元（只含 "(" 與 ")"）


def _read_heredoc_delimiter(command: str, i: int):
    """從 i 讀 heredoc 結束標記（去引號與反斜線），回傳 (word, 下一位置)。"""
    n = len(command)
    word: List[str] = []
    while i < n and command[i] not in _HEREDOC_DELIM_STOP:
        c = command[i]
        if c not in "'\"\\":
            word.append(c)
        i += 1
    return "".join(word), i


def _read_heredoc_bodies(command: str, pos: int, pending):
    """自 pos（換行後）依序讀取每個 pending heredoc 的正文，回傳 (bodies, 新位置)。"""
    n = len(command)
    bodies: List[str] = []
    for strip_tabs, word in pending:
        lines: List[str] = []
        while pos <= n:
            eol = command.find("\n", pos)
            if eol == -1:
                eol = n
            line = command[pos:eol]
            pos = eol + 1
            if (line.lstrip("\t") if strip_tabs else line) == word:
                break
            lines.append(line)
            if eol == n:
                break
        bodies.append("\n".join(lines))
    return bodies, min(pos, n)


def _parse_statements(command: str) -> List[_Statement]:
    """單趟走訪，把命令切成陳述與 token；每個字元至多處理一次。"""
    n = len(command)
    stmts: List[_Statement] = []
    cur = _Statement(0)
    buf: List[str] = []
    has_tok = False
    redirect: Optional[str] = None  # None / 'write' / 'skip'
    pending: list = []
    parens = ""  # 尚未歸屬任何陳述的括號邊界字元
    i = 0

    def flush() -> None:
        nonlocal buf, has_tok, redirect
        if not has_tok:
            return
        text = "".join(buf)
        if redirect == "dup":
            # >&N、>&- 是 fd 複製／關閉，其餘 >&word 是寫檔
            if not (text.isdigit() or text == "-"):
                cur.targets.append(text)
        elif redirect == "write":
            cur.targets.append(text)
        elif redirect != "skip":
            cur.tokens.append(text)
        redirect = None
        buf = []
        has_tok = False

    def end_statement(end_pos: int, next_start: int, boundary: str = "") -> None:
        nonlocal cur, redirect, parens
        flush()
        cur.end = end_pos
        if cur.tokens or cur.targets or cur.bodies:
            cur.pre = parens
            parens = ""
            stmts.append(cur)
        if boundary in ("(", ")"):
            parens += boundary
        cur = _Statement(next_start)
        redirect = None

    while i < n:
        c = command[i]
        m = _PLAIN_RUN.match(command, i)
        if m:
            buf.append(m.group())
            has_tok = True
            i = m.end()
        elif c == "'":
            j = command.find("'", i + 1)
            j = n if j == -1 else j
            buf.append(command[i + 1:j])
            has_tok = True
            i = j + 1
        elif c == '"':
            j = i + 1
            while j < n and command[j] != '"':
                j += 2 if command[j] == "\\" else 1
            buf.append(command[i + 1:min(j, n)])
            has_tok = True
            i = j + 1
        elif c == "\\":
            if i + 1 < n and command[i + 1] != "\n":
                buf.append(command[i + 1])
                has_tok = True
            i += 2
        elif c == "\n":
            if pending:
                bodies, nxt = _read_heredoc_bodies(command, i + 1, pending)
                cur.bodies.extend(bodies)
                pending = []
                end_statement(i, nxt)
                i = nxt
            else:
                end_statement(i, i + 1)
                i += 1
        elif c in " \t\r":
            flush()
            i += 1
        elif c == "#" and not has_tok:
            j = command.find("\n", i)
            i = n if j == -1 else j
        elif c == ">":
            fd_text = "".join(buf) if has_tok else ""
            is_fd = fd_text.isdigit()
            if is_fd:
                buf = []
                has_tok = False
            else:
                flush()
            i += 2 if command.startswith(">>", i) else 1
            # 0> 視為 skip；1、2、>=3 的 fd 目標皆是寫入
            skip = is_fd and fd_text.lstrip("0") == ""
            dup = False
            if i < n and command[i] in "&|":
                dup = command[i] == "&"
                i += 1
            redirect = "skip" if skip else ("dup" if dup else "write")
        elif c == "<":
            if command.startswith("<<<", i):
                flush()
                i += 3
            elif command.startswith("<<", i):
                flush()
                i += 2
                strip_tabs = i < n and command[i] == "-"
                i += 1 if strip_tabs else 0
                while i < n and command[i] in " \t":
                    i += 1
                word, i = _read_heredoc_delimiter(command, i)
                pending.append((strip_tabs, word))
            else:
                flush()
                redirect = "skip"
                i += 1
        elif c == "&" and command.startswith("&>", i):
            flush()
            i += 3 if command.startswith("&>>", i) else 2
            redirect = "write"
        else:
            # ; | & ( ) `：陳述邊界
            end_statement(i, i + 1, c)
            i += 1

    end_statement(n, n)
    return stmts


def _basename(token: str) -> str:
    return token.rsplit("/", 1)[-1]


def _skip_empty_or_suffix(toks: List[str], j: int) -> int:
    """BSD 形式 `-i ''` / `-i .bak`：略過 -i 之後的備份後綴 token。"""
    if j < len(toks) and (toks[j] == "" or toks[j].startswith(".")):
        return j + 1
    return j


def _scan_sed(toks: List[str], j: int, out: List[str]) -> int:
    """從 sed 之後的 token 起走訪一次，原地編輯時收集檔案目標，回傳結束位置。"""
    m = len(toks)
    inplace = False
    has_script_opt = False
    end_opts = False
    positionals: List[str] = []
    while j < m:
        t = toks[j]
        j += 1
        if end_opts or t == "" or t[0] != "-" or t == "-":
            positionals.append(t)
        elif t == "--":
            end_opts = True
        elif t.startswith("--"):
            if t.startswith("--in-place"):
                inplace = True
            elif t in ("--expression", "--file"):
                has_script_opt = True
                j += 1
            elif t.startswith(("--expression=", "--file=")):
                has_script_opt = True
        else:
            k = 1
            while k < len(t):
                ch = t[k]
                if ch == "i":
                    inplace = True
                    if t == "-i":
                        j = _skip_empty_or_suffix(toks, j)
                    break
                if ch in "ef":
                    has_script_opt = True
                    if k == len(t) - 1:
                        j += 1
                    break
                k += 1
    if inplace:
        out.extend(positionals if has_script_opt else positionals[1:])
    return m


def _scan_cp_mv(toks: List[str], j: int, out: List[str]) -> int:
    """cp / mv：略過旗標，最後一個位置參數為目的地（至少需要來源與目的地）。"""
    positionals: List[str] = []
    target_dir: Optional[str] = None
    k = j
    while k < len(toks):
        t = toks[k]
        k += 1
        if t.startswith("--target-directory="):
            target_dir = t.split("=", 1)[1]
        elif t == "--target-directory" and k < len(toks):
            target_dir = toks[k]
            k += 1
        elif t.startswith("--") or t == "-" or t == "":
            if t in ("", "-"):
                positionals.append(t)
        elif t[0] == "-":
            if "t" in t[1:]:
                rest = t[t.index("t") + 1:]
                if rest:
                    target_dir = rest
                elif k < len(toks):
                    target_dir = toks[k]
                    k += 1
        else:
            positionals.append(t)
    if target_dir is not None:
        out.append(target_dir)  # -t DIR：所有位置參數都是來源
    elif len(positionals) >= 2:
        out.append(positionals[-1])
    return len(toks)


def _scan_perl(toks: List[str], j: int, out: List[str]) -> int:
    """perl -i / -pi / -i.bak：原地編輯，位置參數（扣掉未用 -e 時的腳本檔）為目標。"""
    inplace = False
    has_script_opt = False
    positionals: List[str] = []
    k = j
    while k < len(toks):
        t = toks[k]
        k += 1
        if len(t) > 1 and t[0] == "-" and t[1] != "-":
            for ch_idx in range(1, len(t)):
                ch = t[ch_idx]
                if ch == "i":
                    inplace = True
                    break
                if ch in "eE":
                    has_script_opt = True
                    if ch_idx == len(t) - 1:
                        k += 1
                    break
        elif not t.startswith("--"):
            positionals.append(t)
    if inplace:
        out.extend(positionals if has_script_opt else positionals[1:])
    return len(toks)


def _scan_tee(toks: List[str], j: int, out: List[str]) -> int:
    out.extend(t for t in toks[j:] if t == "" or t[0] != "-")
    return len(toks)


_ENV_ASSIGN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
_GIT_OPTS_WITH_ARG = frozenset({"-C", "-c", "--git-dir", "--work-tree", "--namespace"})


def _is_git_mv(toks: List[str]) -> bool:
    """陳述的命令字為 git（略過前置 env 賦值與 git 全域選項）且子命令為 mv。"""
    j = 0
    while j < len(toks) and _ENV_ASSIGN.match(toks[j]):
        j += 1
    if j >= len(toks) or _basename(toks[j]) != "git":
        return False
    j += 1
    while j < len(toks) and toks[j].startswith("-"):
        j += 2 if toks[j] in _GIT_OPTS_WITH_ARG else 1
    return j < len(toks) and toks[j] == "mv"


def _scan_statement_tokens(toks: List[str], out: List[str]) -> None:
    if _is_git_mv(toks):
        return  # git mv 是版本控制內的搬移（deny 訊息指定的正規做法），不是 shell 寫入
    j = 0
    while j < len(toks):
        name = _basename(toks[j])
        if name == "sed":
            j = _scan_sed(toks, j + 1, out)
        elif name == "perl":
            j = _scan_perl(toks, j + 1, out)
        elif name in ("cp", "mv"):
            j = _scan_cp_mv(toks, j + 1, out)
        elif name == "tee":
            j = _scan_tee(toks, j + 1, out)
        else:
            j += 1


def _next_cd(cur_cd: Optional[str], toks: List[str]) -> Optional[str]:
    """陳述以 cd 開頭時更新累積的 cd 位移；None 表示無法靜態判定。"""
    if not toks or _basename(toks[0]) not in ("cd", "pushd"):
        return cur_cd
    if "-" in toks[1:]:
        return None  # cd -：回到前一個目錄，無法靜態判定
    args = [t for t in toks[1:] if t == "" or t[0] != "-"]
    if not args or cur_cd is None:
        return cur_cd
    target = args[0]
    if target[:1] in ("~", "$") or "$" in target or "`" in target:
        return None
    return target if target.startswith("/") else posixpath.join(cur_cd, target)


def _collect_candidates(command: str, depth: int, dirs: Optional[List[Optional[str]]] = None,
                        base_cd: Optional[str] = "") -> List[str]:
    """dirs 非 None 時，與回傳清單逐項對應地記錄各候選路徑生效的 cd 位移（"" 為無位移）。"""
    candidates: List[str] = []
    cur_cd = base_cd
    cd_stack: List[Optional[str]] = []  # 子殼：( 保存當下位移，) 還原

    def sync() -> None:
        if dirs is not None:
            dirs.extend([cur_cd] * (len(candidates) - len(dirs)))

    for stmt in _parse_statements(command):
        for ch in stmt.pre:
            if ch == "(":
                cd_stack.append(cur_cd)
            elif cd_stack:
                cur_cd = cd_stack.pop()
        cur_cd = _next_cd(cur_cd, stmt.tokens)
        candidates.extend(stmt.targets)
        _scan_statement_tokens(stmt.tokens, candidates)
        names = [_basename(t) for t in stmt.tokens]
        if any(_PYTHON_NAME.fullmatch(name) for name in names):
            for text in [command[stmt.start:stmt.end]] + stmt.bodies:
                candidates.extend(_python_write_targets(text))
        sync()
        if depth < _MAX_HEREDOC_RECURSION and any(name in _SHELL_NAMES for name in names):
            for body in stmt.bodies:
                candidates.extend(_collect_candidates(body, depth + 1, None, cur_cd))
                sync()
    return candidates


def _extract_candidate_paths(command: str) -> List[str]:
    """
    從 Bash 命令抽取所有候選寫入目標路徑（單趟 token 走訪，O(n)）。

    heredoc 正文與引號內文字不當命令解析（描述寫入的文字不誤擋）；
    python 陳述的 open() 呼叫與 sh/bash/zsh 的 heredoc 正文因會被執行而納入。

    Returns:
        List[str] - 候選路徑清單（未去重、未正規化）
    """
    return _collect_candidates(command, 0)


def _find_boundary_violation(command: str, logger) -> Optional[str]:
    """
    掃描命令的所有候選寫入路徑，回傳第一個命中 test/、lib/、*.dart 且
    check_file_permission 判定不允許的正規化路徑；無命中回傳 None。

    Args:
        command: Bash 命令
        logger: hook logger

    Returns:
        Optional[str] - 命中的正規化路徑，或 None
    """
    for raw_path in _extract_candidate_paths(command):
        normalized = normalize_path(raw_path)

        # 窄化門檻：僅 test/、lib/、*.dart 才進一步判斷（本票範圍，
        # 避免抽取雜訊觸發 check_file_permission 的 default-deny 分支）
        is_target_scope = (
            normalized.startswith("test/")
            or normalized.startswith("lib/")
            or normalized.endswith(".dart")
        )
        if not is_target_scope:
            continue

        is_allowed, reason = check_file_permission(raw_path, logger)
        if not is_allowed:
            logger.warning(
                "偵測到 Bash 寫入職責邊界違規: path=%s reason=%s command=%s",
                normalized, reason, command,
            )
            return normalized

    return None


# ============================================================================
# 路徑範圍阻擋：主線程與代理人共用，不受開發分支跳過影響
# ============================================================================

# checkout 根目錄下，Bash 不得寫入的頂層目錄
_SCOPE_TOP_DIRS = frozenset({"lib", "test", "integration_test", ".claude"})

# 路徑任一層級為這些名稱即視為建置／快取產物
_EXEMPT_COMPONENTS = frozenset({
    ".venv", "__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache", ".dart_tool",
})

# .claude 底下的本地執行期產物。只保留「無任何 hook／閘門／CLI 讀為判定輸入、
# 也不注入模型 context」者（逐項 grep 讀取方複核後的結果）。
# 已移除：settings.local.json、dispatch-active.json／.lock、hook-state、state、handoff、
# hook-logs、logs、.sync-state.json、.version-release.yaml（皆有讀取方）。
_EXEMPT_CLAUDE_ENTRIES = frozenset({
    ".sync-conflicts", ".zhtw-mcp-skip",
    "ARCHITECTURE_REVIEW_REQUIRED", "PM_INTERVENTION_REQUIRED", "TASK_AVOIDANCE_FIX_MODE",
    "analyses", "migration-backups", "plans", "pm-status.json",
    "scheduled_tasks.lock", "tool-results",
})

_WORKTREE_PREFIX = ".claude/worktrees/"
_PROJECT_DIR_VAR = re.compile(r"^\$\{?CLAUDE_PROJECT_DIR\}?(?=/|$)")


def _find_checkout_root(cwd: str) -> str:
    """自 cwd 向上找含 .git（目錄或檔案）的目錄，即所在 checkout 根目錄；找不到回傳 cwd。"""
    cur = os.path.realpath(cwd)
    while True:
        if os.path.exists(os.path.join(cur, ".git")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return os.path.realpath(cwd)
        cur = parent


def _scope_roots(cwd: str) -> List[str]:
    """候選路徑要換算的 checkout 根目錄：所在 checkout，加上 worktree 對應的主 checkout。"""
    root = _find_checkout_root(cwd)
    roots = [root]
    marker = "/" + _WORKTREE_PREFIX
    if marker in root + "/":
        main_root = (root + "/").split(marker, 1)[0]
        if main_root and main_root != root:
            roots.append(main_root)
    return roots


def _common_dir(checkout_root: str) -> Optional[str]:
    """checkout 的 git common dir（不呼叫 git 子行程）；無法解析回傳 None。

    .git 為目錄 → 該目錄；.git 為 gitlink 檔 → 讀 gitdir 指向的目錄，
    其 commondir 檔（相對該目錄）回到主 .git。
    """
    dot_git = os.path.join(checkout_root, ".git")
    try:
        if os.path.isdir(dot_git):
            return os.path.realpath(dot_git)
        with open(dot_git, encoding="utf-8") as fh:
            first = fh.readline().strip()
        if not first.startswith("gitdir:"):
            return None
        gitdir = first[len("gitdir:"):].strip()
        if not os.path.isabs(gitdir):
            gitdir = os.path.join(checkout_root, gitdir)
        gitdir = os.path.realpath(gitdir)
        with open(os.path.join(gitdir, "commondir"), encoding="utf-8") as fh:
            common = fh.readline().strip()
        common = common if os.path.isabs(common) else os.path.join(gitdir, common)
        common = os.path.realpath(common)
        return common if os.path.isdir(common) else None
    except OSError:
        return None  # 解析失敗：視為不同 repo（不額外阻擋），見票面 Solution


def _same_repo(root_a: str, root_b: str) -> bool:
    """兩個 checkout 根目錄是否屬同一 repository（common dir 相同且可解析）。"""
    a = _common_dir(root_a)
    return a is not None and a == _common_dir(root_b)


def _owning_checkout_root(abs_path: str) -> Optional[str]:
    """目標路徑所屬 checkout 根：自 dirname 向上找第一個存在的祖先，再找含 .git 者。"""
    cur = os.path.dirname(abs_path)
    while not os.path.isdir(cur):
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent
    while True:
        if os.path.exists(os.path.join(cur, ".git")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent


def _relative_to_roots(abs_path: str, roots: List[str]) -> Optional[str]:
    for root in roots:
        if abs_path == root:
            return ""
        if abs_path.startswith(root + "/"):
            return abs_path[len(root) + 1:]
    return None


def _strip_worktree_prefix(rel: str) -> str:
    """從主 checkout 看 worktree 內的檔案：剝掉前綴，以 worktree 自己的根目錄判定。"""
    while rel.startswith(_WORKTREE_PREFIX):
        rel = rel[len(_WORKTREE_PREFIX):].partition("/")[2]
    return rel


def _scope_hit(rel: str) -> bool:
    """rel（checkout 相對路徑，已剝 worktree 前綴）是否落在阻擋範圍且不在豁免清單。"""
    parts = [p for p in rel.split("/") if p]
    if not parts or parts[0] not in _SCOPE_TOP_DIRS:
        return False
    # 建置快取只在 .claude 之外豁免：.claude/hooks／lib 下的 .pyc 會在 hook 執行時載入
    if parts[0] != ".claude" and any(p in _EXEMPT_COMPONENTS for p in parts):
        return False
    if parts[0] == ".claude" and len(parts) > 1 and parts[1] in _EXEMPT_CLAUDE_ENTRIES:
        return False
    return True


def _resolve_candidate(raw: str, cd: str, cwd: str, root: str) -> Optional[str]:
    """候選路徑解析為絕對路徑；含無法靜態判定的成分（變數、命令替換、~）回傳 None。"""
    if not raw:
        return None
    raw = _PROJECT_DIR_VAR.sub(root, raw)
    if raw[0] == "~" or "$" in raw or "`" in raw:
        return None
    return os.path.realpath(os.path.join(cwd, cd, raw))


def _find_scope_violation(command: str, cwd: str, logger) -> Optional[str]:
    """
    回傳第一個落在 lib/、test/、integration_test/、.claude/**（扣除豁免）的候選寫入路徑
    （換算成 checkout 相對路徑）；無命中回傳 None。

    候選路徑相對於 cwd（含命令內 cd 位移）解析，再換算成所在 checkout 根目錄
    （worktree 另加其主 checkout）的相對路徑比對，因此 worktree 內的 lib/x 也會命中。
    無法靜態判定的路徑（變數、命令替換、~、字串拼接）放行，見模組檔頭殘留風險。
    """
    dirs: List[Optional[str]] = []
    candidates = _collect_candidates(command, 0, dirs)
    roots = _scope_roots(cwd)
    base = os.path.realpath(cwd)
    for raw, cd in zip(candidates, dirs):
        if cd is None:
            continue
        abs_path = _resolve_candidate(raw, cd, base, roots[0])
        if abs_path is None:
            continue
        rel = _relative_to_roots(abs_path, roots)
        if rel is None:
            # 目標在 cwd 所屬 checkout 之外：若屬同 repo 的其他 worktree
            # （含主 checkout 同層的 <repo>-<ticket>），以該 checkout 為根判定
            owner = _owning_checkout_root(abs_path)
            if owner is None or not _same_repo(owner, roots[0]):
                continue
            rel = abs_path[len(owner) + 1:] if abs_path != owner else ""
        rel = _strip_worktree_prefix(rel)
        if not _scope_hit(rel):
            continue
        logger.warning("偵測到 Bash 寫入受限路徑: path=%s cwd=%s command=%s", rel, cwd, command)
        return rel
    return None


def _allow_and_exit(logger, reason: str) -> int:
    emit_hook_output("PreToolUse", permission_decision="allow", permission_decision_reason=reason)
    return EXIT_ALLOW


def main() -> int:
    """
    主入口點

    流程: 初始化 → 讀取輸入 → 工具/subagent/分支/跨專案過濾 → 候選路徑抽取
          → 命中則轉呼 check_file_permission → 輸出
    """
    logger = setup_hook_logging("bash-write-boundary-guard")

    logger.info("Bash Write Boundary Guard Hook 啟動")

    input_data = read_json_from_stdin(logger)
    if not input_data:
        logger.debug("輸入為空或解析失敗，返回預設允許")
        return _allow_and_exit(logger, "輸入為空，預設允許")

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    if tool_name != "Bash":
        logger.debug(f"跳過: 工具類型 {tool_name} 不是 Bash")
        return _allow_and_exit(logger, f"工具 {tool_name} 不在檢查範圍")

    command = tool_input.get("command", "")
    if not command:
        return _allow_and_exit(logger, "command 為空，允許")

    # 第一層：路徑範圍阻擋，主線程與代理人皆適用，不受開發分支跳過影響
    # （feat/* worktree 內若跳過，整層即失效）
    cwd = input_data.get("cwd") or os.getcwd()
    scope_path = _find_scope_violation(command, cwd, logger)
    if scope_path is not None:
        who = "代理人" if is_subagent_environment(input_data) else "主線程"
        reason = (
            f"Bash 寫入受限路徑被擋下（path={scope_path}，呼叫身份={who}）。"
            "lib/、test/、integration_test/、.claude/** 禁止透過 Bash"
            "（cat/printf/tee/sed -i/python open()/cp/mv/重導向）寫入。"
            "請改用 Edit 或 Write 工具修改檔案；搬移已追蹤的檔案用 git mv。"
            "lib/ 等處的建置快取（.dart_tool 等）與少數無讀取方的 .claude 本地產物不受此限。"
            "若這是你自己在 ! 命令中執行的操作，同樣會被擋，請改請 Claude 以 Edit 完成。"
            "若是本 hook 自身異常而誤擋正常命令，改用 Edit 修正 "
            ".claude/hooks/bash-write-boundary-guard-hook.py（Edit 不受本 hook 影響）。"
        )
        emit_hook_output(
            "PreToolUse",
            permission_decision="deny",
            permission_decision_reason=reason,
        )
        logger.info("Hook 檢查完成（路徑範圍阻擋），exit code: %d", EXIT_BLOCK)
        return EXIT_BLOCK

    # 第二層（僅主線程）：PM 可寫路徑模型。Subagent 的 lib/test 寫入權責由
    # 第一層決定，不套用 PM 模型
    if is_subagent_environment(input_data):
        logger.info(f"subagent 環境（agent_id={input_data.get('agent_id')}），路徑範圍檢查通過")
        return _allow_and_exit(logger, "subagent 的 Bash 寫入未命中受限路徑")

    # 開發分支跳過（feat/*, fix/* 等），與 main-thread-edit-restriction 一致；
    # 僅作用於第二層
    current_branch = get_current_branch()
    if current_branch and is_allowed_branch(current_branch):
        logger.info(f"開發分支 '{current_branch}' 上，跳過 Bash 寫入邊界限制")
        return _allow_and_exit(logger, f"開發分支 '{current_branch}' 不受主線程 Bash 寫入邊界限制")

    violation_path = _find_boundary_violation(command, logger)

    if violation_path is None:
        logger.debug("未偵測到明確的 test/lib/dart 寫入目標，允許（fail-open）")
        return _allow_and_exit(logger, "未偵測到職責邊界違規的 Bash 寫入形態")

    reason = (
        f"偵測到 Bash 寫入職責邊界違規（path={violation_path}）。"
        "主線程禁止透過 Bash（cat/tee/sed -i/python open()/cp/mv/heredoc 等）"
        "寫入 test/、lib/、*.dart，等同繞過 main-thread-edit-restriction-hook.py "
        "的職責邊界執法。請改派代理人執行此寫入。"
    )
    emit_hook_output(
        "PreToolUse",
        permission_decision="deny",
        permission_decision_reason=reason,
    )
    logger.info("Hook 檢查完成，exit code: %d", EXIT_BLOCK)
    return EXIT_BLOCK


if __name__ == "__main__":
    # fail_closed：此守衛的失效方向是放行；解析異常或分派層逾時時擋下，
    # 理由與負載實測見票面 Solution
    sys.exit(run_hook_safely(main, "bash-write-boundary-guard", fail_closed=True))
