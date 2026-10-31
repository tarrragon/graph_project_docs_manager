"""run_experiment／score 的離線測試：假 client，不連網、不設任何 key。

執行：uv run --with pytest --with pillow==11.0.0 pytest docs/research/weak-observer-ux/test_run_experiment.py
"""
# i18n-exempt: 研究用測試，非 App UI
import hashlib
import io
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import run_experiment as rx  # noqa: E402
import score  # noqa: E402


# ---------- 假資料 ----------

NARROW = {"key": "k", "rect": [10, 10, 100, 50]}  # 中心 (60, 35) -> A
WIDE_WITH_ANCHOR = {"key": "w", "rect": [100, 300, 1020, 60],  # 中心在 K 一帶
                    "anchor": {"text": "t", "rect": [110, 310, 100, 20]}}  # 中心 (160, 320) -> E
WIDE_NO_ANCHOR = {"key": "w", "rect": [100, 300, 1020, 60]}


def _png_bytes(size=(1280, 800)):
    from PIL import Image

    out = io.BytesIO()
    Image.new("RGB", size, (240, 240, 240)).save(out, "PNG")
    return out.getvalue()


def _answers_for(question):
    code, _, _, kind, _, _, expected = question
    if kind == "number":
        return {"value": expected}
    if code == "T-B":
        return {"targets": [WIDE_WITH_ANCHOR]}
    if code == "G-C'":
        return {"targets": [NARROW, {"key": "k2", "rect": [700, 500, 100, 50]}]}
    return {"targets": [NARROW]}


@pytest.fixture
def capture_root(tmp_path):
    root = tmp_path / "ux_capture"
    for q in rx.QUESTIONS:
        for variant in rx.VARIANTS:
            d = root / f"{q[1]}_{variant}" / "screen"
            d.mkdir(parents=True)
            (d / "zh.png").write_bytes(_png_bytes())
            (d / "zh.answers.json").write_text(json.dumps(_answers_for(q)))
    return root


class FakeClient:
    def __init__(self, reply="A"):
        self.reply = reply
        self.calls = []
        self.messages = SimpleNamespace(create=self._create)

    def _create(self, *, model, max_tokens, messages, extra_body=None):
        self.calls.append({"model": model, "max_tokens": max_tokens,
                           "extra_body": extra_body})
        return SimpleNamespace(
            model=model, stop_reason="end_turn",
            content=[SimpleNamespace(type="text", text=self.reply)],
            usage=SimpleNamespace(input_tokens=10, output_tokens=1))


# ---------- 正解格 ----------

def test_point_in_cell_interior():
    assert score.point_cells(160, 100) == ({"A"}, False)


def test_point_on_grid_line_takes_lower_right_cell():
    codes, _ = score.point_cells(320, 200)
    assert "F" in codes  # 右下方格
    assert score.point_cells(320, 100)[0] >= {"B"}


def test_boundary_tolerance_adds_adjacent_cell():
    codes, tolerant = score.point_cells(320 + 16, 100)
    assert codes == {"A", "B"} and tolerant
    codes, tolerant = score.point_cells(320 + 17, 100)
    assert codes == {"B"} and not tolerant


def test_clamps_to_last_cell():
    assert score.point_cells(1280, 800)[0] == {"P"}


def test_narrow_target_uses_bbox_center():
    assert score.target_point(NARROW) == (60, 35)


def test_wide_target_uses_anchor_center():
    assert score.target_point(WIDE_WITH_ANCHOR) == (160, 320)
    assert score.region_truth({"targets": [WIDE_WITH_ANCHOR]})[0] == {"E"}


def test_width_exactly_one_cell_is_not_wide():
    rect = [0, 0, 320, 40]
    assert score.target_point({"key": "x", "rect": rect}) == (160, 20)


def test_wide_target_without_anchor_raises():
    with pytest.raises(ValueError):
        score.region_truth({"targets": [WIDE_NO_ANCHOR]})


def test_multi_target_union_and_baseline():
    ans = {"targets": [NARROW, {"key": "b", "rect": [700, 500, 100, 50]}]}
    codes, tolerant, baseline = score.region_truth(ans)
    assert codes == {"A", "K"} and not tolerant
    assert baseline == pytest.approx(2 / 17)


def test_tolerant_baseline_uses_correct_cell_count():
    ans = {"targets": [{"key": "a", "rect": [326, 80, 20, 20]}]}  # 中心 x=336
    codes, tolerant, baseline = score.region_truth(ans)
    assert codes == {"A", "B"} and tolerant
    assert baseline == pytest.approx(2 / 17)


def test_number_truth():
    assert score.number_truth({"value": 3}) == ({"3"}, False, 0.1)


# ---------- 判定與題級 ----------

