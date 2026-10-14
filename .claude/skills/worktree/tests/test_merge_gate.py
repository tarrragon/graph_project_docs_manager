"""
合併前全套件閘門測試

套件執行器一律注入假的，不真的跑 hooks 或 flutter 全套件。快照建立與移除用 tmp repo 實測；
名額序列化用 tmp 目錄內的小型 pytest 實測。
"""

import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / ".claude"))

import merge_gate as mg  # noqa: E402
import worktree_manager as wm  # noqa: E402
from lib.test_command_parse import WEIGHT_HEAVY, classify_argv_weight  # noqa: E402

TICKET_FILE = "docs/work-logs/v0/v0.5/v0.5.0/tickets/9.9.9-W1-001.md"


def git(repo, *args):
    proc = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    return proc.stdout.strip()


def commit_file(repo, name, text, msg):
    path = repo / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    git(repo, "add", name)
    git(repo, "commit", "-m", msg)


@pytest.fixture
def repo(tmp_path, monkeypatch):
    monkeypatch.setattr(wm, "_sleep", lambda _s: None)
    r = tmp_path / "repo"
    r.mkdir()
    git(r, "init", "-b", "main")
    git(r, "config", "user.email", "t@example.com")
    git(r, "config", "user.name", "t")
    commit_file(r, "lib/marker.txt", "clean\n", "base marker")
    commit_file(r, "lib/other.txt", "o\n", "base other")
    commit_file(r, TICKET_FILE, "t0\n", "base ticket")
    git(r, "checkout", "-b", "feat")
    commit_file(r, "lib/other.txt", "o-feat\n", "feat edit")
    git(r, "checkout", "main")
    monkeypatch.chdir(r)
    monkeypatch.setattr(wm, "get_project_root", lambda: str(r))
    monkeypatch.setattr(wm, "get_worktree_list", lambda: [])
    return r


def snapshots(repo):
    return [ln for ln in git(repo, "worktree", "list").splitlines() if mg.SNAPSHOT_PREFIX in ln]


def make_artifact(cwd):
    art = Path(cwd) / ".dart_tool" / "package_config.json"
    art.parent.mkdir(exist_ok=True)
    art.write_text("{}")


def art(run):
    """為假執行器補上生成產物步驟（pub get 時建立檔案並回 0），其餘交給 run。"""
    def wrapped(argv, cwd):
        if "pub" in argv:
            make_artifact(cwd)
            return 0, ""
        return run(argv, cwd)
    return wrapped


def green_runner(calls):
    def run(argv, cwd):
        calls.append((argv, cwd))
        if "pub" in argv:
            make_artifact(cwd)
        return 0, "ok"
    return run


class TestRedGreen:
    def test_red_does_not_merge_and_lists_failures(self, repo):
        old = git(repo, "rev-parse", "main")
        seen = {}

        def red(argv, cwd):
            seen["main_during_check"] = git(repo, "rev-parse", "main")
            return 1, "collected\nFAILED tests/test_x.py::test_boom - assert 1 == 2\n"

        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), art(red)))
        assert not out.ok
        assert "FAILED tests/test_x.py::test_boom" in out.error
        assert git(repo, "rev-parse", "main") == old
        assert seen["main_during_check"] == old  # 檢查時 update-ref 尚未發生
        assert snapshots(repo) == []

    def test_green_merges(self, repo):
        calls = []
        old = git(repo, "rev-parse", "main")
        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), green_runner(calls)))
        assert out.ok and git(repo, "rev-parse", "main") == out.commit_sha != old
        assert len([c for c in calls if "pub" not in c[0]]) == 1

    def test_cmd_merge_red_returns_nonzero(self, repo, capsys):
        old = git(repo, "rev-parse", "main")
        rc = wm.cmd_merge(None, branch="feat", gate_runner=art(lambda a, c: (1, "FAILED t::x\n")))
        assert rc == 1
        assert "FAILED t::x" in capsys.readouterr().out
        assert git(repo, "rev-parse", "main") == old

    def test_cmd_merge_green_returns_zero(self, repo):
        assert wm.cmd_merge(None, branch="feat", gate_runner=art(green_runner([]))) == 0


