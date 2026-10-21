"""pixel_diff / geometry_check 的測試（含正向對照，E2）。"""
import json
import tempfile
import unittest
from pathlib import Path

import geometry_check as gc
import pixel_diff as pd


def solid(w, h, rgb=(255, 255, 255)):
    return pd.Image(w, h, [bytes(rgb) * w for _ in range(h)])


def paint(img, x, y, w, h, rgb):
    for r in range(y, y + h):
        row = bytearray(img.rows[r])
        row[x * 3:(x + w) * 3] = bytes(rgb) * w
        img.rows[r] = bytes(row)


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


if __name__ == "__main__":
    unittest.main()
