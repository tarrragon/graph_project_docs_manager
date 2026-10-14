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
SUITE_SCRIPTS = "scripts"
SUITE_SKILL_PREFIX = "skill:"

# 全套件命令（argv）；相對於快照根目錄執行
SUITE_COMMANDS = {
    SUITE_FLUTTER: ["fvm", "flutter", "test"],
    SUITE_HOOKS: ["uv", "--directory", ".claude/hooks", "run", "pytest"],
    SUITE_SCRIPTS: ["uv", "--directory", ".claude/scripts", "run", "pytest"],
}

# 範圍判準：路徑前綴或精確檔名命中即需對應套件。見 SKILL.md〈合併前全套件〉
FLUTTER_SCOPE_PREFIXES = ("lib/", "test/", "integration_test/", "macos/", "docs/")
FLUTTER_SCOPE_FILES = ("pubspec.yaml", "pubspec.lock", "l10n.yaml", "analysis_options.yaml")

# 快照內執行前必須就緒的 gitignored 生成產物：套件 -> ((產物路徑, 生成命令), ...)
REQUIRED_ARTIFACTS = {
    SUITE_FLUTTER: ((".dart_tool/package_config.json", ["fvm", "flutter", "pub", "get"]),),
    SUITE_HOOKS: (),
    SUITE_SCRIPTS: (),
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


def _skill_name(path: str) -> Optional[str]:
    parts = path.split("/")
    return parts[2] if len(parts) > 3 and parts[:2] == [".claude", "skills"] else None


def _skill_has_tests(root: str, name: str) -> bool:
    return os.path.isdir(os.path.join(root, ".claude", "skills", name, "tests"))


_LIB_IMPORT = re.compile(r"^\s*(?:from|import)\s+lib(?:\.|\s|$)", re.MULTILINE)


def _skills_importing_lib(root: str) -> list:
    """掃描快照：帶 tests 目錄且有 .py 匯入 lib 的 skill 名稱（不寫死清單，新增 skill 不會漏）。"""
    base = Path(root) / ".claude" / "skills"
    found = []
    for skill in sorted(p for p in base.iterdir() if p.is_dir()) if base.is_dir() else []:
        if not (skill / "tests").is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(skill):
            dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
            if any(_LIB_IMPORT.search(_read_text(Path(dirpath) / n)) for n in filenames if n.endswith(".py")):
                found.append(skill.name)
                break
    return found


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""  # 掃描中途消失或不可讀：視為不匯入 lib，不影響其他檔


def _skill_top_modules(root: str, name: str) -> set:
    """skill 提供的頂層模組名：skill 根與其 scripts/ 下的 .py 模組、帶 __init__.py 的套件。

    hook 常以 sys.path.insert 指向 skill 根或 scripts/ 後匯入，所以兩處都算。
    """
    mods = set()
    for sub in ("", "scripts"):
        base = Path(root) / ".claude" / "skills" / name / sub
        if not base.is_dir():
            continue
        for entry in base.iterdir():
            if entry.is_dir() and (entry / "__init__.py").is_file() and entry.name != "tests":
                mods.add(entry.name)
            elif entry.suffix == ".py" and entry.stem != "__init__" and not entry.stem.startswith("test_"):
                mods.add(entry.stem)
    return mods


def _consumer_suites(root: str, skills: set) -> set:
    """hooks／scripts 的 .py 若匯入這些 skill 的頂層模組，或引用 `skills/<名稱>/` 路徑，回傳對應套件。

    匯入以行首 `from X`／`import X` 辨識，故 sys.path.insert 之後的匯入同樣涵蓋；路徑引用
    只計非測試檔（測試檔提到路徑多為斷言字串）。通用模組名（如 constants）可能多報，只會多跑套件。
    """
    suites = set()
    for suite, sub in ((SUITE_HOOKS, "hooks"), (SUITE_SCRIPTS, "scripts")):
        mods = {s: _skill_top_modules(root, s) for s in skills}
        for dirpath, dirnames, filenames in os.walk(Path(root) / ".claude" / sub):
            dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
            is_test = "tests" in Path(dirpath).parts
            for n in (n for n in filenames if n.endswith(".py")):
                text = _read_text(Path(dirpath) / n)
                if any(_imports_any(text, m) or (not is_test and f"skills/{s}/" in text)
                       for s, m in mods.items()):
                    suites.add(suite)
    return suites


def _imports_any(text: str, modules: set) -> bool:
    return bool(modules) and re.search(
        r"^\s*(?:from|import)\s+(?:%s)\b" % "|".join(re.escape(m) for m in sorted(modules)), text, re.MULTILINE
    ) is not None


def needs_gate(changed_paths: list) -> bool:
    """改動是否可能落在任何全套件範圍內（用於決定是否值得建立快照）。"""
    return any(p.startswith(FLUTTER_SCOPE_PREFIXES) or p in FLUTTER_SCOPE_FILES or p.startswith(".claude/")
               for p in changed_paths if not is_reuse_exempt(p))


def select_suites(changed_paths: list, root: str) -> list:
    """依改動路徑決定套件範圍（root 為合併 commit 的快照，供掃描 skill）。對應表見 SKILL.md。

    套件識別：flutter／hooks／scripts／skill:<名稱>。回傳順序固定，空清單表示免跑。
    """
    paths = [p for p in changed_paths if not is_reuse_exempt(p)]
    want = set()
    touched_skills = {n for n in (_skill_name(p) for p in paths) if n}
    if any(p.startswith(FLUTTER_SCOPE_PREFIXES) or p in FLUTTER_SCOPE_FILES for p in paths):
        want.add(SUITE_FLUTTER)
    for p in (p for p in paths if p.startswith(".claude/")):
        skill = _skill_name(p)
        if skill and _skill_has_tests(root, skill):
            want.add(f"{SUITE_SKILL_PREFIX}{skill}")
        elif p.startswith(".claude/scripts/"):
            want.add(SUITE_SCRIPTS)
        elif p.startswith(".claude/lib/"):
            want.update({SUITE_HOOKS, SUITE_SCRIPTS})
            want.update(f"{SUITE_SKILL_PREFIX}{s}" for s in _skills_importing_lib(root))
        else:  # hooks、rules、settings、無 tests 的 skill 等：hook 測試會讀這些檔
            want.add(SUITE_HOOKS)
    if touched_skills:
        want |= _consumer_suites(root, touched_skills)  # hooks／scripts 匯入該 skill 時加跑
    head = [s for s in (SUITE_FLUTTER, SUITE_HOOKS, SUITE_SCRIPTS) if s in want]
    return head + sorted(s for s in want if s.startswith(SUITE_SKILL_PREFIX))


def suite_command(suite: str, root: str) -> list:
    """套件的執行命令；skill 有 pyproject 沿用 uv --directory，無則借 hooks 的環境跑其 tests 目錄。"""
    if not suite.startswith(SUITE_SKILL_PREFIX):
        return SUITE_COMMANDS[suite]
    name = suite[len(SUITE_SKILL_PREFIX):]
    if os.path.isfile(os.path.join(root, ".claude", "skills", name, "pyproject.toml")):
        return ["uv", "--directory", f".claude/skills/{name}", "run", "pytest"]
    return ["uv", "--directory", ".claude/hooks", "run", "pytest", "-p", "no:cacheprovider", f"../skills/{name}/tests"]


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
    for artifact, generator in REQUIRED_ARTIFACTS.get(suite, ()):
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
        rc, out = runner(wrapped_argv(suite_command(suite, snapshot), project_root), snapshot)
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
        if not needs_gate(paths):
            print("[合併前測試] 改動不在任何全套件範圍內，免跑")
            self.verified_commit = commit
            return GateVerdict(True)
        with _sigterm_as_interrupt(), merge_snapshot(self.repo, commit) as snap:
            suites = select_suites(paths, snap)
            if suites:
                print(f"[合併前測試] 快照內跑全套件：{', '.join(suites)}（合併 commit {commit[:12]}，嘗試 {attempt}）")
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
            continue  # 守衛掃描中途消失或不可讀的測試檔：無內容可判，略過不影響其他檔
        for line in lines:
            if not _READ_CALL.search(line):
                continue
            for token in _PATH_TOKEN.findall(line):
                if is_reuse_exempt(token) and (root / token).is_file():
                    hits.append((str(f.relative_to(root)), token))
    return sorted(set(hits))
