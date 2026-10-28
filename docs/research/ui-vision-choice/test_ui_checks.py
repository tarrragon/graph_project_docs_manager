"""pixel_diff / geometry_check 的測試（含正向對照，E2）。"""
import json
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

import build_dataset as bd
import geometry_check as gc
import pixel_diff as pd


def solid(w, h, rgb=(255, 255, 255)):
    return pd.Image(w, h, [bytes(rgb) * w for _ in range(h)])


def paint(img, x, y, w, h, rgb):
    for r in range(y, y + h):
        row = bytearray(img.rows[r])
        row[x * 3:(x + w) * 3] = bytes(rgb) * w
        img.rows[r] = bytes(row)


def png16(img, rgba=True):
    """測試用：把 8-bit Image 編成 16-bit PNG（高位元組=值，低位元組=0x55）。"""
    def chunk(kind, body):
        crc = zlib.crc32(kind + body) & 0xFFFFFFFF
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)

    raw = b""
    for r in img.rows:
        px = b"".join(
            bytes([r[i], 0x55, r[i + 1], 0x55, r[i + 2], 0x55] + ([255, 255] if rgba else []))
            for i in range(0, len(r), 3))
        raw += b"\x00" + px
    ihdr = struct.pack(">IIBBBBB", img.width, img.height, 16, 6 if rgba else 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


class PixelDiff16BitTest(unittest.TestCase):
    def test_decode_16bit_rgb_and_rgba(self):
        img = solid(5, 4, (10, 20, 30))
        for rgba in (True, False):
            out = pd.decode_png(png16(img, rgba))
            self.assertEqual((out.width, out.height, out.rows), (5, 4, img.rows))

    def test_16bit_known_diff_is_reported(self):  # 正向對照
        a, b = solid(100, 80), solid(100, 80)
        paint(b, 30, 20, 10, 8, (255, 0, 0))
        r = pd.compare(pd.decode_png(png16(a)), pd.decode_png(png16(b)))
        self.assertFalse(r.skip)
        x, y, w, h = r.regions[0]
        self.assertTrue(x <= 30 and y <= 20 and x + w >= 40 and y + h >= 28)

    def test_16bit_self_compare_is_skip(self):  # 負向對照
        a = pd.decode_png(png16(solid(64, 64, (7, 8, 9))))
        self.assertTrue(pd.compare(a, a).skip)


class PixelDiffTest(unittest.TestCase):
    def test_png_roundtrip(self):
        img = solid(5, 4, (10, 20, 30))
        out = pd.decode_png(pd.encode_png(img))
        self.assertEqual((out.width, out.height, out.rows), (5, 4, img.rows))

    def test_identical_is_skip(self):
        r = pd.compare(solid(64, 64), solid(64, 64))
        self.assertTrue(r.skip)
        self.assertEqual(r.regions, [])

    def test_known_diff_is_reported(self):  # 正向對照
        a, b = solid(100, 80), solid(100, 80)
        paint(b, 30, 20, 10, 8, (255, 0, 0))
        r = pd.compare(a, b)
        self.assertFalse(r.skip)
        self.assertEqual(len(r.regions), 1)
        x, y, w, h = r.regions[0]
        self.assertTrue(x <= 30 and y <= 20 and x + w >= 40 and y + h >= 28)

    def test_two_separate_diffs_two_regions(self):
        a, b = solid(200, 200), solid(200, 200)
        paint(b, 5, 5, 4, 4, (0, 0, 0))
        paint(b, 150, 150, 4, 4, (0, 0, 0))
        self.assertEqual(len(pd.compare(a, b).regions), 2)

    def test_tolerance_absorbs_small_delta_but_not_large(self):
        a, b = solid(40, 40, (100, 100, 100)), solid(40, 40, (100, 100, 100))
        paint(b, 0, 0, 40, 40, (102, 100, 100))
        self.assertTrue(pd.compare(a, b, channel_tol=2).skip)
        paint(b, 0, 0, 40, 40, (110, 100, 100))
        self.assertFalse(pd.compare(a, b, channel_tol=2).skip)

    def test_size_mismatch_is_diff(self):
        r = pd.compare(solid(10, 10), solid(10, 12))
        self.assertFalse(r.skip)

    def test_crop_pairs_written(self):
        a, b = solid(100, 80), solid(100, 80)
        paint(b, 30, 20, 10, 8, (255, 0, 0))
        with tempfile.TemporaryDirectory() as d:
            pa, pb = Path(d, "a.png"), Path(d, "b.png")
            pa.write_bytes(pd.encode_png(a))
            pb.write_bytes(pd.encode_png(b))
            res = pd.compare_files(pa, pb, Path(d, "out"))
            self.assertFalse(res.skip)
            self.assertEqual(len(res.crops), 1)
            ca, cb = res.crops[0]
            self.assertTrue(Path(ca).exists() and Path(cb).exists())
            self.assertNotEqual(Path(ca).read_bytes(), Path(cb).read_bytes())


class GeometryTest(unittest.TestCase):
    def doc(self, elements, size=(1280, 800)):
        return {"logicalSize": list(size), "elements": elements}

    def el(self, i, rect, parent=None):
        e = {"index": i, "type": "B", "rect": rect}
        if parent is not None:
            e["parent"] = parent
        return e

    def test_overlap_reported(self):  # 正向對照
        rep = gc.check(self.doc([self.el(1, [0, 0, 100, 50]), self.el(2, [50, 20, 100, 50])]))
        self.assertEqual([(o["a"], o["b"]) for o in rep["overlaps"]], [(1, 2)])

    def test_touching_not_overlap(self):
        rep = gc.check(self.doc([self.el(1, [0, 0, 100, 50]), self.el(2, [100, 0, 100, 50])]))
        self.assertEqual(rep["overlaps"], [])

    def test_parent_child_excluded(self):
        rep = gc.check(self.doc([self.el(1, [0, 0, 100, 50]), self.el(2, [10, 10, 20, 20], parent=1)]))
        self.assertEqual(rep["overlaps"], [])

    def test_grandchild_excluded(self):
        els = [self.el(1, [0, 0, 100, 50]), self.el(2, [5, 5, 50, 30], parent=1),
               self.el(3, [10, 10, 20, 20], parent=2)]
        self.assertEqual(gc.check(self.doc(els))["overlaps"], [])

    def test_out_of_viewport_reported(self):  # 正向對照
        rep = gc.check(self.doc([self.el(1, [1200, 10, 100, 50]), self.el(2, [0, 0, 10, 10])]))
        self.assertEqual([o["index"] for o in rep["outOfViewport"]], [1])

    def test_inside_viewport_clean(self):
        rep = gc.check(self.doc([self.el(1, [1180, 750, 100, 50])]))
        self.assertEqual(rep["outOfViewport"], [])

    def test_raw_rect_out_of_viewport_reported(self):  # 正向對照：rect 已裁切在內、rawRect 超出
        e = self.el(1, [1180, 10, 100, 50])
        e["rawRect"] = [1180, 10, 300, 50]
        rep = gc.check(self.doc([e]))
        self.assertEqual([o["index"] for o in rep["outOfViewport"]], [1])
        self.assertEqual(rep["outOfViewport"][0]["rectSource"], "rawRect")
        self.assertEqual(rep["rectFallback"], [])

    def test_raw_rect_inside_overrides_rect(self):  # 對照：rawRect 在內時以 rawRect 為準
        e = self.el(1, [1200, 10, 100, 50])
        e["rawRect"] = [0, 0, 10, 10]
        self.assertEqual(gc.check(self.doc([e]))["outOfViewport"], [])

    def test_missing_raw_rect_falls_back_and_is_marked(self):
        rep = gc.check(self.doc([self.el(1, [1200, 10, 100, 50]), self.el(2, [0, 0, 10, 10])]))
        self.assertEqual(rep["outOfViewport"][0]["rectSource"], "rect(fallback)")
        self.assertEqual(rep["rectFallback"], [1, 2])

    def test_load_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d, "c.json")
            p.write_text(json.dumps(self.doc([self.el(1, [0, 0, 10, 10])])))
            self.assertEqual(gc.check_file(p)["overlaps"], [])


