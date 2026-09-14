#!/usr/bin/env python3
"""0.1.0-W3-335 系列集合同步稽核：成員 x 位置矩陣產生器（可重跑）。

用法：python3 docs/spec/ui/audit/matrix.py > /tmp/matrix_auto.md
（或於任意工作目錄執行：python3 <此檔絕對路徑> > ...）
輸出三張機械矩陣（狀態、SnackBar key、錨點），格值 Y=出現、.=未出現。
「未出現」不等於缺漏：真缺漏／合理不出現的判定見對應 ticket 的 Problem Analysis /
Solution（本檔不記錄判定結果，只產生原始矩陣）。
比對一律為固定字串（去除 ** 粗體標記後），範圍以章節標題切段；變更歷史表列排除。
權威表定義（STATES／SNACK_KEYS／ANCHOR 三個集合的來源）見同目錄 README.md。
（本檔為稽核腳本，字串內中文為比對樣式非 user-facing 字串）  # i18n-exempt
"""
import re
import glob
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
S1 = str(ROOT / 'docs/spec/ui/SPEC-001-screen-state-matrix.md')
S3 = str(ROOT / 'docs/spec/ui/SPEC-003-interaction-response.md')
S4 = str(ROOT / 'docs/spec/ui/SPEC-004-component-library.md')
UCS = sorted(glob.glob(str(ROOT / 'docs/usecases/UC-*.md')))
HIST = re.compile(r'^\| *\d+\.\d+ *\| *20')


def lines(path):
    return [l.replace('**', '') for l in open(path, encoding='utf-8') if not HIST.match(l)]


def section(ls, start_pat, level):
    """回傳自符合 start_pat 的標題起、至同級或更高級標題前的行。"""
    out, on = [], False
    for l in ls:
        m = re.match(r'^(#+) ', l)
        if m and on and len(m.group(1)) <= level:
            break
        if m and re.search(start_pat, l):
            on = True
            continue
        if on:
            out.append(l)
    return out


def sub(ls, title_pat):
    """於已切出的畫面段內，再切 #### 子節。"""
    return section(ls, title_pat, 4)


L1, L3, L4 = lines(S1), lines(S3), lines(S4)
ALL_UC = [l for p in UCS for l in lines(p)]

SCREEN = {1: ('Domain', 'domain'), 2: ('UC Flow', 'ucFlow'), 3: ('追溯', 'traceability'),  # i18n-exempt
          4: ('Ticket', 'tickets'), 5: ('破洞', 'gaps'), 6: ('節點詳情', 'nodeDetail'), 7: ('浮層', 'switcher')}  # i18n-exempt

