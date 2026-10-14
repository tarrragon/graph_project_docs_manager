#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///

"""
測試前環境檢查 Hook (PreToolUse)

功能:
  在執行 flutter test 前檢查開發環境就緒狀態:
  1. Flutter SDK 可用性
  2. pubspec.lock 存在（依賴已安裝）
  3. .dart_tool/package_config.json 存在（pub get 已執行）

觸發時機: PreToolUse (Bash: flutter test, mcp__dart__run_tests)

輸出:
  環境就緒: allow，附帶確認訊息
  環境異常: allow + stderr 警告（不阻止，但提醒問題）

HOOK_METADATA (JSON):
{
  "event_type": "PreToolUse",
  "matcher": "Bash",
  "description": "測試前環境檢查 - 確保 Flutter SDK 和依賴完整",
  "dependencies": [],
  "version": "1.0.0"
}
"""

import re
import shlex
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).parent.parent))
from lib import setup_hook_logging, run_hook_safely, get_project_root, read_json_from_stdin, emit_hook_output
from lib.hook_messages import ValidationMessages


# 測試命令判定（2026-10-14 改寫）
#
# 只認「敘述開頭」的測試指令。舊判定以子字串比對整段命令文字，grep 的
# pattern、建票命令的參數只要含測試指令字樣就被當成測試執行；對原始字串
# 做 regex 也不夠，引號內的 `\|flutter test` 會被看成管線後的新敘述。
# 因此先依 POSIX 引號規則切 token，引號內文字整段成為單一參數，
# 再只檢查每個敘述的開頭。
STATEMENT_SEPARATOR_CHARS = ";&|()\n"
ENV_ASSIGNMENT_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
TIMEOUT_WRAPPER_NAME = "run-with-timeout.py"
VERSION_MANAGER_PREFIXES = frozenset({"fvm"})
TEST_RUNNER_HEADS = frozenset({("flutter", "test"), ("dart", "test")})


def _split_statements(command: str) -> list[list[str]]:
    """依引號規則切 token，再以分隔符（; & | ( ) 換行）切成各敘述的 token 列。"""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=STATEMENT_SEPARATOR_CHARS)
    lexer.whitespace = " \t\r"  # 換行改作分隔符，不當空白
    lexer.whitespace_split = True
    statements: list[list[str]] = [[]]
    for token in lexer:
        if set(token) <= set(STATEMENT_SEPARATOR_CHARS):
            statements.append([])
        else:
            statements[-1].append(token)
    return [tokens for tokens in statements if tokens]


def _unwrap_timeout_wrapper(tokens: list[str]) -> list[str]:
    """`... run-with-timeout.py <秒數> -- <命令>` 取出被包裝的命令。

    包裝器前可為任意啟動方式（`python3 -I`、`uv run python3` 等），故在整個
    敘述內找包裝器，而非逐 token 比對直譯器白名單。
    """
    for index, token in enumerate(tokens):
        if Path(token).name == TIMEOUT_WRAPPER_NAME:
            rest = tokens[index + 1:]
            return rest[rest.index("--") + 1:] if "--" in rest else []
    return tokens


def _strip_launch_prefixes(tokens: list[str]) -> list[str]:
    """去除環境變數前綴、逾時包裝與版本管理器前綴，留下實際執行的命令。

    不支援的前綴形態（判為非測試命令，只少做一次環境檢查）：`timeout N`、
    `env A=1`、`bash -c '...'`。
    """
    while tokens and ENV_ASSIGNMENT_PATTERN.match(tokens[0]):
        tokens = tokens[1:]
    tokens = _unwrap_timeout_wrapper(tokens)
    while tokens and tokens[0] in VERSION_MANAGER_PREFIXES:
        tokens = tokens[1:]
    return tokens


def is_test_command(tool_name: str, tool_input: dict) -> bool:
    """判斷是否為測試命令：任一敘述去除啟動前綴後以測試指令開頭。"""
    if tool_name != "Bash":
        return tool_name == "mcp__dart__run_tests"
    command = tool_input.get("command", "")
    try:
        statements = _split_statements(command)
    except ValueError:
        # 解析失敗即略過：本 hook 為提示型檢查，漏判一次只少做環境檢查、不擋命令
        return False
    return any(
        tuple(_strip_launch_prefixes(tokens)[:2]) in TEST_RUNNER_HEADS
        for tokens in statements
    )


