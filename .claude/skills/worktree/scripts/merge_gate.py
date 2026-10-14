"""
合併前全套件閘門

掛在 worktree_manager.merge_branch_cas 的 pre_merge_check 掛點：commit-tree 之後、
update-ref 之前，在「合併 commit 的 detached worktree 快照」內，經 run-with-timeout
（取得 heavy 名額）跑全套件；紅燈即回報不通過，ref 不變。

為何在快照內跑：共用 checkout 的工作區含其他 session 未提交的修改，測試會直接載入，
結果無法對應到單一 commit。測合併 commit 而非分支 HEAD：測到的即是將寫入 main 的樹。

CAS 重試：每次重試依新 HEAD 產生不同的合併 commit。上次驗過的 commit 與新 commit 的
差異全部落在 RETRY_REUSE_EXEMPT_GLOBS（只改票檔與版本日誌）時，沿用驗證結果不重跑。

套件執行器可注入（SuiteRunner），單元測試不真的跑 hooks 或 flutter 全套件。
"""

import os
import re
import shutil
import signal
import subprocess
import sys
import threading
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator, Optional

# 閘門允許的 CAS 重試次數（不含首次嘗試）；超過即中止並回報最後一次失敗原因
GATE_MAX_RETRIES = 3
# 單一套件的逾時秒數（不含排隊時間，排隊由 run-with-timeout 的名額閘門處理）
SUITE_TIMEOUT_SECONDS = 3600
# 快照目錄（位於 .claude/worktrees/，已被 gitignore）
SNAPSHOT_DIR = ".claude/worktrees"
SNAPSHOT_PREFIX = "merge-gate-"
_GIT_TIMEOUT_SECONDS = 120
_FAILED_ITEMS_MAX = 20
_OUTPUT_TAIL_LINES = 15

SUITE_FLUTTER = "flutter"
SUITE_HOOKS = "hooks"

# 全套件命令（argv）；相對於快照根目錄執行
SUITE_COMMANDS = {
    SUITE_FLUTTER: ["fvm", "flutter", "test"],
    SUITE_HOOKS: ["uv", "--directory", ".claude/hooks", "run", "pytest"],
}

# 範圍判準：路徑前綴或精確檔名命中即需對應套件。見 SKILL.md〈合併前全套件〉
FLUTTER_SCOPE_PREFIXES = ("lib/", "test/", "integration_test/", "macos/", "docs/")
FLUTTER_SCOPE_FILES = ("pubspec.yaml", "pubspec.lock", "l10n.yaml", "analysis_options.yaml")
HOOKS_SCOPE_PREFIXES = (".claude/",)

# 快照內執行前必須就緒的 gitignored 生成產物：套件 -> ((產物路徑, 生成命令), ...)
REQUIRED_ARTIFACTS = {
    SUITE_FLUTTER: ((".dart_tool/package_config.json", ["fvm", "flutter", "pub", "get"]),),
    SUITE_HOOKS: (),
}

# CAS 重試沿用驗證結果的豁免清單：測試不讀取這些檔，只改它們不影響全套件結果。
# 安全性由 test_merge_gate 的守衛測試維持（掃描測試目錄，出現讀取清單內實際檔案即紅）。
RETRY_REUSE_EXEMPT_GLOBS = (
    "docs/work-logs/**/tickets/*.md",
    "docs/work-logs/**/v*-main.md",
)

# (完整 argv, 工作目錄) -> (結束碼, 合併輸出)
SuiteRunner = Callable[[list, str], tuple]


@dataclass(frozen=True)
class GateVerdict:
    """與 worktree_manager.CheckResult 欄位相同（鴨子型別），避免循環 import。"""

    passed: bool
    reason: str = ""


def _glob_to_regex(glob: str) -> "re.Pattern":
    out, i = [], 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out.append("(?:.+/)?")
            i += 3
        elif glob[i] == "*":
            out.append("[^/]*")
            i += 1
        else:
            out.append(re.escape(glob[i]))
            i += 1
    return re.compile("^" + "".join(out) + "$")


_EXEMPT_PATTERNS = tuple(_glob_to_regex(g) for g in RETRY_REUSE_EXEMPT_GLOBS)


def is_reuse_exempt(path: str) -> bool:
    return any(p.match(path) for p in _EXEMPT_PATTERNS)