class MergeRegionsTest(unittest.TestCase):
    def test_gap_32_merges_gap_33_does_not(self):
        self.assertEqual(bd.merge_regions([(0, 0, 10, 10), (42, 0, 10, 10)]), [(0, 0, 52, 10)])
        self.assertEqual(len(bd.merge_regions([(0, 0, 10, 10), (43, 0, 10, 10)])), 2)

    def test_euclidean_diagonal(self):
        # 水平、垂直間隙各 23 -> 距離約 32.5 > 32，不合併；各 22 -> 約 31.1，合併
        self.assertEqual(len(bd.merge_regions([(0, 0, 10, 10), (33, 33, 10, 10)])), 2)
        self.assertEqual(len(bd.merge_regions([(0, 0, 10, 10), (32, 32, 10, 10)])), 1)

    def test_overlap_merges(self):
        self.assertEqual(bd.merge_regions([(0, 0, 50, 50), (20, 20, 50, 50)]), [(0, 0, 70, 70)])

    def test_chain_merge(self):
        chain = [(i * 40, 0, 10, 10) for i in range(4)]  # 間隙各 30
        self.assertEqual(bd.merge_regions(chain), [(0, 0, 130, 10)])

    def test_merged_box_merges_again(self):
        # A、B 合併後的外接框變大，才與 C 距離 <=32；A、C 原本相距 > 32
        a, b, c = (0, 0, 10, 10), (40, 0, 10, 100), (0, 130, 10, 10)
        self.assertGreater(bd.region_distance(a, c), 32)
        self.assertEqual(bd.merge_regions([a, b, c]), [(0, 0, 50, 140)])

    def test_order_independent(self):
        rs = [(0, 0, 10, 10), (40, 0, 10, 100), (0, 130, 10, 10), (300, 300, 5, 5)]
        self.assertEqual(sorted(bd.merge_regions(rs)), sorted(bd.merge_regions(rs[::-1])))


