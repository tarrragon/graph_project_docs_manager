#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""
Hook 分派程序 (PreToolUse / PostToolUse 共用)

功能:
  同一事件與 matcher 下的多支 hook 合併成單一程序執行，消去每支 hook 重複支付的
  直譯器啟動、lib 匯入與 git rev-parse 固定成本（實測占單支 CPU 八成以上）。

用法:
  hook-dispatcher.py --group PreToolUse:Bash
  清單在 .claude/hooks/hook-dispatch-registry.json；新增 hook 在對應 group 加一項即可。

入口形式:
  以 runpy.run_path(run_name="__main__") 在同程序執行 hook 原檔，hook 自己的
  `__main__` 區塊照常執行（run_hook_safely、fail_closed、liveness 全保留），
  hook 檔案不需改寫，單獨執行入口也保留。

隔離:
  每支 hook 有自己的 stdin / stdout / stderr 緩衝、獨立逾時（setitimer），
  結束後還原 argv / sys.path / environ / cwd；單支例外或逾時不影響其他支。

合併規則:
  - exit code: 任一支 2 -> 2；否則任一支非 0 -> 1；否則 0
  - permissionDecision: deny > ask > allow；單一來源時 reason 原樣傳出，
    多來源以 `[hook名] ` 前綴逐行相接
  - additionalContext / systemMessage: 各 hook 自帶標籤，不加前綴，空行相接
  - stderr: 逐支加 `[hook名] ` 前綴；整體 exit 2 時 JSON 的 deny/ask reason 一併併入 stderr
    （CC 對 exit 2 只讀 stderr）

失敗語意:
  - 單支例外 / 逾時: fail-open 但可見（stderr 前綴 + 日誌），fail_closed 的守衛
    由其自身 run_hook_safely(fail_closed=True) 在 hook 內回 2
  - 分派機制自身失敗: 該支退回以子程序執行（與原註冊等價），守衛不消失
  - registry 讀不到: exit 1 並寫 stderr（fail-open 可見，fail-closed 會鎖死修復用 Bash）

逾時推算:
  每支上限 = min(registry timeout（缺省 30 秒）, 群組剩餘預算)；
  群組預算（budget）= 實際執行上限，settings.json 逾時 = budget + 餘裕。
  任一支卡住時最久等到該支上限，整體不超過 budget。

