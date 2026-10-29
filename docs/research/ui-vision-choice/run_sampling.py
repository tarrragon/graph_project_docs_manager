"""465 取樣執行器：依 judgment-rules.md〈附錄：取樣協議〉兩階段取樣並彙整判定。

用法：python3 run_sampling.py --out <輸出目錄>（key 由 sampler.make_client 讀環境變數）
"""
# i18n-exempt: 研究用 CLI 腳本，非 App UI；字串為 prompt 與診斷訊息
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "common"))
import sampler  # noqa: E402

QUESTION = (
    "以上兩張圖是同一個 App 畫面在程式修改前後、同一位置的裁切。"  # i18n-exempt
    "第一張是「基準」（修改前），第二張是「新」（修改後）。"  # i18n-exempt
    "請判斷新圖相對於基準圖的變化屬於哪一種。"  # i18n-exempt
)
OPTIONS = {
    "A": "缺陷：變化使畫面顯示錯誤，例如文字被裁切、元素重疊或錯位、對比不足",  # i18n-exempt
    "B": "預期修改：變化是刻意的設計調整，畫面仍正確",  # i18n-exempt
    "C": "無法判斷：無法從兩張圖判斷",  # i18n-exempt
}
# (排列, seed)：附錄〈選項順序〉表，所有區塊共用
PERMUTATIONS = (("ABC", 5), ("BCA", 1), ("CAB", 7), ("ACB", 0), ("BAC", 6))
HAIKU = {"model": "claude-haiku-5-5", "temperature": 1.0, "thinking": "disabled",
         "effort": None, "max_tokens": 8}
OPUS = {"model": "claude-opus-5-5", "temperature": None, "thinking": None,
        "effort": "medium", "max_tokens": 4096}
THRESHOLD = 4
RELEASE, TO_USER, TO_OPUS = "放行", "交用戶", "轉Opus"  # i18n-exempt
RESULTS_NAME = "results.jsonl"
SUMMARY_NAME = "summary.json"
MISMATCH_NAME = "order_mismatch.json"


class OrderMismatch(Exception):
    """option_order 與該 seed 預期排列不符（fail-closed）。"""


def load_regions(dataset_path):
    """每個 crop 為一個區塊（region 從 1 起），回傳 [{code, kind, region, paths}]。"""
    regions = []
    base_dir = Path(dataset_path).parent
    for line in Path(dataset_path).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        for i, crop in enumerate(row["crops"], start=1):
            paths = [base_dir / crop["base_path"], base_dir / crop["new_path"]]
            regions.append({"code": row["code"], "kind": row["kind"],
                            "region": i, "paths": paths})
    return regions


def decide_haiku(counts):
    if counts.get("B", 0) >= THRESHOLD:
        return RELEASE
    if counts.get("A", 0) >= THRESHOLD:
        return TO_USER
    return TO_OPUS


def decide_opus(counts):
    return RELEASE if counts.get("B", 0) >= THRESHOLD else TO_USER


def decide_pair(region_finals):
    return RELEASE if all(f == RELEASE for f in region_finals) else TO_USER


def _record(region, params, rec):
    return {
        "code": region["code"], "region": region["region"],
        "model": params["model"], "seed": rec["seed"],
        "option_order": rec["option_order"], "raw_reply": rec["raw_reply"],
        "parsed": rec["parsed"], "stop_reason": rec["stop_reason"],
        "usage": rec["usage"], "temperature": params["temperature"],
        "thinking": params["thinking"], "effort": params["effort"],
        "max_tokens": params["max_tokens"],
    }