def check_flutter_sdk() -> tuple[bool, str]:
    """檢查 Flutter SDK 可用性。"""
    try:
        result = subprocess.run(
            ["flutter", "--version", "--machine"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
        if result.returncode == 0:
            return True, ValidationMessages.PRE_TEST_SDK_OK
        return False, ValidationMessages.PRE_TEST_SDK_ERROR
    except FileNotFoundError:
        return False, ValidationMessages.PRE_TEST_SDK_NOT_FOUND
    except subprocess.TimeoutExpired:
        return False, ValidationMessages.PRE_TEST_SDK_TIMEOUT


# git checkout 等操作會在同一次寫入批次中依序落盤 pubspec.yaml 與
# pubspec.lock，兩者 mtime 因此可能存在毫秒級的寫入順序差（實測本專案
# 為 0.34 毫秒），此差距與依賴是否過期無關。使用者實際編輯 pubspec.yaml
# 後才執行 flutter pub get 更新 lock，兩檔 mtime 差距通常以秒計；1 秒
# 容差足以濾除檔案系統寫入順序雜訊，同時不影響真正過期案例的偵測。
PUBSPEC_MTIME_TOLERANCE_SECONDS = 1.0


def check_dependencies(project_dir: Path) -> list[str]:
    """檢查依賴是否已安裝。"""
    warnings = []

    pubspec_lock = project_dir / "pubspec.lock"
    if not pubspec_lock.exists():
        warnings.append(ValidationMessages.PRE_TEST_PUBSPEC_LOCK_MISSING)
        return warnings

    package_config = project_dir / ".dart_tool" / "package_config.json"
    if not package_config.exists():
        warnings.append(ValidationMessages.PRE_TEST_PACKAGE_CONFIG_MISSING)
        return warnings

    # 檢查 pubspec.yaml 是否比 pubspec.lock 更新（容差外才視為過期）
    pubspec_yaml = project_dir / "pubspec.yaml"
    if pubspec_yaml.exists() and pubspec_lock.exists():
        yaml_mtime = pubspec_yaml.stat().st_mtime
        lock_mtime = pubspec_lock.stat().st_mtime
        if yaml_mtime - lock_mtime > PUBSPEC_MTIME_TOLERANCE_SECONDS:
            warnings.append(ValidationMessages.PRE_TEST_PUBSPEC_OUTDATED)

    return warnings


def main():
    logger = setup_hook_logging("pre-test-hook")
    input_data = read_json_from_stdin(logger)
    if input_data is None:
        return 0

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    if not is_test_command(tool_name, tool_input):
        return 0

    project_dir = get_project_root()
    issues = []

    # 1. 檢查 Flutter SDK
    sdk_ok, sdk_msg = check_flutter_sdk()
    if not sdk_ok:
        issues.append(f"[ERROR] {sdk_msg}")

    # 2. 檢查依賴
    dep_warnings = check_dependencies(project_dir)
    for warning in dep_warnings:
        issues.append(f"[WARNING] {warning}")

    # 輸出結果：emit_hook_output 統一出口（合併警告和 permissionDecision）
    decision_reason = (
        f"{ValidationMessages.PRE_TEST_ENV_CHECK_PREFIX}{len(issues)}{ValidationMessages.PRE_TEST_ENV_CHECK_SUFFIX}"
        if issues else ValidationMessages.PRE_TEST_ENV_READY
    )
    additional_context = None
    if issues:
        warning_text = "\n".join(issues)
        additional_context = f"{ValidationMessages.PRE_TEST_CHECK_HEADER}\n{warning_text}"

    # 環境警告為 PM-only（subagent 觸發時過濾訊息，allow 決策不受影響）
    emit_hook_output(
        "PreToolUse",
        additional_context=additional_context,
        permission_decision="allow",
        permission_decision_reason=decision_reason,
        audience="pm_only",
        input_data=input_data,
    )
    return 0


if __name__ == "__main__":
    sys.exit(run_hook_safely(main, "pre-test-hook"))
