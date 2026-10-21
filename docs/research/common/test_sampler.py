"""sampler 的離線測試：以假 client 執行，不連網。"""
import base64
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).parent))
import sampler  # noqa: E402


class FakeClient:
    def __init__(self, replies, model="claude-fake-1"):
        self.replies = list(replies)
        self.calls = []
        self.messages = SimpleNamespace(create=self._create)
        self.model = model

    def _create(self, *, model, max_tokens, messages, extra_body=None):
        # 簽章比照 SDK 1.17.0：不接受 temperature 關鍵字參數
        kwargs = {"model": model, "max_tokens": max_tokens, "messages": messages}
        if extra_body is not None:
            kwargs["extra_body"] = extra_body
        self.calls.append(kwargs)
        text = self.replies[(len(self.calls) - 1) % len(self.replies)]
        return SimpleNamespace(
            model=self.model,
            content=[SimpleNamespace(text=text)] if text is not None else [],
            usage=SimpleNamespace(input_tokens=11, output_tokens=1),
        )


OPTIONS = {"A": "alpha", "B": "beta", "C": "gamma"}


def test_parse_reply():
    assert sampler.parse_reply("B", ["A", "B"]) == "B"
    assert sampler.parse_reply(" a\n", ["A", "B"]) == "A"
    assert sampler.parse_reply("Z", ["A", "B"]) is None
    assert sampler.parse_reply("", ["A", "B"]) is None


def test_record_fields_and_params():
    c = FakeClient(["A"])
    r = sampler.sample_once(c, "m", "q?", OPTIONS, seed=7, temperature=0.5)
    assert r["model"] == "claude-fake-1"
    assert r["temperature"] == 0.5 and r["seed"] == 7
    assert sorted(r["option_order"]) == ["A", "B", "C"]
    assert r["raw_reply"] == "A" and r["parsed"] == "A"
    assert r["usage"] == {"input_tokens": 11, "output_tokens": 1}
    assert c.calls[0]["max_tokens"] == 1  # 預設值
    assert c.calls[0]["extra_body"] == {"temperature": 0.5}


def test_seed_reproducible_and_shuffles():
    o1 = sampler.shuffled_order(list(OPTIONS), 1)
    assert o1 == sampler.shuffled_order(list(OPTIONS), 1)
    orders = {tuple(sampler.shuffled_order(list(OPTIONS), s)) for s in range(30)}
    assert len(orders) > 1


def test_prompt_contains_options_in_recorded_order():
    c = FakeClient(["A"])
    r = sampler.sample_once(c, "m", "q?", OPTIONS, seed=3)
    text = c.calls[0]["messages"][0]["content"][-1]["text"]
    idx = [text.index(f"{k}: {OPTIONS[k]}") for k in r["option_order"]]
    assert idx == sorted(idx)


def test_image_input(tmp_path):
    img = tmp_path / "x.png"
    img.write_bytes(b"\x89PNG-fake")
    c = FakeClient(["A"])
    sampler.sample_once(c, "m", "q?", OPTIONS, seed=1, image_paths=[img])
    block = c.calls[0]["messages"][0]["content"][0]
    assert block["type"] == "image"
    assert block["source"]["data"] == base64.b64encode(b"\x89PNG-fake").decode()
    assert block["source"]["media_type"] == "image/png"


def test_unparseable_counted_not_dropped():
    # 正向對照：無法解析的回覆必須被計入，不可被丟棄
    c = FakeClient(["A", "Z", "", None, "B"])
    out = sampler.run_samples(c, "m", "q?", OPTIONS, k=5, base_seed=0)
    assert len(out["results"]) == 5
    assert out["unparseable"] == 3
    assert out["counts"] == {"A": 1, "B": 1}
    assert [r["parsed"] for r in out["results"]].count(None) == 3


def test_seeds_recorded_distinct():
    c = FakeClient(["A"])
    out = sampler.run_samples(c, "m", "q?", OPTIONS, k=4, base_seed=100)
    assert [r["seed"] for r in out["results"]] == [100, 101, 102, 103]


def test_make_client_requires_env(monkeypatch):
    monkeypatch.delenv("RESEARCH_ANTHROPIC_API_KEY", raising=False)
    try:
        sampler.make_client()
    except SystemExit:
        return
    raise AssertionError("未設 key 時應拒絕")


def test_make_client_ignores_old_name(monkeypatch):
    # 正向對照：舊名存在、新名不存在 → 仍判定缺 key
    monkeypatch.setenv("ANTHROPIC_API_KEY", "fake-old")
    monkeypatch.delenv("RESEARCH_ANTHROPIC_API_KEY", raising=False)
    try:
        sampler.make_client()
    except SystemExit:
        return
    raise AssertionError("舊名存在不應被接受")


def test_make_client_passes_api_key_explicitly(monkeypatch):
    seen = {}
    fake = SimpleNamespace(Anthropic=lambda **kw: seen.update(kw) or "client")
    monkeypatch.setitem(sys.modules, "anthropic", fake)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "fake-old")
    monkeypatch.setenv("RESEARCH_ANTHROPIC_API_KEY", "fake-new")
    assert sampler.make_client() == "client"
    assert seen == {"api_key": "fake-new"}


def test_temperature_omitted_vs_passed():
    # E1 對照：不傳與傳入的請求與紀錄必須不同
    c = FakeClient(["A"])
    r0 = sampler.sample_once(c, "m", "q?", OPTIONS, seed=1)
    r1 = sampler.sample_once(c, "m", "q?", OPTIONS, seed=1, temperature=0.3)
    assert "temperature" not in c.calls[0]
    assert "extra_body" not in c.calls[0]
    assert r0["temperature"] is None
    assert "temperature" not in c.calls[1]
    assert c.calls[1]["extra_body"] == {"temperature": 0.3}
    assert c.calls[0] != c.calls[1]
    assert r1["temperature"] == 0.3


def test_fake_rejects_temperature_kwarg():
    # 回歸防護：以關鍵字參數傳 temperature 必須翻紅
    c = FakeClient(["A"])
    try:
        c.messages.create(model="m", max_tokens=1, messages=[], temperature=0.1)
    except TypeError:
        return
    raise AssertionError("替身不應接受 temperature 關鍵字參數")
