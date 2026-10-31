# /// script
# requires-python = ">=3.10"
# dependencies = ["anthropic==1.17.0", "pillow==11.0.0"]
# ///
"""弱觀察者試水溫取樣（466〈試水溫取樣與評分規則〉）。

9 題 x orig/bad x K=5 = 90 次，zh 截圖，Haiku。API key 只經 sampler 讀環境變數。
用法：uv run --script run_experiment.py [--capture-root build/ux_capture] [--out-dir .]
"""
# i18n-exempt: 研究用 CLI 腳本，非 App UI；字串為 prompt 與診斷訊息
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "common"))
import sampler  # noqa: E402
import score  # noqa: E402

MODEL = "claude-haiku-5-5"
K = 5
TEMPERATURE = 1.0
MAX_TOKENS = 1
LOCALE = "zh"
VARIANTS = ("orig", "bad")  # 版本序 0、1
GRID_COLOR = (128, 128, 128)
GRID_ALPHA = 128  # 50% 不透明
LABEL_SIZE = 12
LABEL_INSET = 4
NOT_FOUND_REGION = "找不到"  # i18n-exempt
NOT_FOUND_NUMBER = "找不到或沒有"  # i18n-exempt

# (題代碼, 目錄代碼, 類型, 題型, 問句, 數字題單位, 預期正解)
QUESTIONS = [
    ("T-A", "T-A", "A1", "region", "想看這些需求往下拆出的工作單，要按哪個位置？", None, None),  # i18n-exempt
    ("T-B", "T-B", "B", "region", "哪一個項目緊接在最上層需求的下一層？", None, None),  # i18n-exempt
    ("T-C'", "T-C", "C'", "number", "這棵樹裡一共有幾處往下接不到後續的地方？", "處", 3),  # i18n-exempt
    ("G-A", "G-A", "A1", "region", "想讓這頁照最新的內容再查核一遍，要按哪個位置？", None, None),  # i18n-exempt
    ("G-B", "G-B", "B", "number", "由上往下數，第二個分組底下共列了幾條？", "條", 4),  # i18n-exempt
    ("G-C'", "G-C", "C'", "region", "要把整個分組收起來，要按哪個位置？", None, None),  # i18n-exempt
    ("K-A", "K-A", "A2", "region", "只想留下還沒動工的那幾張，要按哪個位置？", None, None),  # i18n-exempt
    ("K-B", "K-B", "B", "region", "單號 0.1.0-W2-006 那一張排在哪一組底下？", None, None),  # i18n-exempt
    ("K-C'", "K-C", "C'", "number", "這一頁裡有幾張單子的內容讀不出來？", "張", 3),  # i18n-exempt
]


def region_options():
    """A–P 加 0（找不到），共 17 個代碼。"""
    options = {}
    for i, code in enumerate(score.CELL_CODES):
        options[code] = f"第 {i // score.GRID + 1} 列第 {i % score.GRID + 1} 欄的格子"  # i18n-exempt
    options[score.NOT_FOUND] = NOT_FOUND_REGION
    return options


def number_options(unit):
    options = {str(n): f"{n} {unit}" for n in range(1, 10)}  # i18n-exempt
    options[score.NOT_FOUND] = NOT_FOUND_NUMBER
    return options


def seed_for(question_idx, variant_idx, sample_idx):
    """題序 1–9 x 100 + 版本序 x 10 + 取樣序。"""
    return (question_idx + 1) * 100 + variant_idx * 10 + sample_idx


def find_answers_path(capture_root, dir_code, variant):
    """build/ux_capture/<代碼>_<版本>/<畫面>/zh.answers.json；畫面目錄須唯一。"""
    hits = sorted((Path(capture_root) / f"{dir_code}_{variant}").glob(
        f"*/{LOCALE}.answers.json"))
    if len(hits) != 1:
        raise FileNotFoundError(  # i18n-exempt
            f"{dir_code}_{variant} 找到 {len(hits)} 份 answers.json")  # i18n-exempt
    return hits[0]