def test_judge_four_outcomes():
    assert score.judge("A", {"A"}) == score.CORRECT
    assert score.judge("B", {"A"}) == score.WRONG
    assert score.judge("0", {"A"}) == score.NOT_FOUND_V
    assert score.judge(None, {"A"}) == score.UNPARSEABLE


def test_cell_status_threshold_counts_wrong_plus_not_found():
    v = [score.WRONG, score.WRONG, score.NOT_FOUND_V, score.WRONG, score.CORRECT]
    assert score.cell_status(v)["fail"] is True
    v = [score.WRONG, score.WRONG, score.NOT_FOUND_V, score.CORRECT, score.CORRECT]
    assert score.cell_status(v)["fail"] is False


def test_cell_status_undecidable_when_two_unparseable():
    v = [score.UNPARSEABLE] * 2 + [score.WRONG] * 3
    assert score.cell_status(v)["fail"] is None
    v = [score.UNPARSEABLE] + [score.WRONG] * 4
    assert score.cell_status(v)["fail"] is True  # 恰 1 次不可解析仍可判


def _rows(question, qtype, variant, verdict_parsed):
    return [{"question": question, "type": qtype, "variant": variant,
             "parsed": p, "correct": ["A"]} for p in verdict_parsed]


def _pair(question, qtype, orig_pass, bad_pass):
    good, bad = ["A"] * 5, ["B"] * 5
    return (_rows(question, qtype, "orig", good if orig_pass else bad)
            + _rows(question, qtype, "bad", good if bad_pass else bad))


def test_conditions_pass():
    rows = []
    for q, t in [("q1", "A1"), ("q2", "A2"), ("q3", "B"), ("q4", "C'")]:
        rows += _pair(q, t, True, False)
    rows += _pair("q5", "B", True, True)
    cond = score.summarize(rows)["conditions"]
    assert cond["a"]["pass"] and cond["b"]["pass"] and cond["c"]["pass"]
    assert cond["b"]["types"] == ["A", "B", "C'"]


def test_condition_b_merges_a1_a2_into_one_type():
    rows = []
    for q, t in [("q1", "A1"), ("q2", "A2"), ("q3", "A1"), ("q4", "A2")]:
        rows += _pair(q, t, True, False)
    cond = score.summarize(rows)["conditions"]
    assert cond["a"]["pass"] and not cond["b"]["pass"]


def test_condition_a_fails_on_reverse_question():
    rows = []
    for q in ["q1", "q2", "q3", "q4"]:
        rows += _pair(q, "B", True, False)
    rows += _pair("q5", "B", False, True)
    cond = score.summarize(rows)["conditions"]
    assert cond["a"]["reverse"] == ["q5"] and not cond["a"]["pass"]


def test_condition_c_fails_when_two_orig_fail():
    rows = _pair("q1", "B", False, False) + _pair("q2", "B", False, False)
    assert not score.summarize(rows)["conditions"]["c"]["pass"]


def test_undecidable_cell_excluded_from_numerator():
    rows = _rows("q1", "B", "orig", ["A"] * 5)
    rows += _rows("q1", "bad", "bad", [None, None, "B", "B", "B"])
    cond = score.summarize(rows)["conditions"]
    assert cond["a"]["forward"] == [] and cond["undecidable"] == ["q1/bad"]


# ---------- 取樣協定 ----------

def test_seed_formula():
    assert rx.seed_for(0, 0, 0) == 100
    assert rx.seed_for(8, 1, 4) == 914


def test_questions_table_matches_frozen_catalog():
    assert [q[0] for q in rx.QUESTIONS] == [
        "T-A", "T-B", "T-C'", "G-A", "G-B", "G-C'", "K-A", "K-B", "K-C'"]
    assert [q[3] for q in rx.QUESTIONS].count("number") == 3


def test_option_sets():
    region = rx.region_options()
    assert len(region) == 17 and region["0"] == "找不到" and region["P"].startswith("第 4 列第 4 欄")
    number = rx.number_options("處")
    assert len(number) == 10 and number["0"] == "找不到或沒有" and number["3"] == "3 處"


def test_number_question_units_follow_question_wording():
    units = {q[0]: rx.number_options(q[5])["3"] for q in rx.QUESTIONS
             if q[3] == "number"}
    assert units == {"T-C'": "3 處", "G-B": "3 條", "K-C'": "3 張"}


def test_overlay_keeps_size_and_changes_pixels():
    from PIL import Image

    original = _png_bytes()
    overlaid = rx.build_overlay(original)
    assert overlaid != original
    assert Image.open(io.BytesIO(overlaid)).size == (1280, 800)
    assert rx.build_overlay(original) == overlaid  # 決定性，sha256 可重現