class Rule7Test(unittest.TestCase):
    def regions(self, n):
        return [(i * 100, 0, 10, 10) for i in range(n)]

    def test_n11_not_applied(self):
        out, applied = bd.apply_rule7(self.regions(11), 1280, 800)
        self.assertFalse(applied)
        self.assertEqual(len(out), 11)

    def test_n12_applied(self):
        out, applied = bd.apply_rule7(self.regions(12), 1280, 800)
        self.assertTrue(applied)
        self.assertEqual(out, [(0, 0, 1280, 800)])


class CropBoxTest(unittest.TestCase):
    def test_expand_min_16_then_pad(self):
        # 40x40 外擴 16 -> 72x72，不足 96，以區塊中心 (220,220) 補到 96
        self.assertEqual(bd.crop_box((200, 200, 40, 40), 1280, 800), (172, 172, 96, 96))

    def test_expand_quarter(self):
        self.assertEqual(bd.crop_box((300, 300, 200, 200), 1280, 800), (250, 250, 300, 300))

    def test_edge_clamped(self):
        self.assertEqual(bd.crop_box((0, 0, 100, 100), 1280, 800), (0, 0, 125, 125))

    def test_small_block_padded_to_96_around_center(self):
        self.assertEqual(bd.crop_box((600, 400, 16, 16), 1280, 800), (560, 360, 96, 96))

    def test_small_block_at_corner_shifts_inward(self):
        self.assertEqual(bd.crop_box((0, 0, 16, 16), 1280, 800), (0, 0, 96, 96))
        self.assertEqual(bd.crop_box((1264, 784, 16, 16), 1280, 800), (1184, 704, 96, 96))

    def test_each_side_uses_own_direction(self):
        # 寬 400 高 20：左右外擴 100，上下外擴 16 -> 高 52 補到 96（中心 y=310）
        self.assertEqual(bd.crop_box((500, 300, 400, 20), 1280, 800), (400, 262, 600, 96))

    def test_whole_image_box(self):
        self.assertEqual(bd.crop_box((0, 0, 1280, 800), 1280, 800), (0, 0, 1280, 800))


class ScaleCropTest(unittest.TestCase):
    def test_upscale_integer_nearest(self):
        img = solid(100, 50, (1, 2, 3))
        paint(img, 0, 0, 1, 1, (9, 9, 9))
        out, scale = bd.scale_crop(img)
        self.assertEqual(scale, 4)  # 384/100 -> 4
        self.assertEqual((out.width, out.height), (400, 200))
        self.assertEqual(out.rows[3][0:3], bytes((9, 9, 9)))
        self.assertEqual(out.rows[4][0:3], bytes((1, 2, 3)))

    def test_upscale_minimal_factor(self):
        self.assertEqual(bd.scale_crop(solid(192, 10))[1], 2)
        self.assertEqual(bd.scale_crop(solid(383, 10))[1], 2)

    def test_384_unchanged(self):
        out, scale = bd.scale_crop(solid(384, 10))
        self.assertEqual((scale, out.width), (1, 384))

    def test_mid_range_unchanged(self):
        out, scale = bd.scale_crop(solid(1280, 800))
        self.assertEqual((scale, out.width, out.height), (1, 1280, 800))

    def test_2576_unchanged(self):
        out, scale = bd.scale_crop(solid(2576, 4))
        self.assertEqual((scale, out.width), (1, 2576))

    def test_downscale_area_average(self):
        img = solid(5152, 2, (0, 0, 0))
        paint(img, 0, 0, 1, 2, (200, 100, 50))
        out, scale = bd.scale_crop(img)
        self.assertEqual((out.width, out.height), (2576, 1))
        self.assertEqual(out.rows[0][0:3], bytes((100, 50, 25)))
        self.assertAlmostEqual(scale, 0.5)


class BuildPairTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.base = solid(400, 300)
        self.new = solid(400, 300)
        paint(self.new, 100, 100, 20, 20, (0, 0, 0))
        (self.dir / "b.png").write_bytes(pd.encode_png(self.base))
        (self.dir / "n.png").write_bytes(pd.encode_png(self.new))
        self.entry = {"code": "T1", "kind": "defect", "truth": "defect", "granularity": "coarse",
                      "screen": "domain", "source": "unit", "head": "abc123",
                      "base": str(self.dir / "b.png"), "new": str(self.dir / "n.png")}

    def tearDown(self):
        self.tmp.cleanup()

    def test_record_fields_and_files(self):
        import hashlib
        rec, reason = bd.build_pair(self.entry, self.dir / "out")
        self.assertIsNone(reason)
        for k in ("code", "kind", "truth", "granularity", "screen", "source", "head", "n",
                  "rule7", "regions", "crops", "base_sha256", "new_sha256"):
            self.assertIn(k, rec)
        self.assertEqual((rec["n"], rec["rule7"]), (1, False))
        self.assertEqual(rec["regions"], [[96, 96, 32, 32]])
        crop = rec["crops"][0]
        self.assertEqual(crop["box"], [64, 64, 96, 96])
        self.assertEqual(crop["scale"], 4)
        out = self.dir / "out"
        for key in ("base_path", "new_path"):
            self.assertFalse(Path(crop[key]).is_absolute())
            self.assertTrue((out / crop[key]).is_file())
        data = (out / crop["base_path"]).read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), crop["base_sha256"])
        img = pd.decode_png((out / crop["new_path"]).read_bytes())
        self.assertEqual((img.width, img.height), (384, 384))
        self.assertEqual(rec["base_sha256"],
                         hashlib.sha256((self.dir / "b.png").read_bytes()).hexdigest())

    def test_identical_pair_skips_without_output(self):
        (self.dir / "n.png").write_bytes((self.dir / "b.png").read_bytes())
        rec, reason = bd.build_pair(self.entry, self.dir / "out")
        self.assertIsNone(rec)
        self.assertIn("skip", reason)
        out = self.dir / "out"
        self.assertFalse(out.exists() and any(out.iterdir()))

    def test_size_mismatch_raises_with_code_and_sizes(self):
        (self.dir / "n.png").write_bytes(pd.encode_png(solid(410, 300)))
        with self.assertRaises(ValueError) as cm:
            bd.build_pair(self.entry, self.dir / "out")
        msg = str(cm.exception)
        for part in ("T1", "400x300", "410x300"):
            self.assertIn(part, msg)

    def test_rule7_whole_image(self):
        new = solid(400, 300)
        for i in range(12):
            paint(new, 4 + (i % 4) * 90, 4 + (i // 4) * 90, 5, 5, (0, 0, 0))
        (self.dir / "n.png").write_bytes(pd.encode_png(new))
        rec, _ = bd.build_pair(self.entry, self.dir / "out")
        self.assertTrue(rec["rule7"])
        self.assertEqual(rec["n"], 12)
        self.assertEqual(rec["crops"][0]["box"], [0, 0, 400, 300])

    def test_build_dataset_writes_jsonl_and_reports_skip(self):
        same = dict(self.entry, code="T2", new=str(self.dir / "b.png"))
        manifest = self.dir / "m.json"
        manifest.write_text(json.dumps([self.entry, same]))
        records, skipped = bd.build_dataset(manifest, self.dir / "out")
        self.assertEqual([r["code"] for r in records], ["T1"])
        self.assertEqual([s["code"] for s in skipped], ["T2"])
        lines = (self.dir / "out" / "dataset.jsonl").read_text().splitlines()
        self.assertEqual([json.loads(line)["code"] for line in lines], ["T1"])


if __name__ == "__main__":
    unittest.main()
