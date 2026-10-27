"""run_integration_tests.py 的彙總邏輯與 merge-gate.yaml failure 正規式測試（子程序以 mock 取代）。"""
import re
import sys
from pathlib import Path

import pytest
import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import run_integration_tests as rit  # noqa: E402

START_FAIL = ("Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.\n"
              "Failed to load x_test.dart: Unable to start the app on the device.\n")
PASS_OUT = "Failed to foreground app; open returned 1\n+36 ~2: All tests passed!\n"


def fake(results):
    """results: {檔: (rc, output)}；回傳 runner 與呼叫紀錄。"""
    calls = []

    def runner(f):
        calls.append(f)
        return results[f]
    return runner, calls


def test_all_pass_returns_zero():
    runner, calls = fake({"a": (0, PASS_OUT), "b": (0, PASS_OUT)})
    assert rit.run_all(["a", "b"], runner) == 0
    assert calls == ["a", "b"]


def test_one_file_fails_is_nonzero_and_later_files_still_run():
    runner, calls = fake({"a": (1, "boom"), "b": (0, PASS_OUT)})
    assert rit.run_all(["a", "b"], runner) != 0
    assert calls == ["a", "b"]


@pytest.mark.parametrize("order", [("bad", "ok"), ("ok", "bad")])
def test_app_start_failure_not_overwritten_by_later_pass(order):
    outcomes = {"bad": (1, START_FAIL), "ok": (0, PASS_OUT)}
    runner, _ = fake(outcomes)
    assert rit.run_all(list(order), runner) != 0


def test_start_failure_text_with_zero_rc_is_still_failure():
    runner, _ = fake({"a": (0, START_FAIL)})
    assert rit.run_all(["a"], runner) != 0


def test_no_files_is_nonzero():
    assert rit.run_all([], lambda f: (0, "")) != 0


def test_discover_recursive_only_test_suffix_sorted(tmp_path):
    base = tmp_path / "integration_test"
    (base / "research").mkdir(parents=True)
    for name in ["b_test.dart", "a_test.dart", "research/deep_test.dart", "research/ux_main.dart", "helper.dart"]:
        (base / name).write_text("")
    assert rit.discover_tests(tmp_path) == [
        "integration_test/a_test.dart", "integration_test/b_test.dart", "integration_test/research/deep_test.dart"]


def test_discover_missing_dir_is_empty(tmp_path):
    assert rit.discover_tests(tmp_path) == []


def _declared():
    root = HERE.parents[2]
    decl = yaml.safe_load((root / ".claude/project-integration/merge-gate.yaml").read_text())
    return decl["suites"]["flutter-integration"]


def test_declared_failure_regex_matches_failure_not_pass():
    rx = re.compile(_declared()["failure"])
    assert any(rx.search(ln) for ln in START_FAIL.splitlines())
    assert not any(rx.search(ln) for ln in PASS_OUT.splitlines())
    assert not rx.search("Failed to foreground app; open returned 1")


def _research():
    root = HERE.parents[2]
    decl = yaml.safe_load((root / ".claude/project-integration/merge-gate.yaml").read_text())
    return decl["suites"]["research-python"]


def test_research_suite_triggers_on_research_dir_and_declares_both_dirs():
    s = _research()
    assert "docs/research/" in s["prefixes"]
    assert "docs/research/common" in s["command"] and "docs/research/ui-vision-choice" in s["command"]


def test_research_regexes_red_vs_green():
    s = _research()
    summary, failure = re.compile(s["summary"]), re.compile(s["failure"])
    red = ["FAILED docs/research/common/test_sampler.py::t - assert False", "1 failed, 22 passed in 0.06s"]
    green = ["22 passed in 0.14s"]
    assert any(failure.search(ln) for ln in red) and not any(failure.search(ln) for ln in green)
    assert summary.search(red[1]) and summary.search(green[0])


def test_timeout_returns_nonzero_and_message_matches_declared_failure(capsys):
    def runner(f):
        raise rit.SuiteTimeout()
    assert rit.run_all(["a", "b"], runner) == rit.EXIT_TIMEOUT
    err = capsys.readouterr().err
    assert rit.TIMEOUT_MESSAGE in err
    rx = re.compile(_declared()["failure"])
    assert any(rx.search(ln) for ln in err.splitlines())  # 正向對照
    assert not any(rx.search(ln) for ln in PASS_OUT.splitlines())


def test_timeout_kills_process_group_with_no_survivors(monkeypatch):
    import subprocess
    import time
    real = subprocess.Popen

    def fake_popen(argv, **kw):
        return real(["sh", "-c", "sleep 307 & wait"], **kw)
    monkeypatch.setattr(rit.subprocess, "Popen", fake_popen)
    with pytest.raises(rit.SuiteTimeout):
        rit.run_streaming("x", deadline=time.monotonic() + 1)
    monkeypatch.undo()  # subprocess.Popen 是全域物件，須還原才能跑 pgrep
    time.sleep(0.3)
    out = subprocess.run(["pgrep", "-f", "sleep 307"], capture_output=True, text=True).stdout.split()
    assert out == []


def _main_with(monkeypatch, argv):
    """以 mock 取代子程序啟動，回傳 (結束碼, run_streaming 呼叫次數)。"""
    started = []
    monkeypatch.setattr(rit, "run_streaming", lambda f, deadline=0: started.append(f) or (0, PASS_OUT))
    monkeypatch.setattr(rit, "discover_tests", lambda root: ["integration_test/a_test.dart"])
    try:
        code = rit.main(argv)
    except SystemExit as e:
        code = e.code
    return code, len(started)


@pytest.mark.parametrize("argv", [["--help"], ["-h"], ["--bogus"], ["extra"]])
def test_help_and_unknown_args_start_nothing_and_exit_usage(monkeypatch, argv):
    code, started = _main_with(monkeypatch, argv)
    assert started == 0
    assert code == rit.EXIT_USAGE
    assert code not in (0, rit.EXIT_TIMEOUT, rit.EXIT_NO_TESTS, rit.EXIT_FAILED)


def test_no_args_still_runs_tests(monkeypatch):
    code, started = _main_with(monkeypatch, [])
    assert started == 1  # 正向對照：mock 有鑑別力
    assert code == 0


def test_declared_command_calls_wrapper():
    assert _declared()["command"] == ["python3", ".claude/project-integration/run_integration_tests.py"]
