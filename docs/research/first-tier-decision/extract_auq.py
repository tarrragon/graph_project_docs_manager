#!/usr/bin/env python3
"""從主控 session 逐字稿機械抽取 AskUserQuestion 呼叫，供 0.5.0-W1-464 逐題編碼使用。

只做抽取，不做任何判讀：Recommended 只標記選項 label 是否含字面「Recommended」，
改答原因等欄位一律留給盲讀者依 coding_scheme.md 編碼。

輸出為逐題一列的 JSONL，內含逐字稿原文，屬用戶本機資料，寫到 .excerpts/（已 gitignore），不入庫。

用法：
    python3 extract_auq.py <transcript.jsonl> <out.jsonl> [--max-calls 44]
"""

import argparse
import json
import sys

CONTEXT_BEFORE_CHARS = 3000
CONTEXT_AFTER_CHARS = 4000
USER_MSG_CHARS = 800


def _load(path):
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line_no, raw in enumerate(fh):
            try:
                rows.append((line_no, json.loads(raw)))
            except json.JSONDecodeError as exc:
                # 逐字稿偶有截斷行；略過並記到 stderr，不中止抽取
                # i18n-exempt: 研究用一次性腳本的診斷輸出
                sys.stderr.write(f"[extract_auq] skip unparsable line {line_no}: {exc}\n")
    return rows


def _content(entry):
    return (entry.get("message") or {}).get("content")


def _assistant_texts(entry):
    content = _content(entry)
    if entry.get("type") != "assistant" or not isinstance(content, list):
        return []
    return [b.get("text", "") for b in content if b.get("type") == "text"]


def _user_typed_text(entry):
    """用戶親手輸入的文字；tool_result 與 meta 注入不算。"""
    if entry.get("type") != "user" or entry.get("isMeta"):
        return None
    content = _content(entry)
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = [b.get("text", "") for b in content if b.get("type") == "text"]
        return "\n".join(texts) if texts else None
    return None


def _find_auq_calls(rows):
    calls = []
    for idx, (line_no, entry) in enumerate(rows):
        content = _content(entry)
        if entry.get("type") != "assistant" or not isinstance(content, list):
            continue
        for block in content:
            if block.get("type") == "tool_use" and block.get("name") == "AskUserQuestion":
                calls.append((idx, line_no, entry, block))
    return calls


def _find_result(rows, start_idx, tool_use_id):
    for line_no, entry in rows[start_idx + 1:]:
        content = _content(entry)
        if entry.get("type") != "user" or not isinstance(content, list):
            continue
        for block in content:
            if block.get("type") == "tool_result" and block.get("tool_use_id") == tool_use_id:
                return line_no, block, entry.get("toolUseResult")
    return None, None, None


def _context_before(rows, call_idx):
    texts = []
    for _, entry in reversed(rows[:call_idx + 1]):
        if _user_typed_text(entry) is not None:
            break
        texts = _assistant_texts(entry) + texts
    return "\n".join(texts)[-CONTEXT_BEFORE_CHARS:]


def _context_after(rows, call_idx, next_call_idx):
    parts = []
    for line_no, entry in rows[call_idx + 1:next_call_idx]:
        typed = _user_typed_text(entry)
        if typed:
            parts.append(f"[L{line_no} user] {typed[:USER_MSG_CHARS]}")
    return "\n".join(parts)[:CONTEXT_AFTER_CHARS]


def _result_text(block):
    if block is None:
        return None
    content = block.get("content")
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict))
    return content


def extract(path, max_calls):
    rows = _load(path)
    calls = _find_auq_calls(rows)[:max_calls]
    out = []
    for call_no, (idx, line_no, entry, block) in enumerate(calls, start=1):
        next_idx = calls[call_no][0] if call_no < len(calls) else len(rows)
        result_line, result_block, tool_use_result = _find_result(rows, idx, block["id"])
        answers = (tool_use_result or {}).get("answers", {}) if isinstance(tool_use_result, dict) else {}
        annotations = (tool_use_result or {}).get("annotations", {}) if isinstance(tool_use_result, dict) else {}
        before = _context_before(rows, idx)
        after = _context_after(rows, idx, next_idx)
        for q_no, question in enumerate(block["input"].get("questions", []), start=1):
            options = question.get("options", [])
            text = question.get("question", "")
            out.append({
                "call_no": call_no,
                "q_no": q_no,
                "transcript_line": line_no,
                "timestamp": entry.get("timestamp"),
                "header": question.get("header"),
                "question": text,
                "multi_select": question.get("multiSelect", False),
                "options": [{"label": o.get("label"), "description": o.get("description")} for o in options],
                "recommended_labels": [o.get("label") for o in options if "Recommended" in (o.get("label") or "")],
                "answer": answers.get(text),
                "annotation": annotations.get(text),
                "result_is_error": bool(result_block and result_block.get("is_error")),
                "result_text": _result_text(result_block),
                "result_line": result_line,
                "context_before": before,
                "context_after_user_messages": after,
            })
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("transcript")
    parser.add_argument("out")
    parser.add_argument("--max-calls", type=int, default=44)
    args = parser.parse_args()
    rows = extract(args.transcript, args.max_calls)
    with open(args.out, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    calls = len({r["call_no"] for r in rows})
    # i18n-exempt: 研究用一次性腳本的摘要輸出
    print(f"calls={calls} questions={len(rows)} out={args.out}")


if __name__ == "__main__":
    main()
