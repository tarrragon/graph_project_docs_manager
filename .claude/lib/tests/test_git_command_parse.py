#!/usr/bin/env python3
"""
git_command_parse 模組單元測試（0.2.1-W3-708）

驗證項目：
1. strip_heredoc_bodies：本體剝離 + 找不到收尾界線時的保底還原
2. normalize_newlines_to_separators：換行轉語句分隔符，引號內換行不受影響
3. is_literal_pathspec_token：廣域 pathspec 判定（. / ./ / :/ / 萬用字元 / 尾斜線）
4. is_shell_redirection_token：重導向 token 辨識
5. find_git_invocations：
   - 失敗語意：None（無法 tokenize）vs []（可解析但無命中）明確區分
   - 前綴包裹穿透：sudo / nohup / time / xargs / env KEY=VAL / 裸 KEY=VAL
   - git 全域選項穿透：-c / --git-dir / --work-tree 等，-C 特別擷取
   - 子命令別名：stage -> add
   - 多語句（&&/;/|/||/()）各自命中
   - heredoc 內文與引號內容不誤判為真實呼叫
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from lib.git_command_parse import (
    contains_git_word,
    strip_heredoc_bodies,
    normalize_newlines_to_separators,
    is_literal_pathspec_token,
    is_shell_redirection_token,
    find_git_invocations,
    GitInvocation,
)


class TestContainsGitWord:
    def test_git_word_present(self):
        assert contains_git_word("git commit -m x") is True

    def test_empty_command(self):
        assert contains_git_word("") is False

    def test_no_git_word(self):
        assert contains_git_word("pytest tests/") is False

    def test_word_boundary_not_substring(self):
        assert contains_git_word("echo legit commit message") is False


class TestStripHeredocBodies:
    def test_no_heredoc_marker_unchanged(self):
        assert strip_heredoc_bodies("git commit -m x") == "git commit -m x"

    def test_single_quoted_delimiter_stripped(self):
        command = "cat <<'EOF'\nsome content\nEOF\n"
        result = strip_heredoc_bodies(command)
        assert "some content" not in result
        assert "<<'EOF'" in result

    def test_unquoted_delimiter_stripped(self):
        command = "cat <<EOF\nsome content\nEOF\n"
        result = strip_heredoc_bodies(command)
        assert "some content" not in result

    def test_dash_delimiter_stripped(self):
        command = "cat <<-EOF\n\tsome content\nEOF\n"
        result = strip_heredoc_bodies(command)
        assert "some content" not in result

    def test_missing_end_delimiter_rolls_back_unchanged(self):
        """找不到收尾界線行時，保底還原整段原文，不做任何剝離。"""
        command = "cat <<'EOF'\nsome content without closing delimiter\n"
        assert strip_heredoc_bodies(command) == command

    def test_multiple_heredocs_both_stripped(self):
        command = "cat <<'A'\nfirst\nA\ncat <<'B'\nsecond\nB\n"
        result = strip_heredoc_bodies(command)
        assert "first" not in result
        assert "second" not in result


class TestNormalizeNewlinesToSeparators:
    def test_bare_newline_becomes_separator(self):
        result = normalize_newlines_to_separators("git add a\ngit commit -m x")
        assert "\n" not in result
        assert " ; " in result

    def test_newline_inside_single_quotes_preserved(self):
        result = normalize_newlines_to_separators("echo 'line1\nline2'")
        assert "\n" in result

    def test_newline_inside_double_quotes_preserved(self):
        result = normalize_newlines_to_separators('echo "line1\nline2"')
        assert "\n" in result


class TestIsLiteralPathspecToken:
    def test_dot_is_broad(self):
        assert is_literal_pathspec_token(".") is False

    def test_dot_slash_is_broad(self):
        assert is_literal_pathspec_token("./") is False

    def test_colon_slash_is_broad(self):
        assert is_literal_pathspec_token(":/") is False

    def test_glob_is_broad(self):
        assert is_literal_pathspec_token("src/*.py") is False
        assert is_literal_pathspec_token("file?.py") is False
        assert is_literal_pathspec_token("[abc].py") is False

    def test_trailing_slash_directory_is_broad(self):
        assert is_literal_pathspec_token("src/") is False

    def test_literal_file_path_is_not_broad(self):
        assert is_literal_pathspec_token("src/foo.py") is True
        assert is_literal_pathspec_token("README.md") is True


class TestIsShellRedirectionToken:
    def test_simple_redirect(self):
        assert is_shell_redirection_token(">") is True
        assert is_shell_redirection_token(">>") is True

    def test_fd_redirect(self):
        assert is_shell_redirection_token("2>&1") is True

    def test_literal_path_not_redirect(self):
        assert is_shell_redirection_token("src/foo.py") is False


class TestFindGitInvocationsFailureSemantics:
    def test_unbalanced_quote_returns_none(self):
        result = find_git_invocations('git commit -m "unterminated', {"commit"})
        assert result is None

    def test_no_match_returns_empty_list_not_none(self):
        result = find_git_invocations("pytest tests/ -q", {"commit"})
        assert result == []

    def test_empty_command_returns_empty_list(self):
        assert find_git_invocations("", {"commit"}) == []


class TestFindGitInvocationsBasic:
    def test_simple_commit(self):
        result = find_git_invocations('git commit -m "x"', {"commit"})
        assert len(result) == 1
        inv = result[0]
        assert inv.subcommand == "commit"
        assert inv.dash_c_path is None
        assert inv.args == ["-m", "x"]

    def test_dash_c_captured(self):
        result = find_git_invocations("git -C /repo commit -m x", {"commit"})
        assert len(result) == 1
        assert result[0].dash_c_path == "/repo"
        assert result[0].args == ["-m", "x"]

    def test_non_matching_subcommand_not_returned(self):
        result = find_git_invocations("git status", {"commit"})
        assert result == []

    def test_add_not_matched_when_only_commit_requested(self):
        result = find_git_invocations("git add foo.py", {"commit"})
        assert result == []


class TestFindGitInvocationsSubcommandAlias:
    def test_stage_alias_matches_add_request(self):
        result = find_git_invocations("git stage foo.py", {"add"})
        assert len(result) == 1
        assert result[0].subcommand == "add"

    def test_add_literal_also_matches(self):
        result = find_git_invocations("git add foo.py", {"add"})
        assert len(result) == 1
        assert result[0].subcommand == "add"


class TestFindGitInvocationsPrefixWrappers:
    def test_sudo_prefix_skipped(self):
        result = find_git_invocations("sudo git commit -m x", {"commit"})
        assert len(result) == 1
        assert result[0].subcommand == "commit"
        # statement 保留完整原文供訊息顯示
        assert result[0].statement[0] == "sudo"

    def test_nohup_prefix_skipped(self):
        result = find_git_invocations("nohup git commit -m x", {"commit"})
        assert len(result) == 1

    def test_time_prefix_skipped(self):
        result = find_git_invocations("time git commit -m x", {"commit"})
        assert len(result) == 1

    def test_xargs_prefix_skipped(self):
        result = find_git_invocations("xargs git commit -m x", {"commit"})
        assert len(result) == 1

    def test_env_with_assignments_skipped(self):
        result = find_git_invocations("env FOO=bar BAZ=qux git commit -m x", {"commit"})
        assert len(result) == 1

    def test_bare_env_assignment_skipped(self):
        result = find_git_invocations("FOO=bar git commit -m x", {"commit"})
        assert len(result) == 1


class TestFindGitInvocationsGlobalOptions:
    def test_dash_c_option_skipped(self):
        result = find_git_invocations('git -c user.name=x commit -m "y"', {"commit"})
        assert len(result) == 1
        assert result[0].args == ["-m", "y"]

    def test_git_dir_option_equals_form_skipped(self):
        """`--git-dir=<path>` 單一 token（含等號）形式亦須正確跳過。"""
        result = find_git_invocations("git --git-dir=/repo/.git commit -m x", {"commit"})
        assert len(result) == 1
        assert result[0].subcommand == "commit"
        assert result[0].args == ["-m", "x"]

    def test_git_dir_option_space_form_skipped(self):
        result = find_git_invocations("git --git-dir /repo/.git commit -m x", {"commit"})
        assert len(result) == 1
        assert result[0].args == ["-m", "x"]

    def test_no_pager_option_skipped(self):
        result = find_git_invocations("git --no-pager commit -m x", {"commit"})
        assert len(result) == 1
        assert result[0].args == ["-m", "x"]


class TestFindGitInvocationsMultiStatement:
    def test_and_and_separator(self):
        result = find_git_invocations("git add foo.py && git commit -m x", {"commit"})
        assert len(result) == 1
        assert result[0].args == ["-m", "x"]

    def test_semicolon_separator(self):
        result = find_git_invocations("git status; git commit -m x", {"commit"})
        assert len(result) == 1

    def test_both_add_and_commit_found_when_both_requested(self):
        result = find_git_invocations(
            "git add foo.py && git commit -m x", {"add", "commit"}
        )
        assert len(result) == 2
        subcommands = {inv.subcommand for inv in result}
        assert subcommands == {"add", "commit"}

    def test_subshell_parens_flattened(self):
        result = find_git_invocations("(cd /repo && git commit -m x)", {"commit"})
        assert len(result) == 1


class TestFindGitInvocationsPayloadNotMisdetected:
    def test_heredoc_body_mentioning_commit_not_matched(self):
        command = (
            'ticket track append-log X --section "Y" '
            '"$(cat <<\'EOF\'\n'
            "描述 git commit 相關文字\n"
            "EOF\n"
            ')")'
        )
        result = find_git_invocations(command, {"commit"})
        assert result == []

    def test_quoted_message_content_not_matched_as_separate_invocation(self):
        result = find_git_invocations(
            'some-cli --why "please avoid git commit here"', {"commit"}
        )
        assert result == []


def test_git_invocation_args_property():
    inv = GitInvocation(
        statement=["git", "commit", "-m", "x"],
        subcommand="commit",
        subcommand_index=1,
        dash_c_path=None,
    )
    assert inv.args == ["-m", "x"]


# ============================================================================
# 0.5.0-W1-120.7.1：包裝命令、巢狀 shell、別名、有效目錄
# ============================================================================

import shlex
import subprocess

import pytest

import lib.git_command_parse as gcp


def _subs(command, base_dir=None, wanted=("commit",)):
    result = find_git_invocations(command, set(wanted), base_dir=base_dir)
    assert result is not None
    return result


@pytest.mark.parametrize(
    "command",
    [
        "/usr/bin/git commit -m x",
        "command git commit -m x",
        "command -p git commit -m x",
        "exec git commit -m x",
        "bash -c 'git commit -m x'",
        "sh -c \"git commit -m x\"",
        "zsh -c 'git commit -m x'",
        "bash -lc 'git commit -m x'",
        "/bin/bash -c 'git commit -m x'",
        "eval 'git commit -m x'",
        "eval git commit -m x",
        "bash -c \"bash -c 'git commit -m x'\"",
        "sudo bash -c 'true && git commit -m x'",
    ],
)
def test_wrapped_commit_detected(command):
    invs = _subs(command)
    assert [i.subcommand for i in invs] == ["commit"]


@pytest.mark.parametrize(
    "command",
    [
        "echo git commit",
        "echo '/usr/bin/git commit'",
        "echo \"bash -c 'git commit'\"",
        "bash -c 'echo git commit'",
        "eval 'echo git commit'",
        "command -v git commit",
        "bash script.sh git commit",
        "printf '%s' 'eval git commit'",
    ],
)
def test_text_mentioning_commit_not_detected(command):
    assert _subs(command) == []


def test_nesting_depth_is_bounded():
    cmd = "git commit -m x"
    for _ in range(8):
        cmd = "bash -c " + shlex.quote(cmd)
    assert find_git_invocations(cmd, {"commit"}) is None  # 超過深度上限：與頂層無法解析同形


class TestEffectiveDir:
    def test_defaults_when_nothing_changes(self):
        inv = _subs("git commit -m x")[0]
        assert (inv.effective_dir, inv.dir_unknown, inv.dash_c_paths) == (None, False, ())

    def test_base_dir_returned_when_nothing_changes(self):
        assert _subs("git commit", base_dir="/base")[0].effective_dir == "/base"

    def test_dash_c_chain_joins_relative_paths(self):
        inv = _subs("git -C a -C b commit")[0]
        assert inv.dash_c_path == "a"
        assert inv.dash_c_paths == ("a", "b")
        assert inv.effective_dir == "a/b"

    def test_absolute_dash_c_replaces(self):
        assert _subs("git -C a -C /x commit")[0].effective_dir == "/x"

    def test_cd_then_git(self):
        assert _subs("cd /repo && git commit")[0].effective_dir == "/repo"

    def test_cd_relative_to_base(self):
        inv = _subs("cd sub && git -C inner commit", base_dir="/base")[0]
        assert inv.effective_dir == "/base/sub/inner"

    def test_cd_in_subshell_does_not_leak(self):
        inv = _subs("(cd /other && git status); git commit", base_dir="/base")[0]
        assert inv.effective_dir == "/base"

    def test_cd_inside_subshell_applies_within(self):
        assert _subs("(cd /other && git commit)")[0].effective_dir == "/other"

    def test_cd_in_pipeline_does_not_leak(self):
        assert _subs("cd /other | cat; git commit", base_dir="/base")[0].effective_dir == "/base"

    def test_cd_inside_bash_c_does_not_leak(self):
        inv = _subs("bash -c 'cd /other'; git commit", base_dir="/base")[0]
        assert inv.effective_dir == "/base"

    def test_cd_inside_bash_c_applies_within(self):
        assert _subs("bash -c 'cd /other && git commit'")[0].effective_dir == "/other"

    @pytest.mark.parametrize(
        "command",
        [
            "cd $X && git commit",
            "cd `pwd`/x && git commit",
            "git -C $DIR commit",
            "cd - && git commit",
            "cd && git commit",
            "cd /a || git commit",
            "false || cd /a; git commit",
            "popd; git commit",
        ],
    )
    def test_dynamic_directory_marks_unknown(self, command):
        inv = _subs(command)[0]
        assert inv.dir_unknown is True
        assert inv.effective_dir is None

    def test_echo_cd_does_not_change_dir(self):
        assert _subs("echo cd /other; git commit", base_dir="/base")[0].effective_dir == "/base"


class TestAliasExpansion:
    def _patch(self, monkeypatch, table):
        calls = []

        def fake(directory, name):
            calls.append((directory, name))
            return table.get(name)

        monkeypatch.setattr(gcp, "_read_git_alias", fake)
        return calls

    def test_simple_alias_hits(self, monkeypatch):
        self._patch(monkeypatch, {"ci": "commit"})
        inv = _subs("git ci -m x")[0]
        assert inv.subcommand == "commit"
        assert inv.args == ["-m", "x"]

    def test_alias_with_default_flags_visible_in_args(self, monkeypatch):
        self._patch(monkeypatch, {"ci": "commit -a"})
        assert "-a" in _subs("git ci -m x")[0].args

    def test_alias_chain(self, monkeypatch):
        self._patch(monkeypatch, {"ci": "co2", "co2": "commit"})
        assert len(_subs("git ci")) == 1

    def test_alias_loop_terminates(self, monkeypatch):
        self._patch(monkeypatch, {"a": "b", "b": "a"})
        assert find_git_invocations("git a", {"commit"}) is None

    def test_alias_lookup_uses_effective_dir(self, monkeypatch):
        calls = self._patch(monkeypatch, {"ci": "commit"})
        _subs("cd /repo && git ci", base_dir="/base")
        assert calls[0] == ("/repo", "ci")

    def test_unrelated_alias_not_hit(self, monkeypatch):
        self._patch(monkeypatch, {"st": "status"})
        assert _subs("git st") == []

    def test_builtin_never_looked_up(self, monkeypatch):
        calls = self._patch(monkeypatch, {})
        _subs("git status")
        assert calls == []

    def test_shell_alias_hit_is_marked_unknown(self, monkeypatch):
        self._patch(monkeypatch, {"go": "!git commit -m x"})
        inv = _subs("git go")[0]
        assert (inv.dir_unknown, inv.effective_dir) == (True, None)

    def test_shell_alias_without_git_commit_not_hit(self, monkeypatch):
        self._patch(monkeypatch, {"go": "!echo hi"})
        assert _subs("git go") == []

    def test_alias_read_failure_does_not_raise(self, monkeypatch):
        def boom(*args, **kwargs):
            raise OSError("no git")

        monkeypatch.setattr(gcp.subprocess, "run", boom)
        assert _subs("git ci -m x") == []

    def test_real_git_config_alias(self, tmp_path):
        subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
        subprocess.run(["git", "-C", str(tmp_path), "config", "alias.ci", "commit"], check=True)
        invs = _subs(f"git -C {tmp_path} ci -m x")
        assert [i.subcommand for i in invs] == ["commit"]
        assert invs[0].effective_dir == str(tmp_path)

    def test_mutation_without_alias_expansion_misses(self, monkeypatch):
        """變異確認：別名讀取永遠回 None 時，正向對照輸入必須變為漏判。"""
        self._patch(monkeypatch, {})
        assert _subs("git ci -m x") == []


def test_mutation_without_nested_script_support_misses(monkeypatch):
    """變異確認：停用巢狀 shell 解析時，bash -c 正向對照輸入必須漏判。"""
    monkeypatch.setattr(gcp, "_nested_script", lambda statement, idx: None)
    assert _subs("bash -c 'git commit -m x'") == []
    assert _subs("git commit -m x") != []


class TestUnparseableIsNone:
    """0.5.0-W1-120.7.1 審查修正：巢狀與別名的無法解析一律回 None（同頂層 tokenize 失敗）。"""

    def test_nested_tokenize_failure_is_none(self):
        assert find_git_invocations("bash -c \"git commit -m 'x\"", {"commit"}) is None

    def test_nested_ok_control_is_list(self):
        assert find_git_invocations("bash -c \"git commit -m 'x'\"", {"commit"}) is not None

    def test_alias_lookup_cap_is_none(self, monkeypatch):
        monkeypatch.setattr(gcp, "_read_git_alias", lambda d, n: None)
        many = "; ".join(f"git zz{i} x" for i in range(gcp._MAX_ALIAS_LOOKUPS + 1))
        assert find_git_invocations(many, {"commit"}) is None

    def test_alias_lookup_under_cap_is_list(self, monkeypatch):
        monkeypatch.setattr(gcp, "_read_git_alias", lambda d, n: None)
        few = "; ".join(f"git zz{i} x" for i in range(gcp._MAX_ALIAS_LOOKUPS))
        assert find_git_invocations(few, {"commit"}) == []

    def test_alias_lookup_is_cached(self, monkeypatch):
        calls = []
        monkeypatch.setattr(gcp, "_read_git_alias", lambda d, n: calls.append(n))
        same = "; ".join("git zz x" for _ in range(30))
        assert find_git_invocations(same, {"commit"}) == []
        assert len(calls) == 1

    def test_alias_total_time_budget_is_none(self, monkeypatch):
        monkeypatch.setattr(gcp, "_read_git_alias", lambda d, n: None)
        clock = iter(range(0, 1000, 5))
        monkeypatch.setattr(gcp.time, "monotonic", lambda: next(clock))
        assert find_git_invocations("git aa x; git bb x", {"commit"}) is None

    def test_alias_timeout_is_none(self, monkeypatch):
        def slow(*args, **kwargs):
            raise subprocess.TimeoutExpired("git", 1)

        monkeypatch.setattr(gcp.subprocess, "run", slow)
        assert find_git_invocations("git ci -m x", {"commit"}) is None

    def test_mutation_without_cap_returns_list(self, monkeypatch):
        """變異確認：上限放寬後，超限輸入不再回 None（證明測試鑑別力）。"""
        monkeypatch.setattr(gcp, "_read_git_alias", lambda d, n: None)
        monkeypatch.setattr(gcp, "_MAX_ALIAS_LOOKUPS", 1000)
        many = "; ".join(f"git zz{i} x" for i in range(9))
        assert find_git_invocations(many, {"commit"}) == []

    def test_mutation_nested_failure_swallowed_returns_list(self, monkeypatch):
        """變異確認：舊行為（巢狀失敗回空）會使上面的 None 斷言翻紅。"""
        original = gcp._scan_script

        def swallowing(script, state, depth, ctx):
            try:
                return original(script, state, depth, ctx)
            except gcp._Unparseable:
                return []

        monkeypatch.setattr(gcp, "_scan_script", swallowing)
        assert find_git_invocations("bash -c \"git commit -m 'x\"", {"commit"}) == []