HOOK_METADATA (JSON):
{
  "event_type": "PreToolUse,PostToolUse",
  "matcher": "Bash",
  "description": "Bash 事件 hook 單一分派程序",
  "dependencies": ["pyyaml"],
  "version": "1.0.0"
}
"""

import importlib
import json
import os
import runpy
import signal
import subprocess
import sys
import time
from io import StringIO
from pathlib import Path
from typing import Callable, Dict, List, Optional

HOOKS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = HOOKS_DIR.parent.parent
REGISTRY_PATH = HOOKS_DIR / "hook-dispatch-registry.json"
DEFAULT_HOOK_TIMEOUT = 30
DEFAULT_GROUP_BUDGET = 120
DECISION_RANK = {"deny": 3, "block": 3, "ask": 2, "allow": 1}
DENY_LEVELS = ("deny", "block", "ask")
EXIT_BLOCK = 2
EXIT_ERROR = 1


class HookTimeout(BaseException):
    """單支 hook 逾時（BaseException，避免被 hook 內的 except Exception 吞掉）"""


class HookResult:
    def __init__(self, name: str, code: int, stdout: str = "", stderr: str = "", error: str = ""):
        self.name = name
        self.code = code
        self.stdout = stdout
        self.stderr = stderr
        self.error = error


def hook_name_of(path: str) -> str:
    return Path(path).stem


def load_group(group: str, registry_path: Path = REGISTRY_PATH) -> dict:
    with open(str(registry_path), encoding="utf-8") as f:
        data = json.load(f)
    return data["groups"][group]


def _alarm_handler(signum, frame):
    raise HookTimeout()


def _snapshot():
    return (list(sys.argv), list(sys.path), dict(os.environ), os.getcwd())


def _restore(snap) -> None:
    argv, path, env, cwd = snap
    sys.argv[:] = argv
    sys.path[:] = path
    if dict(os.environ) != env:
        os.environ.clear()
        os.environ.update(env)
    if os.getcwd() != cwd:
        os.chdir(cwd)


def run_inprocess(path: Path, payload: str, timeout: float) -> HookResult:
    """在同程序以 __main__ 身分執行 hook 原檔，回傳其 exit code 與輸出"""
    name = hook_name_of(str(path))
    out, err = StringIO(), StringIO()
    old = (sys.stdin, sys.stdout, sys.stderr)
    snap = _snapshot()
    code = 0
    error = ""
    sys.stdin, sys.stdout, sys.stderr = StringIO(payload), out, err
    old_handler = None
    try:
        try:
            old_handler = signal.signal(signal.SIGALRM, _alarm_handler)
            signal.setitimer(signal.ITIMER_REAL, max(timeout, 0.001))
        except ValueError:
            old_handler = None  # 非主執行緒無法設 SIGALRM：略過逾時保護
        try:
            runpy.run_path(str(path), run_name="__main__")
        except SystemExit as e:
            code = _exit_code(e.code)
        except HookTimeout:
            code, error = EXIT_ERROR, "逾時（{}s）被分派器終止".format(timeout)
        except Exception as e:  # 單支例外隔離：記錄並回報，不影響其他支
            code, error = EXIT_ERROR, "{}: {}".format(type(e).__name__, e)
        finally:
            if old_handler is not None:
                signal.setitimer(signal.ITIMER_REAL, 0)
                signal.signal(signal.SIGALRM, old_handler)
    finally:
        sys.stdin, sys.stdout, sys.stderr = old
        _restore(snap)
    return HookResult(name, code, out.getvalue(), err.getvalue(), error)


def _exit_code(code) -> int:
    if code is None:
        return 0
    if isinstance(code, int):
        return code
    return EXIT_ERROR  # sys.exit("訊息") 在 CPython 為 exit 1


def run_subprocess(path: Path, payload: str, timeout: float) -> HookResult:
    """退回路徑：以子程序執行 hook（與原本由 CC 啟動等價）"""
    name = hook_name_of(str(path))
    try:
        p = subprocess.run(
            [sys.executable, str(path)], input=payload, capture_output=True,
            text=True, timeout=timeout, cwd=os.getcwd(),
        )
        return HookResult(name, p.returncode, p.stdout, p.stderr)
    except subprocess.TimeoutExpired:
        return HookResult(name, EXIT_ERROR, error="逾時（{}s）子程序被終止".format(timeout))


def _parse_json_object(text: str) -> Optional[dict]:
    text = text.strip()
    if not text.startswith("{"):
        return None
    try:
        obj = json.loads(text)
    except ValueError:
        return None
    return obj if isinstance(obj, dict) else None


def _prefixed(name: str, text: str) -> str:
    return "\n".join("[{}] {}".format(name, ln) for ln in text.strip().splitlines())


def _collect_decisions(parsed: List[tuple]) -> List[tuple]:
    """回傳 (rank, level, name, reason)；涵蓋 hookSpecificOutput 與頂層 decision"""
    found = []
    for name, obj in parsed:
        hso = obj.get("hookSpecificOutput")
        if isinstance(hso, dict) and hso.get("permissionDecision"):
            level = str(hso["permissionDecision"])
            found.append((DECISION_RANK.get(level, 1), level, name,
                          str(hso.get("permissionDecisionReason", ""))))
        if obj.get("decision") in DENY_LEVELS:
            found.append((DECISION_RANK[obj["decision"]], obj["decision"], name,
                          str(obj.get("reason", ""))))
    return found


def merge_results(results: List[HookResult]) -> tuple:
    """合併各支結果 -> (exit_code, stdout, stderr)"""
    codes = [r.code for r in results]
    final = EXIT_BLOCK if EXIT_BLOCK in codes else (EXIT_ERROR if any(codes) else 0)

    parsed, raw_out, contexts, sysmsgs = [], [], [], []
    event_name = ""
    for r in results:
        if not r.stdout.strip():
            continue
        obj = _parse_json_object(r.stdout)
        if obj is None:
            raw_out.append(_prefixed(r.name, r.stdout))
            continue
        parsed.append((r.name, obj))
        hso = obj.get("hookSpecificOutput")
        if isinstance(hso, dict):
            event_name = event_name or str(hso.get("hookEventName", ""))
            if hso.get("additionalContext"):
                contexts.append(str(hso["additionalContext"]))
        if obj.get("systemMessage"):
            sysmsgs.append(str(obj["systemMessage"]))

    decisions = _collect_decisions(parsed)
    top = max((d[0] for d in decisions), default=0)
    strongest = [d for d in decisions if d[0] == top] if decisions else []

    stderr_parts = []
    for r in results:
        if r.stderr.strip():
            stderr_parts.append(_prefixed(r.name, r.stderr))
        if r.error:
            stderr_parts.append("[{}] 分派器: {}".format(r.name, r.error))
    if final == EXIT_BLOCK:
        for _, level, name, reason in strongest:
            if level in DENY_LEVELS and reason:
                stderr_parts.append(_prefixed(name, reason))

    out_obj: Dict[str, object] = {}
    if parsed:
        hso_out: Dict[str, object] = {"hookEventName": event_name}
        if strongest:
            level = strongest[0][1]
            hso_out["permissionDecision"] = level
            reasons = [d for d in strongest if d[3]]
            if len(strongest) == 1:
                hso_out["permissionDecisionReason"] = strongest[0][3]
            elif reasons:
                hso_out["permissionDecisionReason"] = "\n".join(
                    _prefixed(d[2], d[3]) for d in reasons)
        if contexts or raw_out:
            hso_out["additionalContext"] = "\n\n".join(contexts + raw_out)
        out_obj["hookSpecificOutput"] = hso_out
        if sysmsgs:
            out_obj["systemMessage"] = "\n\n".join(sysmsgs)
        stdout = json.dumps(out_obj, ensure_ascii=False)
    else:
        stdout = "\n".join(raw_out)
    return final, stdout, "\n".join(stderr_parts)


def dispatch(entries: List[dict], payload: str, root: Path, budget: float,
             logger=None, inprocess: bool = True,
             clock: Callable[[], float] = time.monotonic) -> List[HookResult]:
    """依序執行 entries；每支上限 = min(自身 timeout, 剩餘預算)"""
    results = []
    start = clock()
    for entry in entries:
        path = root / entry["path"]
        name = hook_name_of(entry["path"])
        remaining = budget - (clock() - start)
        if remaining <= 0:
            results.append(HookResult(name, EXIT_ERROR, error="群組預算用盡，未執行"))
            continue
        timeout = min(float(entry.get("timeout", DEFAULT_HOOK_TIMEOUT)), remaining)
        if not path.exists():
            results.append(HookResult(name, EXIT_ERROR, error="hook 檔案不存在: {}".format(path)))
            continue
        results.append(_run_one(path, payload, timeout, inprocess, logger))
    return results


def _run_one(path: Path, payload: str, timeout: float, inprocess: bool, logger) -> HookResult:
    if inprocess:
        try:
            r = run_inprocess(path, payload, timeout)
        except Exception as e:  # 分派機制本身失敗：退回子程序，守衛不消失
            if logger:
                logger.info("in-process 執行失敗，退回子程序 {}: {}".format(path.name, e))
            r = run_subprocess(path, payload, timeout)
    else:
        r = run_subprocess(path, payload, timeout)
    if r.error and logger:
        logger.info("hook {} 異常: {}".format(r.name, r.error))
    return r


def run_group(group: str, payload: str, registry_path: Path = REGISTRY_PATH,
              root: Path = PROJECT_ROOT, logger=None, inprocess: bool = True) -> tuple:
    cfg = load_group(group, registry_path)
    results = dispatch(cfg["hooks"], payload, root,
                       float(cfg.get("budget", DEFAULT_GROUP_BUDGET)), logger, inprocess)
    return merge_results(results)


def _group_from_argv(argv: List[str]) -> str:
    if "--group" in argv:
        return argv[argv.index("--group") + 1]
    return ""


def main() -> int:
    logger = None
    inprocess = True
    sys.path.insert(0, str(HOOKS_DIR.parent))
    try:
        lib = importlib.import_module("lib")
        logger = lib.setup_hook_logging("hook-dispatcher")
    except Exception as e:  # lib 不可用：所有 hook 退回子程序，且訊息可見
        inprocess = False
        sys.stderr.write("[hook-dispatcher] lib 匯入失敗，改以子程序執行: {}\n".format(e))
    group = _group_from_argv(sys.argv)
    payload = sys.stdin.read()
    try:
        code, out, err = run_group(group, payload, logger=logger, inprocess=inprocess)
    except Exception as e:  # registry 讀取失敗等：fail-open 但可見
        sys.stderr.write("[hook-dispatcher] 分派失敗（group={}）: {}: {}\n".format(
            group, type(e).__name__, e))
        if logger:
            logger.critical("分派失敗 group={}: {}".format(group, e))
        return EXIT_ERROR
    if out:
        sys.stdout.write(out + "\n")
    if err:
        sys.stderr.write(err + "\n")
    return code


if __name__ == "__main__":
    try:
        sys.path.insert(0, str(HOOKS_DIR.parent))
        from lib import run_hook_safely
        sys.exit(run_hook_safely(main, "hook-dispatcher"))
    except ImportError:
        sys.exit(main())  # lib 不可用：main 內會退回子程序執行
