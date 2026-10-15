#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Strategic Compact Suggester

Runs on PreToolUse or periodically to suggest manual compaction at logical intervals.

Why manual over auto-compact:
- Auto-compact happens at arbitrary points, often mid-task
- Strategic compacting preserves context through logical phases
- Compact after exploration, before execution
- Compact after completing a milestone, before starting next

Criteria for suggesting compact:
- Session has been running for extended period
- Large number of tool calls made
- Transitioning from research/exploration to implementation
- Plan has been finalized
"""

import json
import os
import sys
from pathlib import Path

# .claude/skills/strategic-compact/ -> .claude/（lib package 所在）
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from lib import emit_model_reminder  # noqa: E402


def main():
    # Track tool call count (increment in a temp file)
    pid = os.getpid()
    counter_file = Path(f"/tmp/claude-tool-count-{pid}")
    threshold = int(os.environ.get('COMPACT_THRESHOLD', '50'))

    # Initialize or increment counter
    if counter_file.exists():
        try:
            count = int(counter_file.read_text().strip())
            count += 1
        except (ValueError, IOError):
            count = 1
    else:
        count = 1

    counter_file.write_text(str(count))

    message = None
    # Suggest compact after threshold tool calls
    if count == threshold:
        message = f"[StrategicCompact] {threshold} tool calls reached - consider /compact if transitioning phases"
    # Suggest at regular intervals after threshold
    elif count > threshold and count % 25 == 0:
        message = f"[StrategicCompact] {count} tool calls - good checkpoint for /compact if context is stale"

    if message is None:
        return

    # additionalContext 讓模型讀到（stderr + exit 0 模型不可見）。
    # /compact 僅主線程可執行，subagent 不需看到（pm_only）。
    input_data = _read_stdin_json()
    emit_model_reminder("PreToolUse", message, audience="pm_only", input_data=input_data)


def _read_stdin_json():
    """讀取 stdin JSON；空輸入或解析失敗回傳 None（僅影響受眾判斷，不影響提醒輸出）。"""
    try:
        raw = sys.stdin.read().strip()
        return json.loads(raw) if raw else None
    except (ValueError, OSError):
        return None


if __name__ == "__main__":
    main()
