"""465 資料集產生器：依凍結規則 2、3、4、7 由實拍圖產生裁切對與 dataset.jsonl。

manifest 為 JSON 陣列，每對一個物件，鍵：
code, kind, truth, granularity, screen, source, head, base, new
（base／new 為基準圖與新圖的 PNG 路徑）。

用法：python3 build_dataset.py MANIFEST.json OUT_DIR
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import pixel_diff as pd

MERGE_DISTANCE = 32  # 規則 2：最短歐氏距離 <= 32 即合併
RULE7_MIN_N = 12  # 規則 7：n >= 12 改為整張圖單一區塊
EXPAND_MIN = 16  # 規則 3：外擴下限
EXPAND_RATIO = 4  # 外擴 = 該方向邊長 / 4
MIN_BOX = 96  # 規則 3：裁切框最小邊
UPSCALE_BELOW = 384  # 規則 4：長邊小於此值整數倍放大
MAX_LONG_SIDE = 2576  # 規則 4：長邊大於此值面積平均縮小


def region_distance(a, b):
    """兩矩形 (x, y, w, h) 的最短歐氏距離；相交為 0。"""
    dx = max(0, b[0] - (a[0] + a[2]), a[0] - (b[0] + b[2]))
    dy = max(0, b[1] - (a[1] + a[3]), a[1] - (b[1] + b[3]))
    return math.hypot(dx, dy)


def _bounding(a, b):
    x0, y0 = min(a[0], b[0]), min(a[1], b[1])
    x1 = max(a[0] + a[2], b[0] + b[2])
    y1 = max(a[1] + a[3], b[1] + b[3])
    return (x0, y0, x1 - x0, y1 - y0)


def merge_regions(regions):
    """規則 2：距離 <= 32 就併成外接矩形，合併後的框再參與比較，直到穩定。"""
    rs = list(regions)
    merged = True
    while merged:
        merged = False
        for i in range(len(rs)):
            for j in range(i + 1, len(rs)):
                if region_distance(rs[i], rs[j]) <= MERGE_DISTANCE:
                    rs[i] = _bounding(rs[i], rs[j])
                    del rs[j]
                    merged = True
                    break
            if merged:
                break
    return rs


def apply_rule7(regions, width, height):
    """規則 7：n >= 12 整對改為整張圖單一區塊。回傳 (區塊, 是否套用)。"""
    if len(regions) >= RULE7_MIN_N:
        return [(0, 0, width, height)], True
    return list(regions), False


def _box_axis(pos, size, limit):
    """單一方向：外擴、夾在範圍內，不足 MIN_BOX 以區塊中心補足（貼邊往內平移）。"""
    expand = max(EXPAND_MIN, -(-size // EXPAND_RATIO))
    lo, hi = max(0, pos - expand), min(limit, pos + size + expand)
    if hi - lo >= MIN_BOX:
        return lo, hi - lo
    if limit <= MIN_BOX:
        return 0, limit
    lo = (2 * pos + size - MIN_BOX) // 2
    lo = min(max(0, lo), limit - MIN_BOX)
    return lo, MIN_BOX


def crop_box(region, width, height):
    """規則 3：回傳 (x, y, w, h) 裁切框。"""
    x, w = _box_axis(region[0], region[2], width)
    y, h = _box_axis(region[1], region[3], height)
    return (x, y, w, h)


def crop_exact(img, box):
    x, y, w, h = box
    return pd.Image(w, h, [r[x * 3:(x + w) * 3] for r in img.rows[y:y + h]])


def _upscale(img, k):
    rows = []
    for r in img.rows:
        wide = b"".join(r[i:i + 3] * k for i in range(0, len(r), 3))
        rows.extend([wide] * k)
    return pd.Image(img.width * k, img.height * k, rows)


def _axis_weights(src, dst):
    """每個輸出格對應的 [(來源索引, 權重)]，權重為來源格與輸出格覆蓋區的重疊比例。"""
    ratio = src / dst
    out = []
    for o in range(dst):
        lo, hi = o * ratio, (o + 1) * ratio
        cells = []
        for s in range(int(lo), min(src, math.ceil(hi))):
            overlap = min(hi, s + 1) - max(lo, s)
            if overlap > 0:
                cells.append((s, overlap / ratio))
        out.append(cells)
    return out


def _downscale(img, long_side_target):
    long_side = max(img.width, img.height)
    factor = long_side_target / long_side
    nw = max(1, round(img.width * factor))
    nh = max(1, round(img.height * factor))
    wx, wy = _axis_weights(img.width, nw), _axis_weights(img.height, nh)
    tmp = []  # 先沿水平方向平均，每列為 nw*3 個 float
    for r in img.rows:
        line = []
        for cells in wx:
            for c in range(3):
                line.append(sum(r[s * 3 + c] * w for s, w in cells))
        tmp.append(line)
    rows = []
    for cells in wy:
        rows.append(bytes(
            min(255, int(sum(tmp[s][i] * w for s, w in cells) + 0.5)) for i in range(nw * 3)))
    return pd.Image(nw, nh, rows), nw / img.width


def scale_crop(img):
    """規則 4：回傳 (縮放後影像, 倍數)。放大為整數倍，縮小為 float。"""
    long_side = max(img.width, img.height)
    if long_side < UPSCALE_BELOW:
        k = -(-UPSCALE_BELOW // long_side)
        return _upscale(img, k), k
    if long_side > MAX_LONG_SIDE:
        return _downscale(img, MAX_LONG_SIDE)
    return img, 1


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def build_pair(entry, out_dir):
    """處理一對。回傳 (record, None)；基準圖與新圖相同時回傳 (None, 'skip: ...')（規則 6）。"""
    base_bytes = Path(entry["base"]).read_bytes()
    new_bytes = Path(entry["new"]).read_bytes()
    base, new = pd.decode_png(base_bytes), pd.decode_png(new_bytes)
    if (base.width, base.height) != (new.width, new.height):
        raise ValueError(
            f"{entry['code']}: size mismatch base {base.width}x{base.height} "
            f"vs new {new.width}x{new.height}")
    result = pd.compare(base, new)
    if result.skip:
        return None, f"skip: {result.reason}"
    raw_regions = merge_regions(result.regions)
    regions, rule7 = apply_rule7(raw_regions, base.width, base.height)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    crops = []
    for n, region in enumerate(regions, 1):
        box = crop_box(region, base.width, base.height)
        pair = []
        for tag, img in (("base", base), ("new", new)):
            scaled, scale = scale_crop(crop_exact(img, box))
            data = pd.encode_png(scaled)
            path = out / f"{entry['code']}.region{n}.{tag}.png"
            path.write_bytes(data)
            pair.append((path.relative_to(out).as_posix(), _sha256(data)))
        crops.append({"box": list(box), "scale": scale,
                      "base_path": pair[0][0], "base_sha256": pair[0][1],
                      "new_path": pair[1][0], "new_sha256": pair[1][1]})
    record = {k: entry[k] for k in
              ("code", "kind", "truth", "granularity", "screen", "source", "head")}
    record.update({"n": len(raw_regions), "rule7": rule7,
                   "regions": [list(r) for r in regions], "crops": crops,
                   "base_sha256": _sha256(base_bytes), "new_sha256": _sha256(new_bytes)})
    return record, None


def build_dataset(manifest_path, out_dir):
    """讀 manifest，輸出裁切與 dataset.jsonl。回傳 (records, skipped)。"""
    entries = json.loads(Path(manifest_path).read_text())
    records, skipped = [], []
    for entry in entries:
        record, reason = build_pair(entry, out_dir)
        if record is None:
            skipped.append({"code": entry["code"], "reason": reason})
        else:
            records.append(record)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps(r, ensure_ascii=False) for r in records]
    (out / "dataset.jsonl").write_text("".join(line + "\n" for line in lines))
    return records, skipped


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        sys.stderr.write("usage: build_dataset.py MANIFEST.json OUT_DIR\n")
        return 2
    records, skipped = build_dataset(args[0], args[1])
    for s in skipped:
        print(f"{s['code']}: {s['reason']}")
    print(f"{len(records)} pairs written, {len(skipped)} skipped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
