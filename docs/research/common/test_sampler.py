"""sampler 的離線測試：以假 client 執行，不連網。"""
import base64
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).parent))
import sampler  # noqa: E402


def _block(kind, text):
    # thinking 區塊比照真實回應：有 thinking 欄位、沒有 text 屬性
    if kind == "thinking":
        return SimpleNamespace(type="thinking", thinking=text)
    return SimpleNamespace(type="text", text=text)


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
        reply = self.replies[(len(self.calls) - 1) % len(self.replies)]
        stop_reason = "end_turn"
        if isinstance(reply, dict):  # {"blocks": [(type, text)], "stop_reason": ...}
            stop_reason = reply.get("stop_reason", stop_reason)
            content = [_block(t, x) for t, x in reply["blocks"]]
        else:
            content = [_block("text", reply)] if reply is not None else []
        return SimpleNamespace(
            model=self.model,
            content=content,
            stop_reason=stop_reason,
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


def test_thinking_effort_omitted_vs_passed():
    # E1 對照：thinking、effort 各自指定／不指定，請求必須不同且各自正確
    c = FakeClient(["A"])
    sampler.sample_once(c, "m", "q?", OPTIONS, seed=1)
    sampler.sample_once(c, "m", "q?", OPTIONS, seed=1, thinking="adaptive")
    sampler.sample_once(c, "m", "q?", OPTIONS, seed=1, effort="high")
    sampler.sample_once(c, "m", "q?", OPTIONS, seed=1, thinking="disabled",
                        effort="low", temperature=0.2)
    base, th, ef, both = c.calls
    assert "extra_body" not in base
    assert th["extra_body"] == {"thinking": {"type": "adaptive"}}
    assert ef["extra_body"] == {"output_config": {"effort": "high"}}
    assert both["extra_body"] == {
        "temperature": 0.2,
        "thinking": {"type": "disabled"},
        "output_config": {"effort": "low"},
    }
    assert base != th and base != ef and th != ef


def test_thinking_block_first_text_extracted():
    # E2 正向對照：thinking 在前、text 在後，須取到 text
    reply = {"blocks": [("thinking", "hmm"), ("text", "B")]}
    r = sampler.sample_once(FakeClient([reply]), "m", "q?", OPTIONS, seed=1)
    assert r["raw_reply"] == "B" and r["parsed"] == "B"
    assert r["stop_reason"] == "end_turn"


def test_max_tokens_stop_reason_unparseable():
    # E2：max_tokens > 1 時，同一回應 stop_reason=max_tokens -> parsed 為 None
    # 並計入 unparseable（ui-vision-choice 解析規則）
    reply = {"blocks": [("thinking", "hmm"), ("text", "B")],
             "stop_reason": "max_tokens"}
    c = FakeClient([reply])
    r = sampler.sample_once(c, "m", "q?", OPTIONS, seed=1, max_tokens=8)
    assert r["raw_reply"] == "B" and r["parsed"] is None
    assert r["stop_reason"] == "max_tokens"
    out = sampler.run_samples(c, "m", "q?", OPTIONS, k=2, max_tokens=8)
    assert out["unparseable"] == 2 and out["counts"] == {}


def test_max_tokens_one_valid_code_parsed():
    # E1 對照：同一回應（合法代碼、stop_reason=max_tokens）在 max_tokens=1 與 8
    # 下結果不同；max_tokens=1 時依 466 預登記規則〈4. 解析〉取該代碼
    reply = {"blocks": [("text", " b\n")], "stop_reason": "max_tokens"}
    one = sampler.sample_once(FakeClient([reply]), "m", "q?", OPTIONS, seed=1,
                              max_tokens=1)
    eight = sampler.sample_once(FakeClient([reply]), "m", "q?", OPTIONS, seed=1,
                                max_tokens=8)
    assert one["parsed"] != eight["parsed"]
    assert one["parsed"] == "B" and eight["parsed"] is None
    out = sampler.run_samples(FakeClient([reply]), "m", "q?", OPTIONS, k=2,
                              max_tokens=1)
    assert out["unparseable"] == 0 and out["counts"] == {"B": 2}


def test_max_tokens_one_non_code_unparseable():
    # E2 正向對照：max_tokens=1 且截斷文字不是合法代碼 -> 仍無法解析
    reply = {"blocks": [("text", "The")], "stop_reason": "max_tokens"}
    r = sampler.sample_once(FakeClient([reply]), "m", "q?", OPTIONS, seed=1,
                            max_tokens=1)
    assert r["parsed"] is None


def test_no_text_block_no_exception():
    reply = {"blocks": [("thinking", "hmm")], "stop_reason": "max_tokens"}
    r = sampler.sample_once(FakeClient([reply]), "m", "q?", OPTIONS, seed=1)
    assert r["raw_reply"] == "" and r["parsed"] is None


def test_cli_thinking_effort_args():
    base = ["--model", "m", "--question", "q", "--option", "A=a"]
    a = sampler._parse_args(base)
    assert a.thinking is None and a.effort is None
    a = sampler._parse_args(base + ["--thinking", "adaptive", "--effort", "xhigh"])
    assert a.thinking == "adaptive" and a.effort == "xhigh"


def test_fake_rejects_temperature_kwarg():
    # 回歸防護：以關鍵字參數傳 temperature 必須翻紅
    c = FakeClient(["A"])
    try:
        c.messages.create(model="m", max_tokens=1, messages=[], temperature=0.1)
    except TypeError:
        return
    raise AssertionError("替身不應接受 temperature 關鍵字參數")
