# /// script
# requires-python = ">=3.10"
# dependencies = ["anthropic"]
# ///
"""Claude 單 token 選項代碼取樣（研究線共用）。

API key 只從環境變數 ANTHROPIC_API_KEY 讀取，不接受參數、不記錄。
用法：uv run sampler.py --model claude-haiku-5-5 --question "..." \
        --option A=alpha --option B=beta [--image x.png] [-k 1]
"""
# i18n-exempt: 研究用 CLI 腳本，非 App UI；字串為 prompt 與診斷訊息
import argparse
import base64
import json
import mimetypes
import os
import random
import sys
from collections import Counter
from pathlib import Path

KEY_ENV = "ANTHROPIC_API_KEY"
ANSWER_INSTRUCTION = "只回覆一個選項代碼，不加任何其他文字。"  # i18n-exempt
MISSING_KEY_MSG = f"[ERROR] 環境變數 {KEY_ENV} 未設定"  # i18n-exempt


def make_client():
    """建立 client；key 僅取自環境變數，未設則結束。"""
    if not os.environ.get(KEY_ENV):
        sys.exit(MISSING_KEY_MSG)
    import anthropic

    return anthropic.Anthropic()


def shuffled_order(codes, seed):
    """以 seed 決定的選項順序（同 seed 可重現）。"""
    order = list(codes)
    random.Random(seed).shuffle(order)
    return order


def parse_reply(text, codes):
    """回覆去空白後須恰為某選項代碼（不分大小寫），否則回傳 None。"""
    token = (text or "").strip().upper()
    valid = {c.upper(): c for c in codes}
    return valid.get(token)


def _image_block(path):
    path = Path(path)
    media_type = mimetypes.guess_type(path.name)[0] or "image/png"
    data = base64.b64encode(path.read_bytes()).decode()
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": media_type, "data": data},
    }


def _build_prompt(question, options, order):
    lines = [question, ""] + [f"{c}: {options[c]}" for c in order]
    lines += ["", ANSWER_INSTRUCTION]
    return "\n".join(lines)


def sample_once(client, model, question, options, seed, *, max_tokens=1,
                temperature=1.0, image_paths=()):
    """取樣一次並回傳完整記錄。options: {代碼: 選項文字}。"""
    order = shuffled_order(options, seed)
    content = [_image_block(p) for p in image_paths]
    content.append({"type": "text", "text": _build_prompt(question, options, order)})
    resp = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        temperature=temperature,
        messages=[{"role": "user", "content": content}],
    )
    raw = resp.content[0].text if resp.content else ""
    return {
        "model": resp.model,
        "temperature": temperature,
        "seed": seed,
        "option_order": order,
        "raw_reply": raw,
        "parsed": parse_reply(raw, options),
        "usage": {
            "input_tokens": resp.usage.input_tokens,
            "output_tokens": resp.usage.output_tokens,
        },
    }


def run_samples(client, model, question, options, k, base_seed=0, **kwargs):
    """取樣 K 次（seed 依序遞增）；無法解析者計入 unparseable，不丟棄。"""
    results = [
        sample_once(client, model, question, options, base_seed + i, **kwargs)
        for i in range(k)
    ]
    counts = Counter(r["parsed"] for r in results if r["parsed"] is not None)
    return {
        "results": results,
        "counts": dict(counts),
        "unparseable": sum(1 for r in results if r["parsed"] is None),
    }


def _parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--model", required=True)
    p.add_argument("--question", required=True)
    p.add_argument("--option", action="append", required=True)  # 格式 代碼=文字
    p.add_argument("--image", action="append", default=[])
    p.add_argument("-k", type=int, default=1)
    p.add_argument("--max-tokens", type=int, default=1)
    p.add_argument("--temperature", type=float, default=1.0)
    p.add_argument("--seed", type=int, default=0)
    return p.parse_args(argv)


def main(argv=None):
    args = _parse_args(argv)
    options = dict(o.split("=", 1) for o in args.option)
    out = run_samples(
        make_client(), args.model, args.question, options, args.k,
        base_seed=args.seed, max_tokens=args.max_tokens,
        temperature=args.temperature, image_paths=args.image,
    )
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
