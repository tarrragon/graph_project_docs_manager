#!/usr/bin/env python3
"""列出（或終止）本專案範圍內的孤兒測試程序。

用法：python3 .claude/scripts/orphan-test-procs.py [--kill]

不帶引數：只列出，不終止，結束碼 0。
--kill：對符合者先 TERM，寬限後仍存活才 KILL；送訊號前會重讀該 PID 的父程序與命令，
        與認定時不同則不送。結束碼：0 全數處理完；1 有目標未能終止；2 ps/git 等外部命令失敗。

認定須四項皆符合：
1. 父程序為 1（已被 launchd 收養）
2. 非殭屍（ps 狀態不以 Z 開頭）
3. 命令屬已知測試執行器：直接執行 RUNNERS 之一，或經直譯器啟動（-m 模組名或腳本檔名）
4. 工作目錄位於專案根目錄或其 git worktree 之下

特殊情形：
- 工作目錄無法取得或已刪除：無法確認屬於本專案，不終止，僅列為「略過」。
- 子程序自行脫離群組但父程序仍存活：父程序非 1，不符合，不列出。
- 命令列含空白路徑時 ps 無法分辨詞界，認定採保守的啟發式（見 is_runner）。
"""
import argparse
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import List, NamedTuple, Optional

# 已知測試執行器（直接執行時的檔名，或經直譯器啟動時的腳本檔名／-m 模組名）
RUNNERS = frozenset({"flutter_tester", "pytest", "py.test", "jest", "vitest"})
INTERPRETER_RE = re.compile(r"^(python[\d.]*|node|bun|deno)$", re.IGNORECASE)
SCRIPT_EXTS = (".py", ".js", ".mjs", ".cjs", ".ts")
# TERM 後給程序收尾的寬限秒數
GRACE_SECONDS = 3.0
POLL_INTERVAL = 0.05


class Proc(NamedTuple):
    pid: int
    ppid: int
    stat: str
    command: str


class CommandError(Exception):
    """外部命令無法執行或回傳非 0。"""


def _run(cmd: List[str], tolerate_failure: bool = False) -> str:
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as exc:
        raise CommandError(f"無法執行 {cmd[0]}：{exc}")
    if res.returncode != 0 and not tolerate_failure:
        raise CommandError(f"{' '.join(cmd)} 失敗（結束碼 {res.returncode}）：{res.stderr.strip()}")
    return res.stdout


def list_processes() -> List[Proc]:
    out = _run(["ps", "-axo", "pid=,ppid=,stat=,command="])
    procs = []
    for line in out.splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4 and parts[0].isdigit() and parts[1].isdigit():
            procs.append(Proc(int(parts[0]), int(parts[1]), parts[2], parts[3]))
    return procs


def _base(token: str) -> str:
    return os.path.basename(token)


def _script_name(token: str) -> str:
    name = _base(token)
    for ext in SCRIPT_EXTS:
        if name.endswith(ext):
            return name[: -len(ext)]
    return name


def _is_known_executable(token: str) -> bool:
    return _base(token) in RUNNERS or bool(INTERPRETER_RE.match(_base(token)))


def _find_executable(tokens: List[str]) -> int:
    """回傳可執行檔所在的詞索引，找不到回 -1。

    首詞若為絕對路徑，路徑中的空白會把它切成多詞；此時往後找第一個含 "/" 且
    檔名屬 RUNNERS 或直譯器的詞。非絕對路徑只看首詞（避免 grep pytest 之類誤認）。
    """
    if _is_known_executable(tokens[0]):
        return 0
    if tokens[0].startswith("/"):
        for i, t in enumerate(tokens[1:], 1):
            if t.startswith("-"):
                break
            if "/" in t and _is_known_executable(t):
                return i
    return -1


def _interpreter_runs_runner(rest: List[str]) -> bool:
    """直譯器之後的引數是否啟動測試執行器（-m 模組名，或腳本檔名）。"""
    i = 0
    while i < len(rest) and rest[i].startswith("-"):
        if rest[i] == "-m":
            return i + 1 < len(rest) and rest[i + 1] in RUNNERS
        if rest[i] in ("-c", "-e", "-p", "--eval", "--print"):
            return False
        i += 1
    if i >= len(rest):
        return False
    if _script_name(rest[i]) in RUNNERS:
        return True
    if not rest[i].startswith("/"):
        return False
    # 絕對路徑含空白：往後延伸，遇已知副檔名的非執行器腳本即停
    for t in rest[i + 1:]:
        is_other_script = _base(t).endswith(SCRIPT_EXTS) and _script_name(t) not in RUNNERS
        if t.startswith("-") or is_other_script:
            return False
        if "/" in t and _script_name(t) in RUNNERS:
            return True
    return False


def is_runner(command: str) -> bool:
    tokens = command.split()
    if not tokens:
        return False
    idx = _find_executable(tokens)
    if idx < 0:
        return False
    if _base(tokens[idx]) in RUNNERS:
        return True
    return _interpreter_runs_runner(tokens[idx + 1:])