def select_suites(changed_paths: list) -> list:
    """依改動路徑決定全套件範圍。只改豁免檔或不屬兩種範圍的路徑則回傳空清單。"""
    suites = []
    if any(p.startswith(FLUTTER_SCOPE_PREFIXES) or p in FLUTTER_SCOPE_FILES
           for p in changed_paths if not is_reuse_exempt(p)):
        suites.append(SUITE_FLUTTER)
    if any(p.startswith(HOOKS_SCOPE_PREFIXES) for p in changed_paths):
        suites.append(SUITE_HOOKS)
    return suites


def _git(args: list, repo: str):
    env = {k: v for k, v in os.environ.items() if k not in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE")}
    return subprocess.run(["git", *args], cwd=repo, capture_output=True, env=env, timeout=_GIT_TIMEOUT_SECONDS)


def changed_paths_between(repo: str, old: str, new: str) -> Optional[list]:
    """兩個 commit 間改動的路徑；git 失敗回傳 None（呼叫端須視為需重跑）。"""
    proc = _git(["diff-tree", "-r", "-z", "--name-only", "--no-renames", old, new], repo)
    if proc.returncode != 0:
        return None
    return [p.decode("utf-8", "surrogateescape") for p in proc.stdout.split(b"\0") if p]


def _remove_snapshot(repo: str, path: str) -> None:
    """移除快照；git 移除失敗時退回直接刪目錄，最後 prune 清掉登記。"""
    try:
        _git(["worktree", "remove", "--force", path], repo)
    finally:
        if os.path.lexists(path):
            shutil.rmtree(path, ignore_errors=True)
        _git(["worktree", "prune"], repo)


@contextmanager
def merge_snapshot(repo: str, commit: str) -> Iterator[str]:
    """建立合併 commit 的 detached worktree 快照；離開（成功、例外、中斷）時一律移除。"""
    parent = Path(repo) / SNAPSHOT_DIR
    parent.mkdir(parents=True, exist_ok=True)
    path = str(parent / f"{SNAPSHOT_PREFIX}{commit[:12]}-{os.getpid()}")
    try:
        proc = _git(["worktree", "add", "--detach", path, commit], repo)
        if proc.returncode != 0:
            raise RuntimeError(f"建立快照失敗：{proc.stderr.decode('utf-8', 'replace').strip()}")
        yield path
    finally:
        _remove_snapshot(repo, path)


@contextmanager
def _sigterm_as_interrupt() -> Iterator[None]:
    """SIGTERM 轉為 KeyboardInterrupt，使 finally 有機會移除快照；非主執行緒不處理。"""
    if threading.current_thread() is not threading.main_thread():
        yield
        return

    def _raise(_signum, _frame):
        raise KeyboardInterrupt("收到 SIGTERM")

    previous = signal.signal(signal.SIGTERM, _raise)
    try:
        yield
    finally:
        signal.signal(signal.SIGTERM, previous)


def wrapped_argv(command: list, project_root: str, timeout: int = SUITE_TIMEOUT_SECONDS) -> list:
    """全套件一律經 run-with-timeout（heavy 命令自動取得全機名額）。"""
    script = str(Path(project_root) / ".claude" / "scripts" / "run-with-timeout.py")
    return [sys.executable, script, str(timeout), "--", *command]


def default_runner(argv: list, cwd: str) -> tuple:
    """真實執行；回傳 (結束碼, stdout+stderr)。"""
    proc = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, errors="replace")
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def _failed_items(output: str) -> list:
    """從 pytest／flutter 輸出摘出失敗項；摘不到時回傳輸出尾段。"""
    lines = output.splitlines()
    items = [ln.strip() for ln in lines if ln.startswith("FAILED ") or "[E]" in ln]
    if not items:
        items = [ln for ln in lines[-_OUTPUT_TAIL_LINES:] if ln.strip()]
    return items[:_FAILED_ITEMS_MAX]


def _rc_reason(suite: str, rc: int, output: str) -> str:
    if rc == 124:
        return f"[{suite}] 全套件逾時（{SUITE_TIMEOUT_SECONDS} 秒）"
    if rc == 125:
        return f"[{suite}] 等待本機名額逾時，全套件未執行"
    return f"[{suite}] 全套件紅燈（exit {rc}），失敗項：\n  " + "\n  ".join(_failed_items(output))


def _ensure_artifacts(suite: str, snapshot: str, project_root: str, runner: SuiteRunner) -> str:
    """缺 gitignored 生成產物時先生成；生成失敗或仍缺則回傳指名缺漏的理由，否則空字串。"""
    for artifact, generator in REQUIRED_ARTIFACTS[suite]:
        if os.path.exists(os.path.join(snapshot, artifact)):
            continue
        rc, out = runner(wrapped_argv(generator, project_root), snapshot)
        if rc != 0 or not os.path.exists(os.path.join(snapshot, artifact)):
            tail = out.strip().splitlines()[-3:]
            return (f"[{suite}] 快照缺生成產物 {artifact}，生成命令 {' '.join(generator)} 失敗"
                    f"（exit {rc}）：{' / '.join(tail)}")
    return ""


