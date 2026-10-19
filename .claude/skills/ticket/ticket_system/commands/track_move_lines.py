"""
ticket track move-lines 子命令

依行範圍把來源檔的一段文字搬到目標檔，於記憶體驗證行數守恆後以
暫存檔加 rename 寫入；任一步失敗即還原兩檔並以非 0 結束。

用法：
    ticket track move-lines <ticket-id> --src <path> --lines <起>-<迄> \
        --dst <path> --at <行號|end>

src 與 dst 皆須落在 ticket where.files 的寫入範圍內（與 track commit
同一判準），否則拒絕且兩檔不變。--at N 表示插入後搬移段的第一行為
目標檔第 N 行；end 為附加於目標檔尾端。
"""
if __name__ == "__main__":
    import sys
    print("[ERROR] 此檔案不支援直接執行，請使用 ticket track move-lines")
    sys.exit(1)


import argparse
import os
import tempfile
from typing import List, Optional, Tuple

from ticket_system.commands.track_commit import (
    CRITERIA_REJECTION_GUIDANCE,
    _out_of_scope_files,
    _resolve_repo_root,
    _to_repo_relative,
)
from ticket_system.lib.file_conflict import write_files
from ticket_system.lib.messages import ErrorMessages, format_error
from ticket_system.lib.ticket_loader import load_ticket


class MoveLinesError(Exception):
    """搬移前置驗證或寫入失敗（訊息直接輸出給使用者）。"""


def _parse_range(text: str, total: int) -> Tuple[int, int]:
    """解析 `起-迄`（1 起算、含兩端），回傳 0 起算的 [start, end) 切片界線。"""
    parts = text.split("-")
    if len(parts) != 2 or not all(p.isdigit() for p in parts):
        raise MoveLinesError(f"--lines 格式須為 <起>-<迄>，收到 {text!r}")
    first, last = int(parts[0]), int(parts[1])
    if first < 1 or last < first or last > total:
        raise MoveLinesError(f"--lines {text} 超出來源檔範圍（共 {total} 行）")
    return first - 1, last


def _parse_at(text: str, dst_total: int) -> int:
    """解析 --at，回傳 0 起算的插入索引；end 為檔尾。"""
    if text == "end":
        return dst_total
    if not text.isdigit() or not 1 <= int(text) <= dst_total + 1:
        raise MoveLinesError(f"--at 須為 1..{dst_total + 1} 或 end，收到 {text!r}")
    return int(text) - 1


def _with_newline(line: str) -> str:
    return line if line.endswith("\n") else line + "\n"


def _plan_move(
    src_lines: List[str], dst_lines: List[str], start: int, stop: int, at: int
) -> Tuple[List[str], List[str], List[str]]:
    """回傳 (新來源行, 新目標行, 搬移段)。

    搬移段或其前一行缺結尾換行時補上，使行邊界不因拼接而合併。
    """
    moved = [_with_newline(ln) for ln in src_lines[start:stop]]
    new_src = src_lines[:start] + src_lines[stop:]
    head = dst_lines[:at]
    if head:
        head[-1] = _with_newline(head[-1])
    return new_src, head + moved + dst_lines[at:], moved


def _verify_conservation(
    old_src: List[str], new_src: List[str], old_dst: List[str],
    new_dst: List[str], moved: List[str], at: int,
) -> None:
    """來源減少行數須等於目標增加行數，且目標內搬移段逐字等於抽出段。"""
    removed, added = len(old_src) - len(new_src), len(new_dst) - len(old_dst)
    if removed != added or removed != len(moved):
        raise MoveLinesError(
            f"行數不守恆：來源減少 {removed}、目標增加 {added}、搬移段 {len(moved)}"
        )
    if new_dst[at:at + len(moved)] != moved:
        raise MoveLinesError("目標內的搬移段與抽出段不逐字相同")


def _stage_temp(path: str, content: bytes) -> str:
    """在 path 同目錄寫暫存檔並回傳其路徑。"""
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".move-lines-")
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(content)
    except BaseException:
        os.unlink(tmp)
        raise
    return tmp


