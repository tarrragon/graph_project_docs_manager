"""
Unit tests for git-index-lock-cleanup-hook.

Source: 0.18.0-W17-194 — 強化 lock 殘留警告訊息加入 GUI app 外部進程偵測
Related: PC-139 (git-index-lock-source-misattribution-gui-app-fork)
"""

import importlib.util
import os
import re
import sys
import time
from pathlib import Path
from unittest.mock import patch

import pytest


HOOK_PATH = Path(__file__).resolve().parent.parent / "git-index-lock-cleanup-hook.py"


@pytest.fixture(scope="module")
def hook_module():
    sys.path.insert(0, str(HOOK_PATH.parent))
    sys.path.insert(0, str(HOOK_PATH.parent.parent))
    spec = importlib.util.spec_from_file_location(
        "git_index_lock_cleanup_hook", HOOK_PATH
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def fresh_lock(tmp_path):
    """建立一個 .git/index.lock 模擬剛產生的 lock（lock_age < threshold）。"""
    git_dir = tmp_path / ".git"
    git_dir.mkdir()
    lock = git_dir / "index.lock"
    lock.write_text("")
    return tmp_path, lock


def test_fresh_lock_message_contains_gui_app_names(hook_module, fresh_lock):
    """訊息必須包含 4 個 GUI app 名稱（Fork / GitKraken / SourceTree / VS Code）。"""
    project_root, _ = fresh_lock
    with patch.object(hook_module, "get_project_root", return_value=str(project_root)):
        import logging
        logger = logging.getLogger("test")
        msg = hook_module.check_and_cleanup_index_lock(logger)

    assert msg is not None
    for name in ("Fork", "GitKraken", "SourceTree", "VS Code"):
        assert name in msg, f"訊息缺少 GUI app 名稱: {name}"


def test_fresh_lock_message_contains_ps_aux_detection(hook_module, fresh_lock):
    """訊息必須包含 ps aux 外部進程偵測指令範例。"""
    project_root, _ = fresh_lock
    with patch.object(hook_module, "get_project_root", return_value=str(project_root)):
        import logging
        logger = logging.getLogger("test")
        msg = hook_module.check_and_cleanup_index_lock(logger)

    assert msg is not None
    # regex match: ps aux | grep ... Fork|GitKraken|SourceTree
    assert re.search(r"ps\s+aux\s*\|\s*grep", msg), "訊息缺少 ps aux | grep 偵測指令"
    assert re.search(r"Fork\|GitKraken\|SourceTree", msg), "訊息缺少 GUI app pattern"


def test_fresh_lock_message_contains_pc139_reference(hook_module, fresh_lock):
    """訊息必須 cross-link 至 PC-139 error-pattern。"""
    project_root, _ = fresh_lock
    with patch.object(hook_module, "get_project_root", return_value=str(project_root)):
        import logging
        logger = logging.getLogger("test")
        msg = hook_module.check_and_cleanup_index_lock(logger)

    assert msg is not None
    assert "PC-139" in msg, "訊息缺少 PC-139 引用"
    assert (
        "PC-139-git-index-lock-source-misattribution-gui-app-fork" in msg
    ), "訊息缺少 PC-139 完整檔案名引用"


def test_no_lock_returns_none(hook_module, tmp_path):
    """無 lock 檔時應回傳 None。"""
    (tmp_path / ".git").mkdir()
    with patch.object(hook_module, "get_project_root", return_value=str(tmp_path)):
        import logging
        logger = logging.getLogger("test")
        msg = hook_module.check_and_cleanup_index_lock(logger)
    assert msg is None


def test_stale_lock_auto_removed(hook_module, tmp_path):
    """過期 lock 自動移除，訊息含 IMP-046 標記。"""
    git_dir = tmp_path / ".git"
    git_dir.mkdir()
    lock = git_dir / "index.lock"
    lock.write_text("")
    # 將 mtime 設為遠超過 STALE_THRESHOLD_SECONDS
    old_time = time.time() - (hook_module.STALE_THRESHOLD_SECONDS + 60)
    os.utime(lock, (old_time, old_time))

    with patch.object(hook_module, "get_project_root", return_value=str(tmp_path)):
        import logging
        logger = logging.getLogger("test")
        msg = hook_module.check_and_cleanup_index_lock(logger)

    assert msg is not None
    assert "IMP-046" in msg
    assert not lock.exists(), "過期 lock 應被自動移除"


# ---- 0.5.0-W1-164.2：linked worktree 與三項刪除條件 ----

import logging
import subprocess


def _sh(cwd, *args):
    subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True)


@pytest.fixture
def wt(tmp_path):
    """tmp repo + linked worktree；回傳 (worktree 路徑, 其 index.lock 路徑)。"""
    main = tmp_path / "main"
    main.mkdir()
    _sh(main, "init", "-q")
    _sh(main, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "i")
    w = tmp_path / "wt"
    _sh(main, "worktree", "add", "-q", str(w), "-b", "wtb")
    r = subprocess.run(["git", "-C", str(w), "rev-parse", "--git-path", "index.lock"],
                       capture_output=True, text=True, check=True)
    lock = Path(r.stdout.strip())
    if not lock.is_absolute():
        lock = w / lock
    return w, lock


def _run(hook_module, root):
    with patch.object(hook_module, "get_project_root", return_value=str(root)):
        return hook_module.check_and_cleanup_index_lock(logging.getLogger("test"))