def _run_suites(suites: list, snapshot: str, project_root: str, runner: SuiteRunner) -> str:
    """依序跑各套件；任一紅燈即停。回傳空字串表示全綠。"""
    for suite in suites:
        missing = _ensure_artifacts(suite, snapshot, project_root, runner)
        if missing:
            return missing
        rc, out = runner(wrapped_argv(SUITE_COMMANDS[suite], project_root), snapshot)
        if rc != 0:
            return _rc_reason(suite, rc, out)
    return ""


class MergeGate:
    """可掛到 merge_branch_cas(pre_merge_check=...) 的檢查物件；持有跨重試的驗證狀態。"""

    def __init__(self, repo: str, runner: Optional[SuiteRunner] = None, project_root: Optional[str] = None):
        self.repo = repo
        self.runner = runner or default_runner
        self.project_root = project_root or repo
        self.verified_commit: Optional[str] = None
        self.suite_runs = 0

    def _can_reuse(self, commit: str) -> bool:
        if self.verified_commit is None:
            return False
        diff = changed_paths_between(self.repo, self.verified_commit, commit)
        return diff is not None and all(is_reuse_exempt(p) for p in diff)

    def __call__(self, commit: str, ref: str, expected_old: str, attempt: int) -> GateVerdict:
        if self._can_reuse(commit):
            print(f"[合併前測試] 與上次驗過的 {self.verified_commit[:12]} 差異全在豁免清單內，沿用驗證結果")
            return GateVerdict(True)
        paths = changed_paths_between(self.repo, expected_old, commit)
        if paths is None:
            return GateVerdict(False, "無法計算合併改動範圍")
        suites = select_suites(paths)
        if not suites:
            print("[合併前測試] 改動不在任何全套件範圍內，免跑")
            self.verified_commit = commit
            return GateVerdict(True)
        print(f"[合併前測試] 快照內跑全套件：{', '.join(suites)}（合併 commit {commit[:12]}，嘗試 {attempt}）")
        with _sigterm_as_interrupt(), merge_snapshot(self.repo, commit) as snap:
            self.suite_runs += 1
            reason = _run_suites(suites, snap, self.project_root, self.runner)
        if reason:
            return GateVerdict(False, reason)
        self.verified_commit = commit
        return GateVerdict(True)


_PATH_TOKEN = re.compile(r"docs/work-logs/[^\s'\"`)\]}>,]+\.md")
# 同一行出現這些讀取寫法才算「讀取實際檔案」；純路徑字串比對與 JSON 資料夾具不算
_READ_CALL = re.compile(r"File\(|readAs|open\(|Path\(|read_text|read_bytes|\bcat\b|\.read\(|load\(")
_CODE_SUFFIXES = (".py", ".sh", ".dart")
_TEST_SCAN_DIRS = ("test", "integration_test")
_SKIP_DIRS = {".git", ".venv", "node_modules", "worktrees", ".dart_tool", "build", "__pycache__"}


def _test_files(root: Path) -> list:
    files = []
    for d in _TEST_SCAN_DIRS:
        files += [p for p in (root / d).rglob("*") if p.is_file()]
    for dirpath, dirnames, filenames in os.walk(root / ".claude"):
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
        if "tests" not in Path(dirpath).relative_to(root).parts:
            continue
        files += [Path(dirpath) / n for n in filenames]
    return [f for f in files if f.suffix in _CODE_SUFFIXES]


def find_exempt_file_reads(root: Path) -> list:
    """守衛：回傳測試程式碼中「同一行以讀取寫法引用豁免清單內且實際存在之檔案」的 (測試檔, 路徑)。

    限制：只辨識路徑字串與讀取呼叫同行的寫法；經常數或變數間接讀取者不在偵測範圍，
    新增此類寫法時須人工確認不讀豁免清單內的實際檔案。
    """
    hits = []
    for f in _test_files(root):
        try:
            lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for line in lines:
            if not _READ_CALL.search(line):
                continue
            for token in _PATH_TOKEN.findall(line):
                if is_reuse_exempt(token) and (root / token).is_file():
                    hits.append((str(f.relative_to(root)), token))
    return sorted(set(hits))