def test_find_answers_path_requires_single_screen(capture_root):
    extra = capture_root / "T-A_orig" / "other"
    extra.mkdir()
    (extra / "zh.answers.json").write_text("{}")
    with pytest.raises(FileNotFoundError):
        rx.find_answers_path(capture_root, "T-A", "orig")


def test_number_truth_mismatch_with_frozen_value_raises(capture_root, tmp_path):
    path = rx.find_answers_path(capture_root, "T-C", "bad")
    path.write_text(json.dumps({"value": 7}))
    q = next(q for q in rx.QUESTIONS if q[0] == "T-C'")
    with pytest.raises(ValueError):
        rx.prepare_cell(capture_root, q, "bad", tmp_path)


def test_max_edge_guard(capture_root, tmp_path):
    q = rx.QUESTIONS[0]
    with pytest.raises(ValueError):
        rx.prepare_cell(capture_root, q, "orig", tmp_path, max_edge=1000)


# ---------- 端到端（假 client） ----------

def test_run_produces_90_rows_with_registered_seeds(capture_root, tmp_path):
    client = FakeClient("A")
    rows = rx.run(client, capture_root, tmp_path)
    assert len(rows) == 90 and len(client.calls) == 90
    assert {c["model"] for c in client.calls} == {"claude-haiku-5-5"}
    assert all(c["max_tokens"] == 1 and c["extra_body"] == {
        "temperature": 1.0, "thinking": {"type": "disabled"}}
               for c in client.calls)
    assert sorted(r["seed"] for r in rows)[:2] == [100, 101]
    assert len({r["seed"] for r in rows}) == 90
    first = rows[0]
    assert first["question"] == "T-A" and first["variant"] == "orig"
    assert first["correct"] == ["A"] and first["verdict"] == score.CORRECT


def test_run_sends_thinking_disabled_and_omitting_it_differs(capture_root, tmp_path):
    """E1 對照：同一 fixture，run() 送 thinking disabled；不傳 thinking 則 extra_body 不同。"""
    sent = FakeClient("A")
    rx.run(sent, capture_root, tmp_path)
    assert all(c["extra_body"]["thinking"] == {"type": "disabled"} for c in sent.calls)
    assert all("effort" not in c["extra_body"] and "output_config" not in c["extra_body"]
               for c in sent.calls)

    q = rx.QUESTIONS[0]
    cell = rx.prepare_cell(capture_root, q, rx.VARIANTS[0], tmp_path / "images")
    omitted = FakeClient("A")
    rx.sampler.sample_once(omitted, rx.MODEL, q[4], cell[2], 100,
                           max_tokens=rx.MAX_TOKENS, temperature=rx.TEMPERATURE,
                           image_paths=[cell[0]])
    assert "thinking" not in omitted.calls[0]["extra_body"]
    assert omitted.calls[0]["extra_body"] != sent.calls[0]["extra_body"]


def test_run_records_image_sha256_of_sent_bytes(capture_root, tmp_path):
    rows = rx.run(FakeClient("A"), capture_root, tmp_path)
    sent = (tmp_path / "images" / "T-A_orig.png").read_bytes()
    assert rows[0]["image_sha256"] == hashlib.sha256(sent).hexdigest()


def test_run_refuses_to_overwrite_dataset(capture_root, tmp_path):
    rx.run(FakeClient("A"), capture_root, tmp_path)
    with pytest.raises(FileExistsError):
        rx.run(FakeClient("A"), capture_root, tmp_path)


def test_dataset_recomputes_to_same_numbers(capture_root, tmp_path):
    rows = rx.run(FakeClient("A"), capture_root, tmp_path)
    loaded = score.load_dataset(tmp_path / "dataset.jsonl")
    assert loaded == json.loads(json.dumps(rows))
    summary = score.summarize(loaded)
    # 一律答 A：區域題答 A 的格全對（G-C'/T-B 正解不含 A 者除外），數字題 A 無法解析
    assert summary["questions"]["T-A"]["orig"]["status"] == "通過"
    assert summary["questions"]["T-B"]["orig"]["fail"] is True  # 正解 E，答 A 為錯
    assert summary["questions"]["T-C'"]["orig"]["fail"] is None  # 5 次皆不可解析


def test_unparseable_reply_recorded_not_dropped(capture_root, tmp_path):
    rows = rx.run(FakeClient("zzz"), capture_root, tmp_path)
    assert len(rows) == 90 and all(r["parsed"] is None for r in rows)
    assert all(r["verdict"] == score.UNPARSEABLE for r in rows)


# ---------- 衛生 ----------

def test_sources_do_not_mention_foreign_key_name():
    banned = "ANTHROPIC" + "_API_KEY"
    own = [HERE / n for n in ("run_experiment.py", "score.py", "test_run_experiment.py")]
    assert all(banned not in p.read_text(encoding="utf-8") for p in own)