def _write_both(src: str, dst: str, new_src: bytes, new_dst: bytes,
                old_src: bytes) -> None:
    """暫存檔 rename 寫入兩檔；任一步失敗則還原來源並清除暫存檔。"""
    tmps: List[str] = []
    src_replaced = False
    try:
        tmp_src = _stage_temp(src, new_src)
        tmps.append(tmp_src)
        tmp_dst = _stage_temp(dst, new_dst)
        tmps.append(tmp_dst)
        os.replace(tmp_src, src)
        src_replaced = True
        os.replace(tmp_dst, dst)
    except OSError as exc:
        if src_replaced:
            _restore(src, old_src)
        raise MoveLinesError(f"寫入失敗，兩檔已還原：{exc}") from exc
    finally:
        for tmp in tmps:
            if os.path.exists(tmp):
                os.unlink(tmp)


def _restore(path: str, content: bytes) -> None:
    """以暫存檔 rename 還原 path 原內容（還原失敗再退回直接覆寫）。"""
    tmp = _stage_temp(path, content)
    try:
        os.replace(tmp, path)
    except OSError:
        with open(path, "wb") as fh:
            fh.write(content)
        os.unlink(tmp)


def _read_lines(path: str) -> Tuple[bytes, List[str]]:
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
        return raw, raw.decode("utf-8").splitlines(keepends=True)
    except (OSError, UnicodeDecodeError) as exc:
        raise MoveLinesError(f"無法讀取 {path}：{exc}") from exc


def _check_scope(ticket: dict, args: argparse.Namespace, repo_root: str) -> None:
    declared = {_to_repo_relative(p, repo_root, repo_root) for p in write_files(ticket)}
    out = _out_of_scope_files([args.src, args.dst], declared, repo_root, repo_root)
    if out:
        raise MoveLinesError(
            "以下檔案不在 ticket where.files 宣告的寫入範圍內，拒絕搬移：\n"
            + "\n".join(f"  - {f}" for f in out) + "\n" + CRITERIA_REJECTION_GUIDANCE
        )


def _run_move(ticket: dict, args: argparse.Namespace, repo_root: str) -> str:
    _check_scope(ticket, args, repo_root)
    src = os.path.join(repo_root, _to_repo_relative(args.src, repo_root, repo_root))
    dst = os.path.join(repo_root, _to_repo_relative(args.dst, repo_root, repo_root))
    if os.path.realpath(src) == os.path.realpath(dst):
        raise MoveLinesError("src 與 dst 不可相同")
    old_src_raw, src_lines = _read_lines(src)
    old_dst_raw, dst_lines = _read_lines(dst)
    start, stop = _parse_range(args.lines, len(src_lines))
    at = _parse_at(args.at, len(dst_lines))
    new_src, new_dst, moved = _plan_move(src_lines, dst_lines, start, stop, at)
    _verify_conservation(src_lines, new_src, dst_lines, new_dst, moved, at)
    _write_both(src, dst, "".join(new_src).encode("utf-8"),
                "".join(new_dst).encode("utf-8"), old_src_raw)
    return f"[OK] 已搬移 {len(moved)} 行：{args.src}:{args.lines} -> {args.dst}（--at {args.at}）"


def execute_move_lines(args: argparse.Namespace, version: str) -> int:
    """`ticket track move-lines`：成功回 0，任何拒絕或失敗回 1（兩檔不變）。"""
    ticket = load_ticket(version, args.ticket_id)
    if not ticket:
        print(format_error(ErrorMessages.TICKET_NOT_FOUND, ticket_id=args.ticket_id))
        return 1
    repo_root: Optional[str] = _resolve_repo_root(getattr(args, "worktree", None))
    if repo_root is None:
        print(f"[ERROR] --worktree {args.worktree} 不是合法的 git 目錄")
        return 1
    try:
        print(_run_move(ticket, args, repo_root))
    except MoveLinesError as exc:
        print(f"[ERROR] {exc}")
        return 1
    return 0


def register_move_lines_command(subparsers: "argparse._SubParsersAction") -> None:
    """註冊 move-lines 子命令。"""
    p = subparsers.add_parser(
        "move-lines",
        help="依行範圍搬移文字（src/dst 須在 where.files 內，驗證行數守恆後原子寫入）",
    )
    p.add_argument("ticket_id", help="Ticket ID")
    p.add_argument("--src", required=True, help="來源檔路徑")
    p.add_argument("--lines", required=True, help="來源行範圍 <起>-<迄>（1 起算、含兩端）")
    p.add_argument("--dst", required=True, help="目標檔路徑")
    p.add_argument("--at", required=True, help="目標檔插入位置：行號或 end")
    p.add_argument("--worktree", default=None, help="檔案所在 linked worktree 絕對路徑")
