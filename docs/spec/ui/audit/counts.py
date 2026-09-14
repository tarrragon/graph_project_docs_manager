#!/usr/bin/env python3
"""0.1.0-W3-335 系列集合同步稽核：計數敘述擷取（可重跑）。
輸出：每一處含集合計數字樣的片段（檔名 行號 片段），排除「變更歷史」表列。
用法：python3 docs/spec/ui/audit/counts.py > /tmp/counts_raw.txt
（或於任意工作目錄執行：python3 <此檔絕對路徑> > ...）
判讀方式：本檔只列出「疑似寫死計數」的片段，不判定是否為缺漏——多數列屬合理的
固定計數（如「三個阻擋狀態」為 SPEC-001 已定案且不常變動的集合），逐項比對
`document-format-rules.md` 規則 10（可變計數不實例化）判準後才能下結論，判定結果
記錄於對應 ticket 的 Problem Analysis / Solution，本檔不記錄判定結果。
（本檔為稽核腳本，正則內中文為比對樣式非 user-facing 字串）
"""
import re
import glob
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
FILES = sorted(glob.glob(str(ROOT / 'docs/spec/ui/SPEC-00[134]-*.md'))) + sorted(glob.glob(str(ROOT / 'docs/usecases/UC-*.md')))
HIST = re.compile(r'^\| *\d+\.\d+ *\| *20')
NUM = r'(?:\d+|[一二三四五六七八九十兩]+)'  # i18n-exempt
P = re.compile('|'.join([
    r'\b39\b',
    NUM + r' ?個(?:狀態|阻擋狀態|非 Domain 畫面|畫面|載入態|長時操作|目標態|設定入口|承接|分支|區段|捲動處|入口|值|訊號|gate|port)',  # i18n-exempt
    r'[三四五六七]畫面', r'[二三四五六兩]態',  # i18n-exempt
    NUM + r' ?條(?!件|目)',  # i18n-exempt
    NUM + r' ?(?:處|類|種)(?![別型])',  # i18n-exempt
    r'[CFSLTM]1[–-][CFSLTM]\d+',
    r'捲動處|換頁處|拖拉處|同畫面內展開',  # i18n-exempt
    r'共 ?\d+',  # i18n-exempt
    r'\d+ ?個',  # i18n-exempt
]))

for path in FILES:
    name = os.path.basename(path)[:8]
    for i, line in enumerate(open(path, encoding='utf-8'), 1):
        if HIST.match(line):
            continue
        for m in P.finditer(line):
            s = max(0, m.start() - 30)
            frag = line[s:m.end() + 20].rstrip('\n')
            print(f'{name}\t{i}\t{frag}')
