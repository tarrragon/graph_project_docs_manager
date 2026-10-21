"""座標檔幾何檢查（零模型 API）。

讀 0.5.0-W1-466.2 的 `<locale>.coords.json`（elements[].rect = [x, y, w, h]，
logicalSize = [寬, 高]），報告：
- overlaps：非父子（含祖孫）關係的元件矩形重疊（面積 > 0；僅邊相接不算）。
  父子關係取自元素的選填 `parent`（父元素 index）；466.2 現行格式無此欄，
  缺欄時所有成對皆視為非父子。
- outOfViewport：矩形任一邊超出 logicalSize 的元件。讀 `rawRect`（未與視口、
  祖先裁切取交集）；`rect` 已裁切，永遠在視口內。缺 `rawRect` 時退回 `rect`，
  該元素 index 列入輸出的 `rectFallback`，報告項的 `rectSource` 標為 "rect(fallback)"。
"""
import argparse
import json
import sys
from itertools import combinations
from pathlib import Path


def _ancestors(by_index, index):
    seen, cur = set(), by_index[index].get("parent")
    while cur is not None and cur in by_index and cur not in seen:
        seen.add(cur)
        cur = by_index[cur].get("parent")
    return seen


def _overlap_area(r1, r2):
    w = min(r1[0] + r1[2], r2[0] + r2[2]) - max(r1[0], r2[0])
    h = min(r1[1] + r1[3], r2[1] + r2[3]) - max(r1[1], r2[1])
    return w * h if w > 0 and h > 0 else 0.0


def check(doc):
    elements = doc["elements"]
    vw, vh = doc["logicalSize"]
    by_index = {e["index"]: e for e in elements}
    overlaps = []
    for a, b in combinations(elements, 2):
        if b["index"] in _ancestors(by_index, a["index"]) or a["index"] in _ancestors(by_index, b["index"]):
            continue
        area = _overlap_area(a["rect"], b["rect"])
        if area > 0:
            overlaps.append({"a": a["index"], "b": b["index"], "area": area})
    out, fallback = [], []
    for e in elements:
        if "rawRect" in e:
            rect, source = e["rawRect"], "rawRect"
        else:
            rect, source = e["rect"], "rect(fallback)"
            fallback.append(e["index"])
        x, y, w, h = rect
        if x < 0 or y < 0 or x + w > vw or y + h > vh:
            out.append({"index": e["index"], "rect": rect, "rectSource": source})
    return {"overlaps": overlaps, "outOfViewport": out, "rectFallback": fallback}


def check_file(path):
    return check(json.loads(Path(path).read_text(encoding="utf-8")))


def main(argv=None):
    # i18n-exempt: 研究用 CLI 說明文字，非 App 介面
    ap = argparse.ArgumentParser(description="座標檔幾何檢查（零 API）")
    ap.add_argument("coords")
    args = ap.parse_args(argv)
    rep = check_file(args.coords)
    print(json.dumps(rep, ensure_ascii=False, indent=2))
    return 1 if rep["overlaps"] or rep["outOfViewport"] else 0


if __name__ == "__main__":
    sys.exit(main())
