"""ticket track move-lines 子命令測試（0.5.0-W1-362）。

驗證：
1. 搬移後來源減少行數等於目標增加行數，搬移段逐字相同（--at 行號 / end）。
2. E2：目標寫入失敗時非 0 且兩檔逐位元不變。
3. E2：src 或 dst 不在 where.files 內時拒絕且兩檔不變。
4. 行範圍非法、src 與 dst 相同、--at 超界時拒絕且兩檔不變。
"""
import argparse
from unittest.mock import patch

from ticket_system.commands import track_commit, track_move_lines

_TICKET_ID = "0.5.0-W1-999"
_VERSION = "0.5.0"


def _ticket(files):
    return {"id": _TICKET_ID, "type": "IMP", "where": {"files": files}}


def _args(lines, at, src="a.md", dst="b.md"):
    return argparse.Namespace(
        ticket_id=_TICKET_ID, src=src, lines=lines, dst=dst, at=at, worktree=None
    )


def _run(tmp_path, args, declared=("a.md", "b.md")):
    with patch.object(track_move_lines, "load_ticket", return_value=_ticket(list(declared))), \
         patch.object(track_commit, "resolve_project_cwd", return_value=str(tmp_path)):
        return track_move_lines.execute_move_lines(args, _VERSION)


def _setup(tmp_path):
    (tmp_path / "a.md").write_bytes(b"a1\na2\na3\na4\na5\n")
    (tmp_path / "b.md").write_bytes(b"b1\nb2\nb3\n")


def _snapshot(tmp_path):
    return (tmp_path / "a.md").read_bytes(), (tmp_path / "b.md").read_bytes()


class TestMoveLines:
    def test_moves_range_to_line_number(self, tmp_path):
        _setup(tmp_path)
        rc = _run(tmp_path, _args("2-3", "2"))
        assert rc == 0
        assert (tmp_path / "a.md").read_text() == "a1\na4\na5\n"
        assert (tmp_path / "b.md").read_text() == "b1\na2\na3\nb2\nb3\n"

    def test_moves_range_to_end(self, tmp_path):
        _setup(tmp_path)
        rc = _run(tmp_path, _args("1-1", "end"))
        assert rc == 0
        assert (tmp_path / "a.md").read_text() == "a2\na3\na4\na5\n"
        assert (tmp_path / "b.md").read_text() == "b1\nb2\nb3\na1\n"

    def test_end_when_dst_lacks_trailing_newline(self, tmp_path):
        _setup(tmp_path)
        (tmp_path / "b.md").write_bytes(b"b1\nb2")
        rc = _run(tmp_path, _args("1-2", "end"))
        assert rc == 0
        assert (tmp_path / "b.md").read_text() == "b1\nb2\na1\na2\n"

    def test_line_count_conserved(self, tmp_path):
        _setup(tmp_path)
        before = 5 + 3
        _run(tmp_path, _args("2-4", "1"))
        total = len((tmp_path / "a.md").read_text().splitlines()) + len(
            (tmp_path / "b.md").read_text().splitlines()
        )
        assert total == before


