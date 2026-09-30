"""ticket create 的 --blocked-by / --related-to 可重複給且相容逗號分隔。

E1 對照：同批輸入，重複旗標與逗號寫法須得到相同結果；
修正前重複旗標因 argparse 預設覆寫，只剩最後一個值。
"""

import argparse

import pytest

from ticket_system.commands.create import expand_list_arg, register


def _parse(argv):
    root = argparse.ArgumentParser()
    register(root.add_subparsers(dest="command"))
    return root.parse_args(["create", "--action", "實作", "--target", "x", *argv])


@pytest.mark.parametrize("flag,attr", [
    ("--blocked-by", "blocked_by"),
    ("--related-to", "related_to"),
    ("--where", "where_files"),
])
class TestRepeatedListArgs:
    def test_repeated_flag_keeps_all_values(self, flag, attr):
        args = _parse([flag, "A", flag, "B"])
        assert expand_list_arg(getattr(args, attr)) == ["A", "B"]

    def test_comma_form_unchanged(self, flag, attr):
        args = _parse([flag, "A,B"])
        assert expand_list_arg(getattr(args, attr)) == ["A", "B"]

    def test_repeated_equals_comma(self, flag, attr):
        repeated = expand_list_arg(getattr(_parse([flag, "A", flag, "B"]), attr))
        comma = expand_list_arg(getattr(_parse([flag, "A,B"]), attr))
        assert repeated == comma

    def test_mixed_ordered_and_deduped(self, flag, attr):
        args = _parse([flag, "A,B", flag, "C", flag, " B , D"])
        assert expand_list_arg(getattr(args, attr)) == ["A", "B", "C", "D"]

    def test_absent_is_empty(self, flag, attr):
        assert expand_list_arg(getattr(_parse([]), attr)) == []


def test_expand_accepts_legacy_string():
    assert expand_list_arg("A, B,,A") == ["A", "B"]