def build_overlay(png_bytes):
    """4x4 格線（1px #808080、50%）與 A–P 標籤（12px，白邊）；回傳 PNG bytes。"""
    from PIL import Image, ImageDraw, ImageFont

    base = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    line = GRID_COLOR + (GRID_ALPHA,)
    for i in range(1, score.GRID):
        draw.line([(i * score.CELL_W, 0), (i * score.CELL_W, base.height)], fill=line)
        draw.line([(0, i * score.CELL_H), (base.width, i * score.CELL_H)], fill=line)
    font = ImageFont.load_default(size=LABEL_SIZE)
    for i, code in enumerate(score.CELL_CODES):
        x = (i % score.GRID) * score.CELL_W + LABEL_INSET
        y = (i // score.GRID) * score.CELL_H + LABEL_INSET
        draw.text((x, y), code, font=font, fill=GRID_COLOR + (255,),
                  stroke_width=1, stroke_fill=(255, 255, 255, 255))
    out = io.BytesIO()
    Image.alpha_composite(base, layer).convert("RGB").save(out, "PNG")
    return out.getvalue()


def _check_edge(png_bytes, max_edge, label):
    if max_edge is None:
        return
    from PIL import Image

    size = Image.open(io.BytesIO(png_bytes)).size
    if max(size) > max_edge:
        raise ValueError(f"{label} 圖片 {size} 超過上限邊長 {max_edge}，停手回報")  # i18n-exempt


def prepare_cell(capture_root, question, variant, overlay_dir, max_edge=None):
    """讀 answers.json 與 zh.png，回傳 (圖路徑, sha256, 選項, 正解集合, 寬容, 基準)。"""
    code, dir_code, _, kind, _, unit, expected = question
    answers_path = find_answers_path(capture_root, dir_code, variant)
    answers = json.loads(answers_path.read_text(encoding="utf-8"))
    png_path = answers_path.with_name(f"{LOCALE}.png")
    if kind == "region":
        correct, tolerant, baseline = score.region_truth(answers)
        data = build_overlay(png_path.read_bytes())
        options = region_options()
    else:
        correct, tolerant, baseline = score.number_truth(answers)
        if correct != {str(expected)}:
            raise ValueError(f"{code}/{variant} 正解 {correct} 與凍結版 {expected} 不符")  # i18n-exempt
        data = png_path.read_bytes()
        options = number_options(unit)
    _check_edge(data, max_edge, f"{code}/{variant}")
    out_path = Path(overlay_dir) / f"{dir_code}_{variant}.png"
    out_path.write_bytes(data)
    return out_path, hashlib.sha256(data).hexdigest(), options, correct, tolerant, baseline


def build_row(question, variant, sample_idx, cell, record):
    _, digest, _, correct, tolerant, baseline = cell
    return {
        "question": question[0], "type": question[2], "kind": question[3],
        "variant": variant, "sample": sample_idx, "seed": record["seed"],
        "image_sha256": digest, "option_order": record["option_order"],
        "raw_reply": record["raw_reply"], "parsed": record["parsed"],
        "stop_reason": record["stop_reason"], "model": record["model"],
        "usage": record["usage"], "correct": sorted(correct),
        "boundary_tolerant": tolerant, "chance_baseline": baseline,
        "verdict": score.judge(record["parsed"], correct),
    }


def run(client, capture_root, out_dir, max_edge=None):
    """跑完 90 次並寫入 dataset.jsonl；已存在則拒絕覆蓋。"""
    out_dir = Path(out_dir)
    dataset = out_dir / "dataset.jsonl"
    if dataset.exists():
        raise FileExistsError(f"{dataset} 已存在；取樣規則已預先登記，不覆蓋")  # i18n-exempt
    overlay_dir = out_dir / "images"
    overlay_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for qi, question in enumerate(QUESTIONS):
        for vi, variant in enumerate(VARIANTS):
            cell = prepare_cell(capture_root, question, variant, overlay_dir, max_edge)
            for si in range(K):
                record = sampler.sample_once(
                    client, MODEL, question[4], cell[2], seed_for(qi, vi, si),
                    max_tokens=MAX_TOKENS, temperature=TEMPERATURE,
                    image_paths=[cell[0]])
                rows.append(build_row(question, variant, si, cell, record))
    with dataset.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    return rows


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--capture-root", default="build/ux_capture")
    p.add_argument("--out-dir", default=str(Path(__file__).parent))
    p.add_argument("--max-edge", type=int, default=None)
    args = p.parse_args(argv)
    rows = run(sampler.make_client(), args.capture_root, args.out_dir, args.max_edge)
    print(f"[OK] 寫入 {len(rows)} 筆")  # i18n-exempt


if __name__ == "__main__":
    main()
