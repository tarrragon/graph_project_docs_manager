#!/usr/bin/env python3
"""
slot_gate 模組單元測試（本機名額閘門）

驗證項目：
1. 鎖目錄不依賴 TMPDIR（不同 TMPDIR 的程序共用同一名額）
2. 閘門內部例外不以 traceback 結束（holder 寫入失敗、heavy 判定失敗）
3. 等待訊息標示過期的持有者資訊
"""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from lib import slot_gate


def test_default_slot_dir_ignores_tmpdir(tmp_path):
    """名額是全機一份：不同 session 的 TMPDIR 不同時仍指向同一目錄。"""
    code = "import sys; sys.path.insert(0, %r); from lib import slot_gate; print(slot_gate.slot_dir())" % str(
        Path(__file__).parent.parent.parent)
    outs = []
    for name in ("a", "b"):
        tmp = tmp_path / name
        tmp.mkdir()
        env = {k: v for k, v in os.environ.items() if k != "CLAUDE_SLOT_LOCK_DIR"}
        env["TMPDIR"] = str(tmp)
        outs.append(subprocess.run([sys.executable, "-c", code], env=env, capture_output=True,
                                   text=True, timeout=20).stdout.strip())
    assert outs[0] == outs[1] == os.path.join(os.path.expanduser("~"), ".cache", "claude-slot")


def test_env_override_wins(monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(tmp_path))
    assert slot_gate.slot_dir() == str(tmp_path)


def test_acquire_and_release_roundtrip(monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(tmp_path))
    hold, early = slot_gate.acquire_slot(["flutter", "test"], lambda: None)
    assert early is None and hold is not None
    info = json.loads(Path(hold.holder_path).read_text())
    assert info["pid"] == os.getpid()
    hold.release()
    assert not Path(hold.holder_path).exists()


def test_holder_write_failure_does_not_raise(monkeypatch, tmp_path, capsys):
    """entry 組裝（getloadavg）失敗也只寫一行 stderr，仍取得名額。"""
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(tmp_path))

    def boom():
        raise OSError("no loadavg")

    monkeypatch.setattr(slot_gate.os, "getloadavg", boom)
    hold, early = slot_gate.acquire_slot(["flutter", "test"], lambda: None)
    assert early is None and hold is not None
    hold.release()
    assert capsys.readouterr().err.startswith("run-with-timeout:")


def test_is_heavy_command_swallows_classifier_exception_as_heavy(monkeypatch, capsys):
    import lib.test_command_parse as parse

    def boom(_tokens):
        raise RuntimeError("classifier bug")

    monkeypatch.setattr(parse, "classify_argv_weight", boom)
    assert slot_gate.is_heavy_command(["echo", "hi"]) is True
    err = capsys.readouterr().err
    assert err.startswith("run-with-timeout:") and "Traceback" not in err


def test_stale_holder_info_is_marked(monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(tmp_path))
    dead = subprocess.Popen([sys.executable, "-c", "pass"])
    dead.wait()
    (tmp_path / "heavy-slot-0.holder.json").write_text(json.dumps({
        "pid": dead.pid, "cwd": "/x", "command": ["flutter", "test"],
        "started": "2026-10-14 00:00:00", "load": "0.1/0.1/0.1"}))
    assert "過期" in slot_gate.describe_holder(str(tmp_path))


def test_live_holder_info_not_marked_stale(monkeypatch, tmp_path):
    (tmp_path / "heavy-slot-0.holder.json").write_text(json.dumps({
        "pid": os.getpid(), "cwd": "/x", "command": ["flutter", "test"],
        "started": "2026-10-14 00:00:00", "load": "0.1/0.1/0.1"}))
    assert "過期" not in slot_gate.describe_holder(str(tmp_path))


def _expect_unused(directory, capsys):
    hold, early = slot_gate.acquire_slot(["flutter", "test"], lambda: None)
    assert hold is None and early is None
    assert capsys.readouterr().err.startswith("run-with-timeout:")
    assert not list(Path(directory).glob("heavy-slot-*")) if Path(directory).is_dir() else True


def test_dir_owned_by_someone_else_is_not_used(monkeypatch, tmp_path, capsys):
    target = tmp_path / "locks"
    target.mkdir(mode=0o700)
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(target))
    monkeypatch.setattr(slot_gate, "_owner_uid", lambda: os.getuid() + 1)
    _expect_unused(target, capsys)


def test_group_other_writable_dir_is_not_used(monkeypatch, tmp_path, capsys):
    target = tmp_path / "locks"
    target.mkdir()
    target.chmod(0o777)
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(target))
    _expect_unused(target, capsys)


def test_symlinked_dir_is_not_used(monkeypatch, tmp_path, capsys):
    real = tmp_path / "attacker"
    real.mkdir(mode=0o700)
    link = tmp_path / "locks"
    link.symlink_to(real)
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(link))
    _expect_unused(real, capsys)


def test_new_dir_is_created_private(monkeypatch, tmp_path):
    target = tmp_path / "fresh" / "locks"
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(target))
    hold, _ = slot_gate.acquire_slot(["flutter", "test"], lambda: None)
    try:
        assert hold is not None and (target.stat().st_mode & 0o077) == 0
    finally:
        hold.release()


def test_symlinked_lock_file_is_not_followed(monkeypatch, tmp_path, capsys):
    target = tmp_path / "locks"
    target.mkdir(mode=0o700)
    victim = tmp_path / "victim"
    victim.write_text("keep")
    (target / "heavy-slot-0.lock").symlink_to(victim)
    monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(target))
    hold, early = slot_gate.acquire_slot(["flutter", "test"], lambda: None)
    assert hold is None and early is None and victim.read_text() == "keep"
    assert capsys.readouterr().err.startswith("run-with-timeout:")
