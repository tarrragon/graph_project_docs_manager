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
import run_sampling as rs


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


class FakeResp:
    def __init__(self, text, model, stop="end_turn"):
        self.content = [type("B", (), {"type": "text", "text": text})()]
        self.stop_reason, self.model = stop, model
        self.usage = type("U", (), {"input_tokens": 1, "output_tokens": 1})()


class FakeClient:
    """依模型逐次回放腳本；記錄每次呼叫參數。"""

    def __init__(self, haiku, opus=()):
        self.q = {"haiku": list(haiku), "opus": list(opus)}
        self.calls = []
        self.messages = self

    def create(self, **kw):
        self.calls.append(kw)
        key = "haiku" if "haiku" in kw["model"] else "opus"
        item = self.q[key].pop(0)
        text, stop = item if isinstance(item, tuple) else (item, "end_turn")
        return FakeResp(text, kw["model"], stop)


class RunSamplingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.regions = []
        for code, kind, n in (("X1", "defect", 1), ("X2", "expected", 2),
                              ("M9", "mirror", 1)):
            for i in range(1, n + 1):
                png = self.dir / f"{code}.{i}.png"
                png.write_bytes(b"\x89PNG")
                self.regions.append({"code": code, "kind": kind, "region": i,
                                     "paths": [png, png]})
        self.out = self.dir / "out"

    def run_with(self, client, sample_fn=None):
        kw = {"sample_fn": sample_fn} if sample_fn else {}
        r = rs.Runner(client, self.out, **kw)
        return r, r.run(self.regions)

    def test_constants_match_appendix(self):
        self.assertEqual(rs.PERMUTATIONS, (("ABC", 5), ("BCA", 1), ("CAB", 7),
                                           ("ACB", 0), ("BAC", 6)))
        self.assertEqual(rs.HAIKU["max_tokens"], 8)
        self.assertEqual(rs.HAIKU["thinking"], "disabled")
        self.assertEqual(rs.HAIKU["temperature"], 1.0)
        self.assertEqual(rs.OPUS["max_tokens"], 4096)
        self.assertEqual(rs.OPUS["effort"], "medium")
        self.assertIsNone(rs.OPUS["temperature"])
        self.assertIsNone(rs.OPUS["thinking"])

    def test_seed_to_permutation_mapping(self):
        for perm, seed in rs.PERMUTATIONS:
            self.assertEqual("".join(rs.sampler.shuffled_order("ABC", seed)), perm)

    def test_decide_boundaries(self):
        self.assertEqual(rs.decide_haiku({"B": 4, "A": 1}), rs.RELEASE)
        self.assertEqual(rs.decide_haiku({"A": 4, "B": 1}), rs.TO_USER)
        self.assertEqual(rs.decide_haiku({"B": 3, "A": 2}), rs.TO_OPUS)
        self.assertEqual(rs.decide_haiku({"A": 3, "B": 1}), rs.TO_OPUS)
        self.assertEqual(rs.decide_haiku({"B": 3}), rs.TO_OPUS)
        self.assertEqual(rs.decide_opus({"B": 4}), rs.RELEASE)
        self.assertEqual(rs.decide_opus({"B": 3, "A": 2}), rs.TO_USER)
        self.assertEqual(rs.decide_opus({"B": 3}), rs.TO_USER)

    def test_pair_all_release_only(self):
        self.assertEqual(rs.decide_pair([rs.RELEASE, rs.RELEASE]), rs.RELEASE)
        self.assertEqual(rs.decide_pair([rs.RELEASE, rs.TO_USER]), rs.TO_USER)

    def test_flow_order_truncation_and_summary(self):
        # X1 全 B 放行；X2.1 全 A 交用戶；X2.2 含截斷轉 Opus；M9 全 C 轉 Opus
        haiku = (["B"] * 5 + ["A"] * 5 + ["B", "B", "B", ("B", "max_tokens"), "A"]
                 + ["C"] * 5)
        client = FakeClient(haiku, ["B"] * 5 + ["A"] * 5)
        _, s = self.run_with(client)
        models = [c["model"] for c in client.calls]
        self.assertEqual(models, ["claude-haiku-5-5"] * 20 + ["claude-opus-5-5"] * 10)
        self.assertEqual(s["regions"]["X2.region2"]["haiku_counts"], {"B": 3, "A": 1})
        self.assertEqual(s["regions"]["X2.region2"]["opus_decision"], rs.RELEASE)
        self.assertEqual(s["pairs"]["X1"]["verdict"], rs.RELEASE)
        self.assertEqual(s["pairs"]["X2"]["verdict"], rs.TO_USER)
        self.assertEqual(s["mirror_pairs"]["M9"]["verdict"], rs.TO_USER)
        self.assertNotIn("M9", s["pairs"])
        self.assertEqual(s["max_tokens_stops"]["claude-haiku-5-5"], 1)
        lines = (self.out / "results.jsonl").read_text().splitlines()
        self.assertEqual(len(lines), 30)
        first, last = json.loads(lines[0]), json.loads(lines[-1])
        self.assertEqual(first["thinking"], "disabled")
        self.assertIsNone(first["effort"])
        self.assertEqual(last["effort"], "medium")
        self.assertIsNone(last["temperature"])

    def test_opus_request_omits_temperature_and_thinking(self):
        client = FakeClient(["C"] * 20, ["B"] * 20)
        self.run_with(client)
        opus_call = [c for c in client.calls if "opus" in c["model"]][0]
        self.assertNotIn("thinking", opus_call.get("extra_body", {}))
        self.assertNotIn("temperature", opus_call.get("extra_body", {}))

    def test_position_table_counts(self):
        _, s = self.run_with(FakeClient(["B"] * 20))
        t = s["b_position_tables"]["claude-haiku-5-5"]
        self.assertEqual({k: v["chose_B"] for k, v in t.items()},
                         {"1": 8, "2": 4, "3": 8})

    def test_order_mismatch_fail_closed(self):
        calls = []

        def bad(client, model, q, opts, seed, **kw):
            calls.append(seed)
            rec = rs.sampler.sample_once(client, model, q, opts, seed, **kw)
            if len(calls) == 3:
                rec["option_order"] = ["C", "B", "A"]
            return rec
        client = FakeClient(["B"] * 20)
        with self.assertRaises(rs.OrderMismatch):
            rs.Runner(client, self.out, sample_fn=bad).run(self.regions)
        self.assertEqual(len(client.calls), 3)
        self.assertEqual(len((self.out / "results.jsonl").read_text().splitlines()), 2)
        mm = json.loads((self.out / rs.MISMATCH_NAME).read_text())
        self.assertEqual(mm["actual_order"], ["C", "B", "A"])

    def test_refuse_existing_results(self):
        self.out.mkdir()
        (self.out / "results.jsonl").write_text("keep")
        with self.assertRaises(FileExistsError):
            rs.Runner(FakeClient([]), self.out).run(self.regions)
        self.assertEqual((self.out / "results.jsonl").read_text(), "keep")


if __name__ == "__main__":
    unittest.main()
