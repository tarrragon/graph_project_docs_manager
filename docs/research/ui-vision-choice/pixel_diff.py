"""截圖像素差異比對（零模型 API、僅標準函式庫）。

容差比對兩張 PNG：有差異時輸出差異區塊外接矩形與兩圖同位置裁切對；
無差異標記 skip（免看，不送模型）。

雜訊底線（0.5.0-W1-465.1 實測）：同一份 fixture 於 macOS 實機連續擷取 5 次，
PNG sha256 逐字相同，逐通道最大差 0。DEFAULT_CHANNEL_TOL 在實測底線 0 之上
留 2 的餘裕，吸收跨機器抗鋸齒的次級抖動；實測底線若改變須重量並更新此值。
"""
import argparse
import json
import struct
import sys
import zlib
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_CHANNEL_TOL = 2
BLOCK = 16  # 差異像素以 BLOCK 格聚成區塊，相鄰區塊合併為一個矩形
PAD = 8  # 裁切時外擴像素，保留上下文
_PNG_SIG = b"\x89PNG\r\n\x1a\n"


@dataclass
class Image:
    width: int
    height: int
    rows: list  # 每列 bytes，RGB 三通道


@dataclass
class DiffResult:
    skip: bool
    regions: list = field(default_factory=list)  # [(x, y, w, h)]
    crops: list = field(default_factory=list)  # [(基準裁切路徑, 新圖裁切路徑)]
    reason: str = ""


def _unfilter(raw, width, height, bpp):
    stride = width * bpp
    rows, prev, pos = [], bytearray(stride), 0
    for _ in range(height):
        ftype = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ftype == 1:
                line[i] = (line[i] + a) & 255
            elif ftype == 2:
                line[i] = (line[i] + b) & 255
            elif ftype == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
            elif ftype != 0:
                raise ValueError(f"unknown PNG filter {ftype}")
        rows.append(bytes(line))
        prev = line
    return rows


def decode_png(data):
    """解 8／16-bit RGB / RGBA 非交錯 PNG，輸出統一為 8-bit RGB（alpha 丟棄）。"""
    if not data.startswith(_PNG_SIG):
        raise ValueError("not a PNG")
    pos, idat, hdr = 8, b"", None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            hdr = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
    width, height, depth, ctype, _, _, interlace = hdr
    if depth not in (8, 16) or ctype not in (2, 6) or interlace:
        raise ValueError(f"unsupported PNG depth={depth} type={ctype} interlace={interlace}")
    channels = 3 if ctype == 2 else 4
    bytes_per_sample = depth // 8
    bpp = channels * bytes_per_sample
    rows = _unfilter(zlib.decompress(idat), width, height, bpp)
    if bytes_per_sample == 2:
        rows = [r[0::2] for r in rows]  # 16-bit 取每通道高位元組，縮成 8-bit
    if channels == 4:
        rows = [bytes(v for i in range(width) for v in r[i * 4:i * 4 + 3]) for r in rows]
    return Image(width, height, rows)


def encode_png(img):
    def chunk(kind, body):
        crc = zlib.crc32(kind + body) & 0xFFFFFFFF
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)

    raw = b"".join(b"\x00" + r for r in img.rows)
    ihdr = struct.pack(">IIBBBBB", img.width, img.height, 8, 2, 0, 0, 0)
    return _PNG_SIG + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def _dirty_blocks(a, b, tol):
    blocks = set()
    for y in range(a.height):
        ra, rb = a.rows[y], b.rows[y]
        if ra == rb:
            continue
        for x in range(a.width):
            i = x * 3
            if (abs(ra[i] - rb[i]) > tol or abs(ra[i + 1] - rb[i + 1]) > tol
                    or abs(ra[i + 2] - rb[i + 2]) > tol):
                blocks.add((x // BLOCK, y // BLOCK))
    return blocks


def _merge_blocks(blocks):
    """8 鄰域連通分量 -> 像素座標外接矩形。"""
    seen, regions = set(), []
    for start in sorted(blocks):
        if start in seen:
            continue
        stack, comp = [start], []
        seen.add(start)
        while stack:
            bx, by = stack.pop()
            comp.append((bx, by))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (bx + dx, by + dy)
                    if n in blocks and n not in seen:
                        seen.add(n)
                        stack.append(n)
        x0 = min(c[0] for c in comp) * BLOCK
        y0 = min(c[1] for c in comp) * BLOCK
        x1 = (max(c[0] for c in comp) + 1) * BLOCK
        y1 = (max(c[1] for c in comp) + 1) * BLOCK
        regions.append((x0, y0, x1 - x0, y1 - y0))
    return regions


def compare(a, b, channel_tol=DEFAULT_CHANNEL_TOL):
    if (a.width, a.height) != (b.width, b.height):
        return DiffResult(False, [(0, 0, max(a.width, b.width), max(a.height, b.height))],
                          reason=f"size mismatch {a.width}x{a.height} vs {b.width}x{b.height}")
    regions = _merge_blocks(_dirty_blocks(a, b, channel_tol))
    regions = [(x, y, min(w, a.width - x), min(h, a.height - y)) for x, y, w, h in regions]
    return DiffResult(skip=not regions, regions=regions, reason="" if regions else "no diff, skip")


def crop(img, x, y, w, h):
    x0, y0 = max(0, x - PAD), max(0, y - PAD)
    x1, y1 = min(img.width, x + w + PAD), min(img.height, y + h + PAD)
    return Image(x1 - x0, y1 - y0, [r[x0 * 3:x1 * 3] for r in img.rows[y0:y1]])


def compare_files(base_path, new_path, out_dir, channel_tol=DEFAULT_CHANNEL_TOL):
    base = decode_png(Path(base_path).read_bytes())
    new = decode_png(Path(new_path).read_bytes())
    result = compare(base, new, channel_tol)
    if result.skip or (base.width, base.height) != (new.width, new.height):
        return result
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for n, (x, y, w, h) in enumerate(result.regions, 1):
        pa, pb = out / f"region{n}.base.png", out / f"region{n}.new.png"
        pa.write_bytes(encode_png(crop(base, x, y, w, h)))
        pb.write_bytes(encode_png(crop(new, x, y, w, h)))
        result.crops.append((str(pa), str(pb)))
    return result


def main(argv=None):
    ap = argparse.ArgumentParser(description="screenshot pixel diff (zero API)")
    ap.add_argument("base")
    ap.add_argument("new")
    ap.add_argument("--out", required=True, help="crop pair output dir")
    ap.add_argument("--tol", type=int, default=DEFAULT_CHANNEL_TOL)
    args = ap.parse_args(argv)
    res = compare_files(args.base, args.new, args.out, args.tol)
    print(json.dumps({"skip": res.skip, "regions": res.regions, "crops": res.crops,
                      "reason": res.reason}, ensure_ascii=False))
    return 0 if res.skip else 1


if __name__ == "__main__":
    sys.exit(main())