class Runner:
    def __init__(self, client, out_dir, sample_fn=sampler.sample_once):
        self.client, self.out_dir, self.sample_fn = client, Path(out_dir), sample_fn
        self.rows = []

    def _call(self, region, params, seed, out_file):
        rec = self.sample_fn(
            self.client, params["model"], QUESTION, OPTIONS, seed,
            max_tokens=params["max_tokens"], temperature=params["temperature"],
            image_paths=region["paths"], thinking=params["thinking"],
            effort=params["effort"])
        expected = sampler.shuffled_order(OPTIONS, seed)
        if rec["option_order"] != expected:
            self._save_mismatch(region, params, seed, expected, rec)
            raise OrderMismatch(f"{region['code']} r{region['region']} seed={seed}")
        row = _record(region, params, rec)
        out_file.write(json.dumps(row, ensure_ascii=False) + "\n")
        out_file.flush()
        self.rows.append(row)
        return row

    def _save_mismatch(self, region, params, seed, expected, rec):
        data = {"code": region["code"], "region": region["region"],
                "model": params["model"], "seed": seed,
                "expected_order": expected, "actual_order": rec["option_order"]}
        (self.out_dir / MISMATCH_NAME).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def _stage(self, regions, params, out_file):
        counts = {}
        for r in regions:
            key = (r["code"], r["region"])
            rows = [self._call(r, params, seed, out_file) for _, seed in PERMUTATIONS]
            counts[key] = dict(Counter(x["parsed"] for x in rows if x["parsed"]))
        return counts

    def run(self, regions):
        self.out_dir.mkdir(parents=True, exist_ok=True)
        path = self.out_dir / RESULTS_NAME
        if path.exists():
            raise FileExistsError(f"{path} exists: refuse to overwrite or resume")
        with open(path, "x", encoding="utf-8") as f:
            haiku = self._stage(regions, HAIKU, f)
            routed = [r for r in regions
                      if decide_haiku(haiku[(r["code"], r["region"])]) == TO_OPUS]
            opus = self._stage(routed, OPUS, f)
        summary = build_summary(regions, haiku, opus, self.rows)
        (self.out_dir / SUMMARY_NAME).write_text(
            json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
        return summary


def _position_table(rows, model):
    """B 的位置（option_order 內 1 起）× 是否選 B。"""
    table = {str(p): {"chose_B": 0, "not_B": 0, "unparsed": 0} for p in (1, 2, 3)}
    for row in (r for r in rows if r["model"] == model):
        cell = table[str(row["option_order"].index("B") + 1)]
        if row["parsed"] is None:
            cell["unparsed"] += 1
        else:
            cell["chose_B" if row["parsed"] == "B" else "not_B"] += 1
    return table


def build_summary(regions, haiku, opus, rows):
    region_info, finals = {}, {}
    for r in regions:
        key = (r["code"], r["region"])
        h = decide_haiku(haiku[key])
        entry = {"kind": r["kind"], "haiku_counts": haiku[key], "haiku_decision": h,
                 "opus_counts": None, "opus_decision": None}
        final = h
        if h == TO_OPUS:
            entry["opus_counts"] = opus[key]
            final = entry["opus_decision"] = decide_opus(opus[key])
        entry["final"] = final
        region_info[f"{r['code']}.region{r['region']}"] = entry
        finals.setdefault(r["code"], []).append((r["kind"], final))
    pairs = {c: {"kind": v[0][0], "verdict": decide_pair([f for _, f in v])}
             for c, v in finals.items()}
    return {
        "regions": region_info,
        "pairs": {c: p for c, p in pairs.items() if p["kind"] != "mirror"},
        "mirror_pairs": {c: p for c, p in pairs.items() if p["kind"] == "mirror"},
        "max_tokens_stops": {m["model"]: sum(
            1 for x in rows if x["model"] == m["model"]
            and x["stop_reason"] == "max_tokens") for m in (HAIKU, OPUS)},
        "b_position_tables": {m["model"]: _position_table(rows, m["model"])
                              for m in (HAIKU, OPUS)},
    }


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", required=True)
    p.add_argument("--dataset", default=str(HERE / "dataset" / "dataset.jsonl"))
    args = p.parse_args(argv)
    if (Path(args.out) / RESULTS_NAME).exists():
        sys.stderr.write(f"[ERROR] {args.out}/{RESULTS_NAME} exists, refuse to run\n")
        return 1
    runner = Runner(sampler.make_client(), args.out)
    try:
        runner.run(load_regions(args.dataset))
    except OrderMismatch as e:
        sys.stderr.write(f"[ERROR] option_order mismatch, stopped: {e}\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
