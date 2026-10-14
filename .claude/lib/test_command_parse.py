#!/usr/bin/env python3
"""
測試命令解析共用工具

提供 Bash hook 共用的「什麼算一次測試執行」定義。pre-test-hook、
test-timeout-pre、post-test-hook 原各自判定（子字串、對原始字串做 regex），
引號內的 `\\|flutter test` 會被當成管線後的新敘述，包裝腳本的 `--` 不被
認得，pytest 也不被涵蓋。本模組把判定收斂為單一定義：沿用
git_command_parse.parse_command_statements 的切分（heredoc 剝離、換行轉
分隔符、引號語意），只檢查每個敘述去除啟動前綴後的開頭。

主要功能:
- find_test_invocations: 解析命令字串，回傳各測試呼叫（含 runner 種類）
- TestInvocation: 單次測試呼叫的結構化記錄

失敗語意（與 git_command_parse 一致，呼叫端須用 `is None` 區分）：
- `None`：命令字串無法安全解析（未閉合引號）
- `[]`：可解析但沒有測試呼叫

支援的啟動前綴：env／KEY=VAL／sudo／nohup／time／xargs、timeout、fvm、
`uv [選項] run`、`[python] run-with-timeout.py N -- <命令>`（可巢狀）。
不支援：`bash -c '...'`（命令位於引號字串內，需二次解析）。
"""

import re
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

from .git_command_parse import _skip_prefix_wrapper_count, parse_command_statements

RUNNER_FLUTTER = "flutter"
RUNNER_DART = "dart"
RUNNER_NPM = "npm"
RUNNER_PYTEST = "pytest"
ALL_RUNNERS = frozenset({RUNNER_FLUTTER, RUNNER_DART, RUNNER_NPM, RUNNER_PYTEST})

TIMEOUT_WRAPPER_NAME = "run-with-timeout.py"
PYTEST_EXECUTABLES = frozenset({"pytest", "py.test"})
_PYTHON_EXECUTABLE_RE = re.compile(r"^python(\d+(\.\d+)?)?$")
_TIMEOUT_OPTIONS_WITH_VALUE = frozenset({"-s", "--signal", "-k", "--kill-after"})
_UV_OPTIONS_WITH_VALUE = frozenset({
    "--directory", "--project", "--python", "-p", "--with", "-w",
    "--with-editable", "--with-requirements", "--env-file", "--group",
    "--extra", "--package", "--index", "--index-url", "--extra-index-url",
    "--cache-dir", "--config-file",
})


@dataclass(frozen=True)
class TestInvocation:
    """單次測試呼叫：runner 為執行器種類，statement 保留含啟動前綴的完整敘述。"""

    __test__ = False  # 避免 pytest 把 Test 開頭的類別當測試收集
    runner: str
    statement: Tuple[str, ...]


def _skip_options(tokens: List[str], with_value) -> List[str]:
    index = 0
    while index < len(tokens) and tokens[index].startswith("-"):
        index += 2 if tokens[index] in with_value else 1
    return tokens[index:]


def _strip_timeout(tokens: List[str]) -> List[str]:
    """timeout [選項] <時長> <命令>"""
    return _skip_options(tokens[1:], _TIMEOUT_OPTIONS_WITH_VALUE)[1:]


def _strip_uv_run(tokens: List[str]) -> List[str]:
    """uv [全域選項] run [run 選項] <命令>；非 uv run 回 []。"""
    rest = _skip_options(tokens[1:], _UV_OPTIONS_WITH_VALUE)
    if not rest or rest[0] != "run":
        return []
    return _skip_options(rest[1:], _UV_OPTIONS_WITH_VALUE)


def _strip_timeout_wrapper(tokens: List[str]) -> Optional[List[str]]:
    """[直譯器 [旗標]] run-with-timeout.py N -- <命令>；不是包裝呼叫回 None。"""
    index = 0
    if _PYTHON_EXECUTABLE_RE.match(Path(tokens[0]).name):
        index = 1
        while index < len(tokens) and tokens[index].startswith("-"):
            index += 1
    if index >= len(tokens) or Path(tokens[index]).name != TIMEOUT_WRAPPER_NAME:
        return None
    rest = tokens[index + 1:]
    return rest[rest.index("--") + 1:] if "--" in rest else []


def _strip_one_launcher(tokens: List[str]) -> List[str]:
    skipped = _skip_prefix_wrapper_count(tokens)  # env／KEY=VAL／sudo／nohup／time／xargs
    if skipped:
        return tokens[skipped:]
    head = tokens[0]
    if head == "timeout":
        return _strip_timeout(tokens)
    if head == "fvm":
        return tokens[1:]
    if head == "uv":
        return _strip_uv_run(tokens)
    unwrapped = _strip_timeout_wrapper(tokens)
    return tokens if unwrapped is None else unwrapped


def _strip_launch_prefixes(tokens: List[str]) -> List[str]:
    """前綴可巢狀（包裝腳本內再接 uv run），反覆去除至穩定。"""
    while tokens:
        stripped = _strip_one_launcher(tokens)
        if stripped == tokens:
            return tokens
        tokens = stripped
    return tokens


def _is_python_module_pytest(tokens: List[str]) -> bool:
    """python [旗標] -m pytest"""
    if not _PYTHON_EXECUTABLE_RE.match(Path(tokens[0]).name):
        return False
    rest = tokens[1:]
    while rest and rest[0].startswith("-") and rest[0] != "-m":
        rest = rest[1:]
    return len(rest) >= 2 and rest[0] == "-m" and rest[1] == "pytest"


def _is_npm_test(tokens: List[str]) -> bool:
    """npm test[:x] / npm run test[:x]"""
    if len(tokens) > 2 and tokens[1] == "run":
        script = tokens[2]
    else:
        script = tokens[1] if len(tokens) > 1 else ""
    return script == "test" or script.startswith("test:")


def _classify_runner(tokens: List[str]) -> Optional[str]:
    if not tokens:
        return None
    head = Path(tokens[0]).name
    if head in (RUNNER_FLUTTER, RUNNER_DART):
        return head if len(tokens) > 1 and tokens[1] == "test" else None
    if head == RUNNER_NPM:
        return RUNNER_NPM if _is_npm_test(tokens) else None
    if head in PYTEST_EXECUTABLES or _is_python_module_pytest(tokens):
        return RUNNER_PYTEST
    return None


def find_test_invocations(command: str) -> Optional[List[TestInvocation]]:
    """解析命令字串，回傳其中的測試呼叫；無法解析回 None，無命中回 []。"""
    statements = parse_command_statements(command)
    if statements is None:
        return None
    invocations = []
    for statement in statements:
        runner = _classify_runner(_strip_launch_prefixes(statement))
        if runner is not None:
            invocations.append(TestInvocation(runner=runner, statement=tuple(statement)))
    return invocations
