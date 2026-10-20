"""0.5.0-W1-400.2：各測試根之間 test_*.py 檔名不得重複（conftest.py 豁免）。

同名檔技術上可並存（模組名不同，不會撞名），但改某模組的行為或字面時，
找到一份就誤以為已改過另一份（0.5.0-W1-384 閘門紅燈同型），故以守衛擋住新建同名檔。
"""

import tomllib
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent


def find_duplicate_test_basenames(roots: list[Path]) -> set[str]:
    """回傳出現在兩個以上根目錄的 test_*.py 檔名集合。"""
    seen: dict[str, int] = {}
    for root in roots:
        for name in {p.name for p in root.rglob("test_*.py")}:
            seen[name] = seen.get(name, 0) + 1
    return {name for name, count in seen.items() if count > 1}


def _configured_roots() -> list[Path]:
    with (SKILL_ROOT / "pyproject.toml").open("rb") as f:
        testpaths = tomllib.load(f)["tool"]["pytest"]["ini_options"]["testpaths"]
    return [SKILL_ROOT / p for p in testpaths]


def test_configured_test_roots_have_no_duplicate_basenames():
    assert find_duplicate_test_basenames(_configured_roots()) == set()


def test_same_basename_in_two_roots_is_reported(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    a.mkdir()
    b.mkdir()
    (a / "test_x.py").write_text("")
    (b / "test_x.py").write_text("")
    (b / "test_only_b.py").write_text("")
    assert find_duplicate_test_basenames([a, b]) == {"test_x.py"}


def test_same_conftest_in_two_roots_is_exempt(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    a.mkdir()
    b.mkdir()
    (a / "conftest.py").write_text("")
    (b / "conftest.py").write_text("")
    assert find_duplicate_test_basenames([a, b]) == set()