class TestHeavySlot:
    def test_suite_commands_are_wrapped_and_heavy(self):
        for suite, cmd in mg.SUITE_COMMANDS.items():
            argv = mg.wrapped_argv(cmd, str(ROOT))
            assert argv[1].endswith("run-with-timeout.py"), suite
            assert argv[argv.index("--") + 1:] == cmd
            assert classify_argv_weight(cmd) == WEIGHT_HEAVY, suite

    def test_runner_receives_wrapped_argv(self, repo):
        calls = []
        wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), green_runner(calls)))
        argv = calls[-1][0]
        assert argv[1].endswith("run-with-timeout.py") and "--" in argv

    def test_two_concurrent_runs_are_serialized(self, tmp_path, monkeypatch):
        slots = tmp_path / "slots"
        slots.mkdir(mode=0o700)
        monkeypatch.setenv("CLAUDE_SLOT_LOCK_DIR", str(slots))
        stamps = {}

        def make_dir(name):
            d = tmp_path / name
            d.mkdir()
            (d / "test_stamp.py").write_text(
                "import time, pathlib\n"
                "def test_stamp():\n"
                f"    pathlib.Path(r'{d}/start').write_text(str(time.time()))\n"
                "    time.sleep(1.0)\n"
                f"    pathlib.Path(r'{d}/end').write_text(str(time.time()))\n"
            )
            return d

        def run(d):
            argv = mg.wrapped_argv([sys.executable, "-m", "pytest", "-q", "-p", "no:cacheprovider"], str(ROOT), 120)
            stamps[d.name] = mg.default_runner(argv, str(d))[0]

        dirs = [make_dir("a"), make_dir("b")]
        threads = [threading.Thread(target=run, args=(d,)) for d in dirs]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        assert stamps == {"a": 0, "b": 0}
        spans = sorted((float((d / "start").read_text()), float((d / "end").read_text())) for d in dirs)
        assert spans[1][0] >= spans[0][1]  # 第二份在第一份結束後才開始


def _touch(root, rel, text=""):
    f = root / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)


@pytest.fixture
def skel(tmp_path):
    """模擬合併快照：三種 skill 型態 + 無 tests 的 skill。"""
    r = tmp_path / "snap"
    for name, pyproject, imports_lib in (("withpy", True, True), ("nopy", False, True), ("lone", True, False)):
        _touch(r, f".claude/skills/{name}/tests/test_a.py")
        _touch(r, f".claude/skills/{name}/mod.py", "from lib import x\n" if imports_lib else "import os\n")
        if pyproject:
            _touch(r, f".claude/skills/{name}/pyproject.toml")
    _touch(r, ".claude/skills/docsonly/SKILL.md")
    return str(r)


class TestScope:
    def test_flutter_scope(self, skel):
        assert mg.select_suites(["lib/main.dart"], skel) == [mg.SUITE_FLUTTER]

    def test_hooks_and_other_claude_paths_run_hooks(self, skel):
        for p in (".claude/hooks/x.py", ".claude/rules/core/a.md", ".claude/settings.json",
                  ".claude/skills/docsonly/SKILL.md"):
            assert mg.select_suites([p], skel) == [mg.SUITE_HOOKS], p

    def test_skill_runs_its_own_tests_not_hooks(self, skel):
        """E2：只改 skill 不會只跑 hooks。"""
        assert mg.select_suites([".claude/skills/withpy/mod.py"], skel) == ["skill:withpy"]
        assert mg.select_suites([".claude/skills/nopy/tests/test_a.py"], skel) == ["skill:nopy"]

    def test_scripts_scope(self, skel):
        assert mg.select_suites([".claude/scripts/run-with-timeout.py"], skel) == [mg.SUITE_SCRIPTS]

    def test_lib_runs_hooks_scripts_and_importing_skills(self, skel):
        assert mg.select_suites([".claude/lib/x.py"], skel) == [
            mg.SUITE_HOOKS, mg.SUITE_SCRIPTS, "skill:nopy", "skill:withpy"]  # lone 不匯入 lib，不在內

    def test_multiple_scopes_ordered_and_none(self, skel):
        got = mg.select_suites(["lib/a.dart", ".claude/hooks/b.py", ".claude/scripts/c.py",
                                ".claude/skills/lone/mod.py"], skel)
        assert got == [mg.SUITE_FLUTTER, mg.SUITE_HOOKS, mg.SUITE_SCRIPTS, "skill:lone"]
        assert mg.select_suites([TICKET_FILE, "README.md"], skel) == []
        assert not mg.needs_gate([TICKET_FILE, "README.md"])

    def test_new_skill_is_picked_up_without_list_edit(self, skel):
        _touch(Path(skel), ".claude/skills/brandnew/tests/test_a.py")
        assert mg.select_suites([".claude/skills/brandnew/x.py"], skel) == ["skill:brandnew"]

    def test_suite_commands(self, skel):
        assert mg.suite_command("skill:withpy", skel) == ["uv", "--directory", ".claude/skills/withpy", "run", "pytest"]
        nopy = mg.suite_command("skill:nopy", skel)
        assert nopy[:5] == ["uv", "--directory", ".claude/hooks", "run", "pytest"] and nopy[-1] == "../skills/nopy/tests"
        assert mg.suite_command(mg.SUITE_SCRIPTS, skel)[2] == ".claude/scripts"
        for suite in ("skill:withpy", "skill:nopy", mg.SUITE_SCRIPTS):
            assert classify_argv_weight(mg.suite_command(suite, skel)) == WEIGHT_HEAVY, suite

    def test_gate_runs_skill_suite_only_for_skill_change(self, repo):
        git(repo, "checkout", "-q", "feat")
        commit_file(repo, ".claude/skills/foo/tests/test_a.py", "", "foo tests")
        commit_file(repo, ".claude/skills/foo/mod.py", "x = 1\n", "foo mod")
        git(repo, "checkout", "-q", "main")
        calls = []
        gate = mg.MergeGate(str(repo), art(green_runner(calls)))
        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=gate)
        assert out.ok
        cmds = [" ".join(argv[argv.index("--") + 1:]) for argv, _ in calls]
        assert any("--directory .claude/hooks" in c and "../skills/foo/tests" in c for c in cmds)
        assert not any(c.endswith(".claude/hooks run pytest") for c in cmds)  # 不只跑 hooks 全套

    def test_skill_documents_scope_rule(self):
        text = (Path(__file__).parent.parent / "SKILL.md").read_text(encoding="utf-8")
        assert "合併前全套件" in text and "flutter test" in text and "hooks pytest" in text
        assert "skill:" in text and ".claude/scripts" in text and ".claude/lib" in text

    def test_scope_selects_runner_commands(self, repo):
        calls = []
        wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), green_runner(calls)))
        flat = [a for argv, _ in calls for a in argv]
        assert "flutter" in flat and "pytest" not in flat  # 只改 lib/，不跑 hooks


