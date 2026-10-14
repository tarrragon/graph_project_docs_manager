"""測試監控檔路徑：pre／post 兩支 hook 共用，鍵的決定規則只在此定義。

鍵的退路：tool_use_id -> session_id -> 舊單檔 test-monitor.json。
"""

import re
from pathlib import Path
from typing import Optional

_UNSAFE_KEY_CHARS = re.compile(r"[^A-Za-z0-9_.-]")


def monitor_key(input_data: dict) -> Optional[str]:
    """回傳監控檔鍵；兩個識別都缺時回傳 None（走舊單檔）。"""
    for field in ("tool_use_id", "session_id"):
        value = input_data.get(field)
        if isinstance(value, str) and value:
            return _UNSAFE_KEY_CHARS.sub("_", value)
    return None


def keyed_monitor_file(project_dir: Path, key: str) -> Path:
    return project_dir / ".claude" / "hook-logs" / "test-monitor" / f"{key}.json"


def legacy_monitor_file(project_dir: Path) -> Path:
    return project_dir / ".claude" / "hook-logs" / "test-monitor.json"
