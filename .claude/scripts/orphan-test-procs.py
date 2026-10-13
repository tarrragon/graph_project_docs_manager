#!/usr/bin/env python3
"""列出（或終止）本專案範圍內的孤兒測試程序。

用法：orphan-test-procs.py [--kill] [--root <目錄>]

不帶引數：只列出，不終止，結束碼 0。
--kill：對符合者先 TERM，寬限後仍存活才 KILL。可重複執行；無孤兒時輸出固定、結束碼 0。
--root：覆寫專案根目錄（預設為本腳本所在 git 專案的根目錄；測試用）。

認定須三項皆符合：
1. 父程序為 1（已被 launchd 收養）
2. 命令屬已知測試執行器清單（RUNNERS）
3. 工作目錄位於專案根目錄或其 git worktree 之下

特殊情形：
- 工作目錄無法解析或指向已刪除目錄：無法確認屬於本專案，不終止，僅列為「略過」。
- 子程序自行脫離群組但父程序仍存活：父程序非 1，不符合，不列出。
  （若其父程序之後結束而被收養，下次執行即符合。）
"""
import argparse
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import List, NamedTuple, Optional

# 已知測試執行器（命令第一個詞的檔名）
RUNNERS = frozenset({"flutter_tester", "pytest", "py.test", "jest", "vitest"})
# TERM 後給程序收尾的寬限秒數
GRACE_SECONDS = 3.0
POLL_INTERVAL = 0.05


class Proc(NamedTuple):
    pid: int
    ppid: int
    stat: str
    command: str


def list_processes() -> List[Proc]:
    out = subprocess.run(["ps", "-axo", "pid=,ppid=,stat=,command="],
                         capture_output=True, text=True).stdout
    procs = []
    for line in out.splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4 and parts[0].isdigit() and parts[1].isdigit():
            procs.append(Proc(int(parts[0]), int(parts[1]), parts[2], parts[3]))
    return procs


def is_runner(command: str) -> bool:
    return os.path.basename(command.split(None, 1)[0]) in RUNNERS


def process_cwd(pid: int) -> Optional[str]:
    """回傳程序工作目錄；無法取得時回 None。"""
    out = subprocess.run(["lsof", "-a", "-d", "cwd", "-Fn", "-p", str(pid)],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith("n"):
            return line[1:]
    return None


def project_roots(root: Optional[str]) -> List[str]:
    """專案根目錄加上其 git worktree 根目錄（realpath）。"""
    base = root or subprocess.run(
        ["git", "-C", str(Path(__file__).resolve().parent), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True).stdout.strip()
    roots = [os.path.realpath(base)] if base else []
    if base:
        listing = subprocess.run(["git", "-C", base, "worktree", "list", "--porcelain"],
                                 capture_output=True, text=True).stdout
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
        if cwd is None or not os.path.isdir(cwd):
            skipped.append((p, "cwd 無法解析或已刪除"))
        elif under(cwd, roots):
            matched.append(p)
    return matched, skipped


def _send(pid: int, sig: int) -> None:
    try:
        os.kill(pid, sig)
    except ProcessLookupError:
        pass  # 已結束
    except PermissionError:
        # macOS 對殭屍送訊號回 EPERM；他人程序亦同，本指令不處理後者
        pass


def _is_alive(pid: int) -> bool:
    out = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)],
                         capture_output=True, text=True).stdout.strip()
    return bool(out) and not out.startswith("Z")


def terminate(pid: int, grace: float = GRACE_SECONDS) -> None:
    _send(pid, signal.SIGTERM)
    deadline = time.monotonic() + grace
    while time.monotonic() < deadline and _is_alive(pid):
        time.sleep(POLL_INTERVAL)
    if _is_alive(pid):
        _send(pid, signal.SIGKILL)


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="列出或終止本專案範圍的孤兒測試程序")
    ap.add_argument("--kill", action="store_true", help="終止符合者（先 TERM 後 KILL）")
    ap.add_argument("--root", help="覆寫專案根目錄")
    args = ap.parse_args(argv)
    matched, skipped = classify(list_processes(), project_roots(args.root))
    for p in matched:
        print(f"孤兒 {p.pid} {p.command}")
    for p, reason in skipped:
        print(f"略過 {p.pid} {p.command}（{reason}）")
    if args.kill:
        for p in matched:
            terminate(p.pid)
            print(f"已終止 {p.pid}")
    print(f"符合 {len(matched)} 略過 {len(skipped)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