class TestSnapshot:
    def test_result_not_affected_by_dirty_main_checkout(self, repo):
        (repo / "lib" / "marker.txt").write_text("dirty\n")  # 主 checkout 未提交修改
        seen = {}

        def run(argv, cwd):
            seen["cwd"] = cwd
            return (0, "") if (Path(cwd) / "lib/marker.txt").read_text() == "clean\n" else (1, "dirty tree")

        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), art(run)))
        assert out.ok, out.error
        assert seen["cwd"] != str(repo) and mg.SNAPSHOT_PREFIX in seen["cwd"]

    @pytest.mark.parametrize("path", ["green", "red", "timeout", "interrupt"])
    def test_snapshot_removed_on_every_exit_path(self, repo, path):
        during = {}

        def run(argv, cwd):
            during["n"] = len(snapshots(repo))
            if path == "interrupt":
                raise KeyboardInterrupt
            return {"green": (0, ""), "red": (1, "x"), "timeout": (124, "")}[path]

        gate = mg.MergeGate(str(repo), art(run))
        if path == "interrupt":
            with pytest.raises(KeyboardInterrupt):
                wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=gate)
        else:
            out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=gate)
            assert out.ok == (path == "green")
            if path == "timeout":
                assert "逾時" in out.error
        assert during["n"] == 1  # 執行期間快照存在
        assert snapshots(repo) == []
        assert not list((repo / mg.SNAPSHOT_DIR).glob(mg.SNAPSHOT_PREFIX + "*"))


class TestArtifacts:
    def test_missing_artifact_generated_before_suite(self, repo):
        order = []

        def run(argv, cwd):
            if "pub" in argv:
                order.append("gen")
                art = Path(cwd) / ".dart_tool" / "package_config.json"
                art.parent.mkdir(exist_ok=True)
                art.write_text("{}")
            else:
                order.append("suite")
                assert (Path(cwd) / ".dart_tool/package_config.json").exists()
            return 0, ""

        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), run))
        assert out.ok and order == ["gen", "suite"]

    def test_generation_failure_names_missing_artifact(self, repo):
        calls = []

        def run(argv, cwd):
            calls.append(argv)
            return 1, "pub get failed"

        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), run))
        assert not out.ok and ".dart_tool/package_config.json" in out.error
        assert len(calls) == 1  # 套件本體未執行


def advance_main(repo, name, text):
    """模擬並行 session 推進 main。"""
    commit_file(repo, name, text, f"advance {name}")