class TestRejections:
    def test_write_failure_restores_both_files(self, tmp_path, capsys):
        """E2 正向對照：目標寫入失敗，非 0 且兩檔逐位元不變。"""
        _setup(tmp_path)
        before = _snapshot(tmp_path)
        real_replace = track_move_lines.os.replace

        def fail_on_dst(tmp, final):
            if str(final).endswith("b.md"):
                raise OSError("injected")
            return real_replace(tmp, final)

        with patch.object(track_move_lines.os, "replace", side_effect=fail_on_dst):
            rc = _run(tmp_path, _args("2-3", "end"))
        assert rc != 0
        assert _snapshot(tmp_path) == before
        assert sorted(p.name for p in tmp_path.iterdir()) == ["a.md", "b.md"]

    def test_conservation_failure_writes_nothing(self, tmp_path):
        """E2：守恆驗證失敗（植入錯誤的搬移計算）時非 0 且兩檔不變。"""
        _setup(tmp_path)
        before = _snapshot(tmp_path)
        with patch.object(track_move_lines, "_plan_move",
                          return_value=(["a1\n"], ["b1\n", "b2\n", "b3\n"], ["a2\n"])):
            rc = _run(tmp_path, _args("2-3", "end"))
        assert rc != 0
        assert _snapshot(tmp_path) == before

    def test_src_out_of_scope(self, tmp_path):
        _setup(tmp_path)
        before = _snapshot(tmp_path)
        assert _run(tmp_path, _args("1-1", "end"), declared=("b.md",)) != 0
        assert _snapshot(tmp_path) == before

    def test_dst_out_of_scope(self, tmp_path):
        _setup(tmp_path)
        before = _snapshot(tmp_path)
        assert _run(tmp_path, _args("1-1", "end"), declared=("a.md",)) != 0
        assert _snapshot(tmp_path) == before

    def test_invalid_ranges_rejected(self, tmp_path):
        _setup(tmp_path)
        before = _snapshot(tmp_path)
        for lines in ("0-2", "3-2", "4-9", "x", "2"):
            assert _run(tmp_path, _args(lines, "end")) != 0
        for at in ("0", "5", "zz"):
            assert _run(tmp_path, _args("1-1", at)) != 0
        assert _snapshot(tmp_path) == before

    def test_same_file_rejected(self, tmp_path):
        _setup(tmp_path)
        before = _snapshot(tmp_path)
        assert _run(tmp_path, _args("1-1", "end", dst="a.md")) != 0
        assert _snapshot(tmp_path) == before

    def test_permissions_preserved_on_success(self, tmp_path):
        _setup(tmp_path)
        for name in ("a.md", "b.md"):
            (tmp_path / name).chmod(0o755)
        assert _run(tmp_path, _args("1-1", "end")) == 0
        for name in ("a.md", "b.md"):
            assert (tmp_path / name).stat().st_mode & 0o777 == 0o755

    def test_permissions_preserved_on_restore(self, tmp_path):
        _setup(tmp_path)
        for name in ("a.md", "b.md"):
            (tmp_path / name).chmod(0o755)
        real_replace = track_move_lines.os.replace

        def fail_on_dst(tmp, final):
            if str(final).endswith("b.md"):
                raise OSError("injected")
            return real_replace(tmp, final)

        with patch.object(track_move_lines.os, "replace", side_effect=fail_on_dst):
            assert _run(tmp_path, _args("1-1", "end")) != 0
        for name in ("a.md", "b.md"):
            assert (tmp_path / name).stat().st_mode & 0o777 == 0o755

    def test_line_boundary_is_newline_only(self, tmp_path):
        (tmp_path / "a.md").write_bytes(b"a1\na\x0c2\na3\n")
        (tmp_path / "b.md").write_bytes(b"b1\n")
        assert _run(tmp_path, _args("2-2", "end")) == 0
        assert (tmp_path / "a.md").read_bytes() == b"a1\na3\n"
        assert (tmp_path / "b.md").read_bytes() == b"b1\na\x0c2\n"

    def test_restore_failure_gives_clear_message(self, tmp_path, capsys):
        _setup(tmp_path)
        real_replace = track_move_lines.os.replace
        calls = {"a": 0}

        def fail(tmp, final):
            if str(final).endswith("b.md"):
                raise OSError("injected dst")
            if str(final).endswith("a.md"):
                calls["a"] += 1
                if calls["a"] >= 2:
                    raise OSError("injected restore")
            return real_replace(tmp, final)

        with patch.object(track_move_lines.os, "replace", side_effect=fail):
            rc = _run(tmp_path, _args("1-1", "end"))
        out = capsys.readouterr().out
        assert rc != 0
        assert "還原失敗" in out and "備份" in out

    def test_fullwidth_digits_rejected(self, tmp_path):
        _setup(tmp_path)
        assert _run(tmp_path, _args("１-２", "end")) != 0
        assert _run(tmp_path, _args("1-1", "１")) != 0

    def test_crlf_file_keeps_crlf_when_filling_newline(self, tmp_path):
        (tmp_path / "a.md").write_bytes(b"a1\r\na2\r\n")
        (tmp_path / "b.md").write_bytes(b"b1\r\nb2")
        assert _run(tmp_path, _args("1-1", "end")) == 0
        assert (tmp_path / "b.md").read_bytes() == b"b1\r\nb2\r\na1\r\n"

    def test_missing_ticket(self, tmp_path):
        _setup(tmp_path)
        with patch.object(track_move_lines, "load_ticket", return_value=None):
            assert track_move_lines.execute_move_lines(_args("1-1", "end"), _VERSION) != 0