def process_cwd(pid: int) -> Optional[str]:
    """回傳程序工作目錄；無法取得時回 None（程序已結束時 lsof 回非 0，視為無法取得）。"""
    out = _run(["lsof", "-a", "-d", "cwd", "-Fn", "-p", str(pid)], tolerate_failure=True)
    for line in out.splitlines():
        if line.startswith("n"):
            return line[1:]
    return None


def project_roots(root: Optional[str]) -> List[str]:
    """專案根目錄加上其 git worktree 根目錄（realpath）。

    給定 root 時直接以它為唯一範圍，不展開 worktree（測試與縮小範圍用）。
    """
    if root:
        return [os.path.realpath(root)]
    base = _run(["git", "-C", str(Path(__file__).resolve().parent),
                 "rev-parse", "--show-toplevel"]).strip()
    listing = _run(["git", "-C", base, "worktree", "list", "--porcelain"])
    roots = [os.path.realpath(base)]
    roots += [os.path.realpath(l[len("worktree "):])
              for l in listing.splitlines() if l.startswith("worktree ")]
    return sorted(set(roots))


def under(path: str, roots: List[str]) -> bool:
    real = os.path.realpath(path)
    return any(real == r or real.startswith(r + os.sep) for r in roots)


def classify(procs: List[Proc], roots: List[str]):
    """回傳 (符合者, 略過者)；略過者為 (Proc, 原因)。"""
    matched, skipped = [], []
    for p in procs:
        if p.ppid != 1 or p.stat.startswith("Z") or not is_runner(p.command):
            continue
        cwd = process_cwd(p.pid)
        if cwd is None:
            skipped.append((p, "無法取得 cwd"))
        elif not os.path.isdir(cwd):
            skipped.append((p, f"cwd 已刪除：{cwd}"))
        elif under(cwd, roots):
            matched.append(p)
    return matched, skipped


def _send(pid: int, sig: int) -> None:
    try:
        os.kill(pid, sig)
    except ProcessLookupError:
        pass  # 已結束
    except PermissionError:
        # macOS 對殭屍送訊號回 EPERM；他人程序亦同。是否仍存活由 terminate 的存活檢查回報
        pass


def _is_alive(pid: int) -> bool:
    out = _run(["ps", "-o", "stat=", "-p", str(pid)], tolerate_failure=True).strip()
    return bool(out) and not out.startswith("Z")


def _same_identity(p: Proc) -> bool:
    """該 PID 目前仍是認定時的那個程序（父程序為 1 且命令未變）。"""
    out = _run(["ps", "-o", "ppid=,command=", "-p", str(p.pid)], tolerate_failure=True).strip()
    parts = out.split(None, 1)
    return len(parts) == 2 and parts[0] == "1" and parts[1] == p.command


def terminate(p: Proc, grace: float = GRACE_SECONDS) -> str:
    """回傳 "terminated"、"changed"（身份已變，未送訊號）或 "survived"。"""
    if not _same_identity(p):
        return "terminated" if not _is_alive(p.pid) else "changed"
    _send(p.pid, signal.SIGTERM)
    deadline = time.monotonic() + grace
    while time.monotonic() < deadline and _is_alive(p.pid):
        time.sleep(POLL_INTERVAL)
    if _is_alive(p.pid):
        if not _same_identity(p):
            return "changed"
        _send(p.pid, signal.SIGKILL)
        time.sleep(POLL_INTERVAL)
    return "survived" if _is_alive(p.pid) else "terminated"


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="列出或終止本專案範圍的孤兒測試程序")
    ap.add_argument("--kill", action="store_true", help="終止符合者（先 TERM 後 KILL）")
    ap.add_argument("--root", help=argparse.SUPPRESS)  # 測試用，不列入說明
    args = ap.parse_args(argv)
    try:
        matched, skipped = classify(list_processes(), project_roots(args.root))
    except CommandError as exc:
        sys.stderr.write(f"錯誤：{exc}\n")
        return 2
    for p in matched:
        print(f"符合 {p.pid} {p.command}")
    for p, reason in skipped:
        print(f"略過 {p.pid} {p.command}（{reason}）")
    failed = 0
    if args.kill:
        for p in matched:
            try:
                result = terminate(p)
            except CommandError as exc:
                sys.stderr.write(f"錯誤：{exc}\n")
                return 2
            if result == "terminated":
                print(f"已終止 {p.pid}")
            elif result == "changed":
                print(f"未終止 {p.pid}（送訊號前身份已變，不處理）")
            else:
                failed += 1
                print(f"未能終止 {p.pid}（送出 KILL 後仍存活）")
    print(f"符合 {len(matched)} 略過 {len(skipped)}")
    if not args.kill:
        print("僅列出，未終止任何程序；加 --kill 才終止")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