def _age(lock, hook_module):
    t = time.time() - (hook_module.STALE_THRESHOLD_SECONDS + 60)
    os.utime(lock, (t, t))


def test_worktree_lock_path_is_under_worktrees_dir(hook_module, wt):
    w, lock = wt
    assert "worktrees" in lock.parts
    assert Path(hook_module.resolve_lock_path(str(w), logging.getLogger("test"))).resolve() == lock.resolve()


def test_worktree_stale_empty_lock_removed(hook_module, wt):
    w, lock = wt
    lock.write_text("")
    _age(lock, hook_module)
    msg = _run(hook_module, w)
    assert msg and "IMP-046" in msg
    assert not lock.exists()


def test_worktree_nonempty_lock_kept(hook_module, wt):
    w, lock = wt
    lock.write_text("x")
    _age(lock, hook_module)
    msg = _run(hook_module, w)
    assert msg and "非 0 位元組" in msg
    assert lock.exists()


def test_worktree_young_lock_kept(hook_module, wt):
    w, lock = wt
    lock.write_text("")
    msg = _run(hook_module, w)
    assert msg and "WARNING" in msg
    assert lock.exists()


def test_worktree_lock_held_by_process_kept(hook_module, wt):
    """liveness：真實行程持有鎖檔時不得刪除。"""
    w, lock = wt
    lock.write_text("")
    _age(lock, hook_module)
    holder = subprocess.Popen(["tail", "-f", str(lock)], stdout=subprocess.DEVNULL)
    try:
        time.sleep(0.5)
        msg = _run(hook_module, w)
    finally:
        holder.kill()
        holder.wait()
    assert msg and "有行程持有" in msg
    assert lock.exists()


def test_lsof_unavailable_fails_safe(hook_module, wt):
    """失敗語意：無法判定持有者時不刪。"""
    w, lock = wt
    lock.write_text("")
    _age(lock, hook_module)
    with patch.object(hook_module, "is_held_by_process", wraps=hook_module.is_held_by_process), \
         patch.object(hook_module.subprocess, "run", side_effect=[
             subprocess.CompletedProcess([], 0, stdout=str(lock) + "\n", stderr=""),
             OSError("no lsof"),
         ]):
        msg = _run(hook_module, w)
    assert msg and "不自動移除" in msg
    assert lock.exists()


# ---- 合併前追修：payload cwd、刪除前複核、lsof 判定、解析失敗記錄 ----

import json


def _aged_empty(lock, hook_module):
    lock.write_text("")
    _age(lock, hook_module)


def test_payload_cwd_beats_env_real_stdin(hook_module, wt, tmp_path):
    """env 指主 repo、payload cwd 為 worktree：清 worktree 的鎖，主 repo 的鎖不動（真實 stdin）。"""
    w, wlock = wt
    main = tmp_path / "main"
    mlock = main / ".git" / "index.lock"
    _aged_empty(wlock, hook_module)
    _aged_empty(mlock, hook_module)
    payload = {"tool_name": "Bash", "tool_input": {"command": "git add x"}, "cwd": str(w)}
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(main))
    r = subprocess.run(
        ["python3", str(HOOK_PATH)], input=json.dumps(payload),
        capture_output=True, text=True, env=env, timeout=60,
    )
    assert r.returncode == 0, r.stderr
    assert not wlock.exists(), "worktree 的鎖應被清"
    assert mlock.exists(), "主 repo 的鎖不得被動"


def test_lock_replaced_during_lsof_not_removed(hook_module, wt):
    w, lock = wt
    _aged_empty(lock, hook_module)

    def swap(path, logger):
        os.remove(path)
        with open(path, "w"):
            pass
        return False

    with patch.object(hook_module, "is_held_by_process", side_effect=swap):
        msg = _run(hook_module, w)
    assert lock.exists(), "新 inode 的鎖不得被刪"
    assert msg and "被替換" in msg


@pytest.mark.parametrize("rc,out,err,held", [
    (1, "", "", False),
    (1, "", "lsof: WARNING", True),
    (2, "", "", True),
    (0, "123\n", "", True),
    (127, "", "", True),
])
def test_lsof_result_matrix(hook_module, rc, out, err, held):
    cp = subprocess.CompletedProcess([], rc, stdout=out, stderr=err)
    with patch.object(hook_module.subprocess, "run", return_value=cp):
        assert hook_module.is_held_by_process("/x", logging.getLogger("test")) is held


def test_lsof_timeout_treated_as_held(hook_module):
    with patch.object(hook_module.subprocess, "run",
                      side_effect=subprocess.TimeoutExpired("lsof", 5)):
        assert hook_module.is_held_by_process("/x", logging.getLogger("test")) is True


def test_rev_parse_failure_logged_and_falls_back(hook_module, tmp_path, caplog):
    with caplog.at_level(logging.WARNING, logger="test"):
        with patch.object(hook_module.subprocess, "run",
                          side_effect=subprocess.TimeoutExpired("git", 5)):
            p = hook_module.resolve_lock_path(str(tmp_path), logging.getLogger("test"))
    assert p == str(tmp_path / ".git" / "index.lock")
    assert "無法解析" in caplog.text


def test_fresh_lock_message_uses_resolved_path(hook_module, wt, capsys):
    w, lock = wt
    lock.write_text("")
    msg = _run(hook_module, w)
    assert str(lock) in msg
    assert str(lock) in capsys.readouterr().err