# (節, 狀態名, 狀態錨點)；順序依 SPEC-001 §1–§7 表列序（權威）。
# 本清單為權威表之一（見 README.md），SPEC-001〈狀態總數〉增減狀態時須同步更新。
STATES = [
    (1, '未選專案', 'state-domain-unset'), (1, '載入中', 'state-domain-loading'),  # i18n-exempt
    (1, '正常 · 矩陣', 'state-domain-matrix'), (1, '已選格', 'panel-domain-cell-detail'),  # i18n-exempt
    (1, '正常 · 泳道', 'state-domain-swimlane'), (1, '泳道 · 尚未選定 UC', 'state-domain-swimlane-uc-unset'),  # i18n-exempt
    (1, '泳道 · flow 未結構化', 'state-domain-swimlane-unstructured'), (1, '空圖', 'state-domain-empty'),  # i18n-exempt
    (1, '不是框架專案', 'state-domain-not-framework'), (1, '無可消費的型別表', 'state-domain-schema-unconsumable'),  # i18n-exempt
    (1, 'schema 不相容', 'state-domain-schema-incompatible'),  # i18n-exempt
    (2, '專案未就緒', 'state-ucFlow-project-unready'), (2, '無 UC', 'state-ucFlow-empty'),  # i18n-exempt
    (2, '尚未選定 UC', 'state-ucFlow-uc-unset'), (2, 'flow 未結構化', 'state-ucFlow-unstructured'),  # i18n-exempt
    (2, '正常', 'state-ucFlow-normal'),  # i18n-exempt
    (3, '專案未就緒', 'state-traceability-project-unready'), (3, '正常', 'state-traceability-normal'),  # i18n-exempt
    (3, '鏈路斷裂', 'state-traceability-broken'), (3, '無提案', 'state-traceability-empty'),  # i18n-exempt
    (4, '專案未就緒', 'state-tickets-project-unready'), (4, '未載入', 'state-tickets-unloaded'),  # i18n-exempt
    (4, '載入中', 'state-tickets-loading'), (4, '正常 · 列表', 'state-tickets-list'),  # i18n-exempt
    (4, '正常 · 主題', 'state-tickets-topic'), (4, '無 ticket', 'state-tickets-empty'),  # i18n-exempt
    (4, '含損壞', 'badge-tickets-corrupted'),  # i18n-exempt
    (5, '專案未就緒', 'state-gaps-project-unready'), (5, '掃描中', 'state-gaps-scanning'),  # i18n-exempt
    (5, '無破洞', 'state-gaps-none'), (5, '有破洞', 'state-gaps-found'),  # i18n-exempt
    (6, '專案未就緒', 'state-nodeDetail-project-unready'), (6, '未選節點', 'state-nodeDetail-unset'),  # i18n-exempt
    (6, '正常', 'state-nodeDetail-normal'), (6, '部分損壞', 'state-nodeDetail-partial'),  # i18n-exempt
    (6, '原始檔已消失', 'state-nodeDetail-missing'),  # i18n-exempt
    (7, '收合', 'state-switcher-collapsed'), (7, '展開', 'state-switcher-expanded'),  # i18n-exempt
    (7, '無最近專案', 'state-switcher-no-recent'),  # i18n-exempt
]


def row_has(ls, cell_prefix):
    pat = re.compile(r'\| *' + re.escape(cell_prefix) + r'(?: *\||（)')
    return any(pat.search(l) for l in ls)


def has(ls, s):
    return any(s in l for l in ls)


def yn(b):
    return 'Y' if b else '.'


def state_matrix():
    s1_81 = section(L1, r'^### 8\.1', 3)
    s3_4 = section(L3, r'^## 4\. ', 2)
    s3_27 = section(L3, r'^### 2\.7', 3)
    s4_36 = section(L4, r'^### 3\.6', 3)
    s4_31 = section(L4, r'^### 3\.1', 3)
    head = ['#', '節', '狀態', '錨點', 'S1表', 'S1§8.1', 'S3§4', 'S3導航', 'S3生命週期', 'S3動畫', 'S3互動', 'S3§2.7', 'S4§3.6', 'S4錨點', 'S4§3.1', 'UC']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    for i, (n, name, anc) in enumerate(STATES, 1):
        s1n = section(L1, rf'^## {n}\. ', 2)
        s3n = section(L3, rf'^### 3\.{n} ', 3)
        cells = [
            str(i), f'§{n}', name, f'`{anc}`',
            yn(row_has(s1n, name)),
            yn(row_has(s1_81, f'§{n} | {name}')),
            yn(has(s3_4, f'`{anc}`')),
            yn(row_has(sub(s3n, r'導航跳轉與退出'), name)),  # i18n-exempt
            yn(has(sub(s3n, r'生命週期'), anc) or has(sub(s3n, r'生命週期'), name)),  # i18n-exempt
            yn(has(sub(s3n, r'動畫提示'), name)),  # i18n-exempt
            yn(has(sub(s3n, r'互動反應'), anc)),  # i18n-exempt
            yn(has(s3_27, name)),
            yn(row_has(s4_36, f'§{n} | {name}')),
            yn(has(L4, anc)),
            yn(has(s4_31, name)),
            yn(has(ALL_UC, name)),
        ]
        print('| ' + ' | '.join(cells) + ' |')


