# /// script
# requires-python = ">=3.10"
# ///
"""弱觀察者試水溫的正解與評分規則（466〈試水溫取樣與評分規則〉＋〈寬目標改用標題錨點〉）。

run_experiment.py 匯入本檔的判定函式；直接執行本檔則由 dataset.jsonl 重算全部數字。
用法：python score.py dataset.jsonl
"""
# i18n-exempt: 研究用 CLI 腳本，非 App UI；字串為報告與診斷訊息
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "common"))
import sampler  # noqa: E402

GRID = 4
CELL_W, CELL_H = 320, 200
TOLERANCE_PX = 16  # 規則 2：中心點距內部格線 16px 內，相鄰格也算對
WIDE_TARGET_PX = 320  # 寬度超過一格即改用標題錨點
CELL_CODES = [chr(ord("A") + i) for i in range(GRID * GRID)]
NOT_FOUND = "0"
REGION_OPTION_COUNT = 17  # A–P 加「找不到」
NUMBER_OPTION_COUNT = 10  # 0–9
UNPARSEABLE_LIMIT = 1  # 規則 4：5 次中超過 1 次無法解析 → 不可判
FAIL_THRESHOLD = 4  # 規則 5：答錯加找不到至少 4/5 → 題級失敗
PASS_A_MIN = 4  # 條件 (a)
PASS_B_MIN_TYPES = 2  # 條件 (b)
PASS_C_MAX_ORIG_FAIL = 1  # 條件 (c)

CORRECT = "對"  # i18n-exempt
WRONG = "錯"  # i18n-exempt
NOT_FOUND_V = "找不到"  # i18n-exempt
UNPARSEABLE = "不可解析"  # i18n-exempt
STATUS_UNDECIDABLE = "不可判"  # i18n-exempt
STATUS_FAIL = "失敗"  # i18n-exempt
STATUS_PASS = "通過"  # i18n-exempt
USAGE = "用法：python score.py dataset.jsonl"  # i18n-exempt


def _axis_cells(coord, size, count):
    """單軸正解格：所在格；距內部格線 TOLERANCE_PX 內時加相鄰格。回傳 (集合, 是否寬容)。"""
    idx = min(int(coord // size), count - 1)  # 落在格線上取右下方格（floor）
    cells = {idx}
    tolerant = False
    if idx > 0 and coord - idx * size <= TOLERANCE_PX:
        cells.add(idx - 1)
        tolerant = True
    if idx < count - 1 and (idx + 1) * size - coord <= TOLERANCE_PX:
        cells.add(idx + 1)
        tolerant = True
    return cells, tolerant


def point_cells(x, y):
    """點所對應的正解格代碼集合與是否套用邊界寬容。"""
    cols, tol_x = _axis_cells(x, CELL_W, GRID)
    rows, tol_y = _axis_cells(y, CELL_H, GRID)
    codes = {CELL_CODES[r * GRID + c] for r in rows for c in cols}
    return codes, tol_x or tol_y


def _center(rect):
    x, y, w, h = rect
    return x + w / 2, y + h / 2


def target_point(target):
    """目標判定點：寬度 <= 320 取 bbox 中心；較寬取標題錨點中心（無錨點則報錯）。"""
    rect = target["rect"]
    if rect[2] <= WIDE_TARGET_PX:
        return _center(rect)
    anchor = target.get("anchor")
    if not anchor:
        raise ValueError(f"寬目標 {target.get('key')} 缺 anchor，無法決定正解格")
    return _center(anchor["rect"])


def region_truth(answers):
    """區域題正解：回傳 (正解集合, 是否邊界寬容, 隨機猜中基準)。多目標取聯集。"""
    codes, tolerant = set(), False
    for target in answers["targets"]:
        cells, tol = point_cells(*target_point(target))
        codes |= cells
        tolerant = tolerant or tol
    return codes, tolerant, len(codes) / REGION_OPTION_COUNT


def number_truth(answers):
    return {str(answers["value"])}, False, 1 / NUMBER_OPTION_COUNT


def judge(parsed, correct):
    """單次判定：對／錯／找不到／不可解析。"""
    if parsed is None:
        return UNPARSEABLE
    if parsed == NOT_FOUND:
        return NOT_FOUND_V
    return CORRECT if parsed in correct else WRONG


def cell_status(verdicts):
    """同題同版本的取樣判定 → 格級結果（fail 為 None 表示不可判）。"""
    if verdicts.count(UNPARSEABLE) > UNPARSEABLE_LIMIT:
        return {"status": STATUS_UNDECIDABLE, "fail": None}
    failures = verdicts.count(WRONG) + verdicts.count(NOT_FOUND_V)
    failed = failures >= FAIL_THRESHOLD
    return {"status": STATUS_FAIL if failed else STATUS_PASS, "fail": failed}


def reparse(row):
    """依預登記規則由 raw_reply 重算；不讀 dataset 的 parsed／verdict 欄。"""
    return sampler.parse_reply(row["raw_reply"], row["option_order"])


def load_dataset(path):
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def summarize(rows):
    """由資料列重算題級結果與 (a)(b)(c)；判定一律由 raw_reply 經 sampler.parse_reply 重算。"""
    grouped = defaultdict(list)
    types = {}
    for r in rows:
        grouped[(r["question"], r["variant"])].append(
            judge(reparse(r), set(r["correct"])))
        types[r["question"]] = r["type"]
    questions = {}
    for q in sorted(types):
        questions[q] = {
            "type": types[q],
            "orig": cell_status(grouped[(q, "orig")]),
            "bad": cell_status(grouped[(q, "bad")]),
            "orig_verdicts": grouped[(q, "orig")],
            "bad_verdicts": grouped[(q, "bad")],
        }
    return {"questions": questions, "conditions": _conditions(questions),
            "not_found_rate": _not_found_rate(rows)}


def _diff_questions(questions, orig_fail, bad_fail):
    return [q for q, v in questions.items()
            if v["orig"]["fail"] is orig_fail and v["bad"]["fail"] is bad_fail]


def _conditions(questions):
    forward = _diff_questions(questions, False, True)  # 原版通過、壞版失敗
    reverse = _diff_questions(questions, True, False)
    kinds = {"A" if questions[q]["type"] in ("A1", "A2") else questions[q]["type"]
             for q in forward}  # A1、A2 合併算 1 種
    orig_fail = sum(1 for v in questions.values() if v["orig"]["fail"] is True)
    undecidable = [f"{q}/{ver}" for q, v in questions.items()
                   for ver in ("orig", "bad") if v[ver]["fail"] is None]
    return {
        "a": {"forward": forward, "reverse": reverse,
              "pass": len(forward) >= PASS_A_MIN and not reverse},
        "b": {"types": sorted(kinds), "pass": len(kinds) >= PASS_B_MIN_TYPES},
        "c": {"orig_fail": orig_fail, "pass": orig_fail <= PASS_C_MAX_ORIG_FAIL},
        "undecidable": undecidable,
    }


def _not_found_rate(rows):
    total, hit = defaultdict(int), defaultdict(int)
    for r in rows:
        total[r["variant"]] += 1
        hit[r["variant"]] += reparse(r) == NOT_FOUND
    return {v: hit[v] / total[v] for v in total}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        sys.exit(USAGE)
    print(json.dumps(summarize(load_dataset(argv[0])), ensure_ascii=False,
                     indent=2))


if __name__ == "__main__":
    main()
