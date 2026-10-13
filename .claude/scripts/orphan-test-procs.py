#!/usr/bin/env python3
"""列出（或終止）本專案範圍內的孤兒測試程序。

用法：python3 .claude/scripts/orphan-test-procs.py [--kill]

不帶引數：只列出，不終止，結束碼 0。
--kill：對符合者先 TERM，寬限後仍存活才 KILL；送訊號前會重讀該 PID 的父程序與命令，
        與認定時不同則不送。結束碼：0 全數處理完；1 有目標未能終止；2 ps/git 等外部命令失敗。

認定須四項皆符合：
1. 父程序為 1（已被 launchd 收養）
2. 非殭屍（ps 狀態不以 Z 開頭）
3. 命令屬已知測試執行器：首詞為 RUNNERS 之一，或首詞為直譯器且緊接 -m 模組名／執行器腳本
4. 工作目錄位於專案根目錄或其 git worktree 之下

特殊情形：
- 工作目錄無法取得或已刪除：無法確認屬於本專案，不終止，僅列為「略過」。
- 子程序自行脫離群組但父程序仍存活：父程序非 1，不符合，不列出。
- 首詞為絕對路徑但該檔案不存在（含執行檔已被刪除的程序）：不認定。
- 命令列的詞界無法由 ps 分辨，認定只看首詞（見 is_runner）：執行檔路徑含空白、
  直譯器帶值選項、測試執行器的工作程序皆不支援，寧可漏認，不可誤認。
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
# KILL 後等待目標消失的期限秒數（機器過載時 KILL 生效可能晚於一個輪詢間隔）
KILL_WAIT_SECONDS = 3.0


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


def _interpreter_runs_runner(rest: List[str]) -> bool:
    """直譯器之後的第一個引數是否啟動測試執行器（-m 模組名，或執行器腳本）。

    只看緊接在直譯器之後的詞：-m 取模組名，-mNAME 取 NAME；其他選項（含帶值的
    -W、-X、--require 等）一律不認定，因為無法分辨選項的值與腳本詞。
    """
    if not rest:
        return False
    first = rest[0]
    if first == "-m":
        return len(rest) > 1 and rest[1] in RUNNERS
    if first.startswith("-m"):
        return first[2:] in RUNNERS
    if first.startswith("-"):
        return False
    return _script_name(first) in RUNNERS


def _is_regular_file(path: str) -> bool:
    """磁碟上是否存在該一般檔案（獨立成函式，供測試替換）。"""
    return os.path.isfile(path)


def is_runner(command: str) -> bool:
    """只看首詞；後方任何詞都不用來推測被空白切斷的路徑（寧可漏認，不可誤認）。

    首詞為絕對路徑時須為磁碟上存在的一般檔案：被空白切斷的半截路徑不是檔案。
    """
    tokens = command.split()
    if not tokens or not _is_known_executable(tokens[0]):
        return False
    if os.path.isabs(tokens[0]) and not _is_regular_file(tokens[0]):
        return False
    if _base(tokens[0]) in RUNNERS:
        return True
    return _interpreter_runs_runner(tokens[1:])


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


def _ps_query(pid: int, fields: str) -> str:
    """查詢單一 PID 的 ps 欄位。找不到該 PID（結束碼 1 且無 stderr）回空字串；其餘失敗拋 CommandError。"""
    cmd = ["ps", "-o", fields, "-p", str(pid)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as exc:
        raise CommandError(f"無法執行 ps：{exc}")
    if res.returncode != 0 and (res.returncode != 1 or res.stderr.strip()):
        raise CommandError(f"{' '.join(cmd)} 失敗（結束碼 {res.returncode}）：{res.stderr.strip()}")
    return res.stdout.strip()


def _is_alive(pid: int) -> bool:
    out = _ps_query(pid, "stat=")
    return bool(out) and not out.startswith("Z")


def _same_identity(p: Proc) -> bool:
    """該 PID 目前仍是認定時的那個程序（父程序為 1 且命令未變）。"""
    parts = _ps_query(p.pid, "ppid=,command=").split(None, 1)
    return len(parts) == 2 and parts[0] == "1" and parts[1] == p.command


def _wait_gone(pid: int, seconds: float) -> bool:
    """在期限內輪詢；回傳是否已消失。"""
    deadline = time.monotonic() + seconds
    while _is_alive(pid):
        if time.monotonic() >= deadline:
            return False
        time.sleep(POLL_INTERVAL)
    return True


def terminate(p: Proc, grace: float = GRACE_SECONDS) -> str:
    """回傳 terminated／gone（未送訊號即已不存在）／changed（送訊號前身份已變）／
    changed_after_term（TERM 後仍存活但身份已變，未送 KILL）／survived。"""
    if not _same_identity(p):
        return "gone" if not _is_alive(p.pid) else "changed"
    _send(p.pid, signal.SIGTERM)
    if _wait_gone(p.pid, grace):
        return "terminated"
    if not _same_identity(p):
        return "changed_after_term"
    _send(p.pid, signal.SIGKILL)
    return "terminated" if _wait_gone(p.pid, KILL_WAIT_SECONDS) else "survived"


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        description="列出或終止本專案範圍的孤兒測試程序",
        epilog="不支援（會漏認，不會誤認）：執行檔路徑含空白；直譯器帶值選項"
               "（python 的 -W、-X，node 的 -r、--require、--import、--loader）；"
               "測試執行器的工作程序（如 jest、vitest 的 worker）。")
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
            elif result == "gone":
                print(f"已不存在 {p.pid}（未送訊號時即已結束）")
            elif result == "changed":
                print(f"未終止 {p.pid}（送訊號前身份已變，不處理）")
            elif result == "changed_after_term":
                failed += 1
                print(f"未終止 {p.pid}（已送出 TERM，TERM 後身份已變，未送 KILL）")
            else:
                failed += 1
                print(f"未能終止 {p.pid}（送出 KILL 後仍存活）")
    print(f"符合 {len(matched)} 略過 {len(skipped)}")
    if not args.kill:
        print("僅列出，未終止任何程序；加 --kill 才終止")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