# 本清單為權威表之一（見 README.md），新增或移除 SnackBar key 時須同步更新。
SNACK_KEYS = ['openedExternallyMessage', 'externalOpenFailedMessage', 'sourceFileNotFoundSnackbarMessage',
              'sourceFileStillMissingMessage', 'scanCompleteNoGapsSnackbarMessage', 'scanCompleteSnackbarMessage',
              'folderPickerUnavailableMessage', 'folderUnavailableMessage', 'ticketsTargetNotFoundMessage',
              'ticketsFiltersClearedSnackbarMessage', 'rescanAction', 'viewGapsAction', 'undoAction']


def snack_matrix():
    s3_213 = section(L3, r'^### 2\.13', 3)
    s3_22 = section(L3, r'^### 2\.2 ', 3)
    s1_82 = section(L1, r'^### 8\.2', 3)
    s4_426 = section(L4, r'^### 4\.26', 3)
    s4_406 = section(L4, r'^#### 4\.0\.6', 4)
    variants = sub(s4_426, r'^#### 變體')  # i18n-exempt
    slots = sub(s4_426, r'^#### slot 契約')  # i18n-exempt
    i18n = sub(s4_426, r'^#### i18n')
    head = ['key', 'S3§2.2', 'S3§2.13', 'S3§3.1', 'S3§3.2', 'S3§3.4', 'S3§3.5', 'S3§3.6', 'S3§3.7', 'S1§8.2', 'S4§4.26變體', 'S4§4.26slot', 'S4§4.26i18n', 'S4§4.0.6']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    for k in SNACK_KEYS:
        row = [f'`{k}`', yn(has(s3_22, k)), yn(has(s3_213, k))]
        for n in (1, 2, 4, 5, 6, 7):
            row.append(yn(has(section(L3, rf'^### 3\.{n} ', 3), k)))
        row += [yn(has(s1_82, k)), yn(has(variants, k)), yn(has(slots, k)), yn(has(i18n, k)), yn(has(s4_406, k))]
        print('| ' + ' | '.join(row) + ' |')
    print('\n註：S1§8.2 以事件敘述為單位、不寫 key 名，該欄 . 為預期（改以對應 ticket 的事件對映表核對）。')  # i18n-exempt


ANCHOR = re.compile(r'`((?:state|action|mode|scroll|drag|badge|panel|menu|option|card|cell|expander|input|nav|project)-[A-Za-z0-9<>\-_*.]+)`')


def anchor_matrix():
    def collect(ls):
        s = set()
        for l in ls:
            s.update(a.rstrip('.') for a in ANCHOR.findall(l))
        return s
    s3_int = set()
    for n in range(1, 8):
        s3_int |= collect(sub(section(L3, rf'^### 3\.{n} ', 3), r'互動反應'))  # i18n-exempt
    s3_all, s4_all, s1_all = collect(L3), collect(L4), collect(L1)
    s3_11 = collect(section(L3, r'^### 1\.1 ', 3))
    s3_14 = collect(section(L3, r'^### 1\.4 ', 3))
    s3_4 = collect(section(L3, r'^## 4\. ', 2))
    universe = sorted(s3_all | s4_all | s1_all)
    head = ['錨點', 'S3§3.x互動', 'S3§1.1', 'S3§1.4', 'S3§4', 'S3任一', 'S4任一', 'S1任一']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    for a in universe:
        if '<screen>' in a or a in ('nav-item-', 'nav-page-', 'state-*', 'mode-*', 'scroll-*', 'expander-*'):
            continue
        print(f'| `{a}` | {yn(a in s3_int)} | {yn(a in s3_11)} | {yn(a in s3_14)} | {yn(a in s3_4)} | {yn(a in s3_all)} | {yn(a in s4_all)} | {yn(a in s1_all)} |')


if __name__ == '__main__':
    print('# 機械矩陣（matrix.py 產出）\n\n## A. 狀態 x 位置\n')  # i18n-exempt
    state_matrix()
    print('\n## B. SnackBar key x 位置\n')  # i18n-exempt
    snack_matrix()
    print('\n## C. 錨點 x 位置\n')  # i18n-exempt
    anchor_matrix()