class TestRetryReuse:
    def _merge_with_advance(self, repo, advance_path):
        state = {"n": 0}

        def run(argv, cwd):
            state["n"] += 1
            if state["n"] == 1:
                advance_main(repo, advance_path, "new\n")
            return 0, ""

        gate = mg.MergeGate(str(repo), art(run))
        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=gate, max_retries=mg.GATE_MAX_RETRIES)
        return out, gate

    def test_exempt_only_difference_reuses_result(self, repo):
        out, gate = self._merge_with_advance(repo, TICKET_FILE)
        assert out.ok and out.attempts == 2
        assert gate.suite_runs == 1

    def test_non_exempt_difference_reruns_suite(self, repo):
        out, gate = self._merge_with_advance(repo, "lib/new.txt")
        assert out.ok and out.attempts == 2
        assert gate.suite_runs == 2


class TestRetryCap:
    def test_cap_aborts_with_last_failure_and_keeps_branch(self, repo, capsys):
        calls = {"n": 0}

        def run(argv, cwd):
            calls["n"] += 1
            advance_main(repo, f"lib/adv{calls['n']}.txt", "x\n")  # 每次都使 CAS 失敗
            return 0, ""

        rc = wm.cmd_merge(None, branch="feat", gate_runner=art(run))
        out = capsys.readouterr().out
        assert rc == 1
        assert "expected" in out  # 回報最後一次失敗原因（CAS 預算與閘門上限擇先中止）
        assert calls["n"] == mg.GATE_MAX_RETRIES + 1
        merged = subprocess.run(["git", "merge-base", "--is-ancestor", "feat", "main"], cwd=repo).returncode
        assert merged != 0  # main 未含分支（ref 未被寫成合併 commit）
        assert git(repo, "rev-parse", "--verify", "refs/heads/feat")


    def test_explicit_cap_message_names_limit_and_last_error(self, repo):
        calls = {"n": 0}

        def run(argv, cwd):
            calls["n"] += 1
            advance_main(repo, f"lib/adv{calls['n']}.txt", "x\n")
            return 0, ""

        old_branch = git(repo, "rev-parse", "feat")
        out = wm.merge_branch_cas("feat", repo=str(repo), pre_merge_check=mg.MergeGate(str(repo), art(run)),
                                  max_retries=1)
        assert not out.ok and "上限 1" in out.error and "expected" in out.error
        assert calls["n"] == 2
        assert git(repo, "rev-parse", "feat") == old_branch


class TestBypassFlag:
    def test_skip_gate_logs_reason_and_skips_runner(self, repo, capsys):
        called = []
        rc = wm.cmd_merge(None, branch="feat", skip_gate_reason="緊急修復", gate_runner=green_runner(called))
        assert rc == 0 and called == []
        log = (repo / ".claude/logs/worktree-merge.log").read_text(encoding="utf-8")
        assert "略過合併前測試" in log and "緊急修復" in log

    def test_skip_gate_without_reason_rejected(self, repo):
        old = git(repo, "rev-parse", "main")
        assert wm.cmd_merge(None, branch="feat", skip_gate_reason="  ") == 1
        assert git(repo, "rev-parse", "main") == old


class TestExemptList:
    def test_patterns(self):
        assert mg.is_reuse_exempt(TICKET_FILE)
        assert mg.is_reuse_exempt("docs/work-logs/v0/v0.5/v0.5.0-main.md")
        assert not mg.is_reuse_exempt("docs/work-logs/topic-assignments.txt")
        assert not mg.is_reuse_exempt("docs/spec/ui/domain-map.md")

    def test_list_is_exactly_two_globs(self):
        assert mg.RETRY_REUSE_EXEMPT_GLOBS == ("docs/work-logs/**/tickets/*.md", "docs/work-logs/**/v*-main.md")

    def test_guard_flags_test_reading_real_exempt_file(self, tmp_path):
        """E2 正向對照：讀取清單內實際檔案的樣本須為紅。"""
        (tmp_path / "docs/work-logs/v1/tickets").mkdir(parents=True)
        (tmp_path / "docs/work-logs/v1/tickets/1.0.0-W1-001.md").write_text("x")
        (tmp_path / "test").mkdir()
        (tmp_path / "test/a_test.dart").write_text(
            "File('docs/work-logs/v1/tickets/1.0.0-W1-001.md').readAsStringSync();\n")
        (tmp_path / "test/b_test.dart").write_text(
            "expect(p, 'docs/work-logs/v1/tickets/not-there.md');\n")
        hits = mg.find_exempt_file_reads(tmp_path)
        assert hits == [("test/a_test.dart", "docs/work-logs/v1/tickets/1.0.0-W1-001.md")]

    def test_no_test_reads_exempt_files(self):
        assert mg.find_exempt_file_reads(ROOT) == []
