#!/usr/bin/env python3
"""0.1.0-W3-335 系列集合同步稽核：成員 x 位置矩陣產生器與閘門（可重跑）。

用法：python3 docs/spec/ui/audit/matrix.py > /tmp/matrix_auto.md; echo $?
（或於任意工作目錄執行：python3 <此檔絕對路徑> > ...）
輸出三張機械矩陣（狀態、SnackBar key、錨點）、狀態集合相等檢查與真缺漏清單。
格值：Y=出現；~<id>=未出現但屬合理不出現（id 見 MASKS，附出處與理由）；
X=未出現且無遮罩，即真缺漏候選（是否真為缺漏由對應 ticket 判讀）。
結尾輸出真缺漏數；真缺漏加狀態集合對稱差大於 0 時 exit 1，否則 exit 0。
遮罩只收有理由的項目：R 編號來自 0.1.0-W3-335.54 Solution〈4. 合理不出現〉，
N 編號為 0.3.3-W3-375 新判定；不得為了歸零而擴大遮罩。
比對一律為固定字串（去除 ** 粗體標記後），範圍以章節標題切段；變更歷史表列排除。
權威表定義（STATES／SNACK_KEYS／ANCHOR 三個集合的來源）見同目錄 README.md。
（本檔為稽核腳本，字串內中文為比對樣式非 user-facing 字串）  # i18n-exempt
"""
import re
import sys
import glob
from collections import Counter
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
    (5, '無法判定破洞', 'state-gaps-undeterminable'),  # i18n-exempt
    (6, '專案未就緒', 'state-nodeDetail-project-unready'), (6, '未選節點', 'state-nodeDetail-unset'),  # i18n-exempt
    (6, '正常', 'state-nodeDetail-normal'), (6, '部分損壞', 'state-nodeDetail-partial'),  # i18n-exempt
    (6, '原始檔已消失', 'state-nodeDetail-missing'),  # i18n-exempt
    (7, '收合', 'state-switcher-collapsed'), (7, '展開', 'state-switcher-expanded'),  # i18n-exempt
    (7, '無最近專案', 'state-switcher-no-recent'),  # i18n-exempt
]


# 合理不出現遮罩：id -> (出處, 理由)。R 編號見 0.1.0-W3-335.54 Solution〈4. 合理不出現〉；
# N 編號為 0.3.3-W3-375 新判定，逐項列於該票 Solution 供核對。
MASKS = {
    'R1': ('.54 R1', 'S3 各 §3.x 生命週期以事件為列，未提及的狀態無專屬事件（整欄）'),  # i18n-exempt
    'R2': ('.54 R2', '由結果進入的狀態（阻擋三態、空圖、專案未就緒、正常類）不以狀態錨點出現於互動表，進入由導航表與 §4 承載'),  # i18n-exempt
    'R3': ('.54 R3', '動畫提示：專案未就緒由 §2.1 轉場通則承載；正常 · 矩陣由「載入中 → 正常」上位列涵蓋（僅收此二類）'),  # i18n-exempt
    'R4': ('.54 R4', '§2.7 只涵蓋空狀態／阻擋狀態元件；載入、正常、疊加類與原始檔已消失（S3-10b）不在範圍'),  # i18n-exempt
    'R5': ('.54 R5', 'state-／action-／mode- 錨點由 SPEC-004 通式（4.21、4.24、4.4、4.10）涵蓋，不逐一列名'),  # i18n-exempt
    'R6': ('.54 R6', 'SPEC-004 §3.1 資料視圖類狀態（正常*）由容器列以畫面節號標示，不寫狀態名'),  # i18n-exempt
    'R7': ('.54 R7', 'UC 為場景層，不要求逐狀態列舉（整欄）'),  # i18n-exempt
    'R8': ('.54 R8/R13', 'S1 §8.2 以事件敘述為單位、不寫 key 名（整欄；R13 判定 §2.13 #7-#9 不入 §8.2）'),  # i18n-exempt
    'R9': ('.54 R9', 'S3 §2.2 只承載外部開啟契約與系統通知，選擇器／資料夾／Ticket 類 key 不在其範圍'),  # i18n-exempt
    'R10': ('.54 R10', '非互動元素錨點由各自子表或殼層通則承載，不入互動反應表'),  # i18n-exempt
    'R11': ('.54 R11', '通則返回鍵 action-<screen>-back 為頁面框架通則（S3 §2.3），不逐狀態列'),  # i18n-exempt
    'R12': ('.54 R12', 'action-ucFlow-back-to-domain 為「已刪除」註記，不應出現於互動表'),  # i18n-exempt
    'N1': ('W3-375 新判定', '子集欄：該節／該表本身定義成員子集（捲動處、同畫面展開、退出觸發、S1 任一、S4 變體、S4 §4.0.6 新 key 總表），非全集必列；副作用：子集欄漏列新成員不會被本腳本發現'),  # i18n-exempt
    'N2': ('W3-375 新判定', '畫面節分欄：key 只在觸發它的畫面節出現，改以「S3 §3.x 任一節出現」作行層檢查'),  # i18n-exempt
    'N3': ('W3-375 新判定', '通式錨點（含 *）為命名通則，具體成員各自成列於同矩陣，本欄不逐通式要求'),  # i18n-exempt
}
GAPS = []            # (矩陣, 成員, 位置)：無遮罩的未出現格
MASK_USED = Counter()


def cell(matrix, member, col, present, mask=None):
    """Y／~<id>／X 三態格值；X 同時登記為真缺漏。"""
    if present:
        return 'Y'
    if mask:
        MASK_USED[mask] += 1
        return '~' + mask
    GAPS.append((matrix, member, col))
    return 'X'


def row_has(ls, cell_prefix):
    pat = re.compile(r'\| *' + re.escape(cell_prefix) + r'(?: *\||（)')
    return any(pat.search(l) for l in ls)


def has(ls, s):
    return any(s in l for l in ls)



STATE_COLS = ['S1表', 'S1§8.1', 'S3§4', 'S3導航', 'S3生命週期', 'S3動畫', 'S3互動', 'S3§2.7', 'S4§3.6', 'S4錨點', 'S4§3.1', 'UC']  # i18n-exempt
BLOCKED_ANCHORS = ('state-domain-not-framework', 'state-domain-schema-unconsumable', 'state-domain-schema-incompatible')


def state_mask(col, name, anc):
    """狀態矩陣某欄的合理不出現遮罩 id；無則 None（未出現即真缺漏）。"""
    normal = name.startswith('正常')  # i18n-exempt
    unready = anc.endswith('-project-unready')
    blocked = anc in BLOCKED_ANCHORS
    loading = name in ('載入中', '掃描中')  # i18n-exempt
    overlay = name in ('已選格', '含損壞')  # i18n-exempt
    if col == 'S3生命週期':  # i18n-exempt
        return 'R1'
    if col == 'S3互動' and (normal or unready or blocked or name == '空圖'):  # i18n-exempt
        return 'R2'
    if col == 'S3動畫' and (unready or anc == 'state-domain-matrix'):  # i18n-exempt
        return 'R3'
    if col == 'S3§2.7' and (normal or loading or overlay or anc == 'state-nodeDetail-missing'):
        return 'R4'
    if col == 'S4錨點' and anc.startswith('state-'):  # i18n-exempt
        return 'R5'
    if col == 'S4§3.1' and normal:
        return 'R6'
    if col == 'UC':
        return 'R7'
    return None


def state_matrix():
    s1_81 = section(L1, r'^### 8\.1', 3)
    s3_4 = section(L3, r'^## 4\. ', 2)
    s3_27 = section(L3, r'^### 2\.7', 3)
    s4_36 = section(L4, r'^### 3\.6', 3)
    s4_31 = section(L4, r'^### 3\.1', 3)
    head = ['#', '節', '狀態', '錨點'] + STATE_COLS  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    for i, (n, name, anc) in enumerate(STATES, 1):
        s1n = section(L1, rf'^## {n}\. ', 2)
        s3n = section(L3, rf'^### 3\.{n} ', 3)
        present = {  # i18n-exempt
            'S1表': row_has(s1n, name),  # i18n-exempt
            'S1§8.1': row_has(s1_81, f'§{n} | {name}'),
            'S3§4': has(s3_4, f'`{anc}`'),
            'S3導航': row_has(sub(s3n, r'導航跳轉與退出'), name),  # i18n-exempt
            'S3生命週期': has(sub(s3n, r'生命週期'), anc) or has(sub(s3n, r'生命週期'), name),  # i18n-exempt
            'S3動畫': has(sub(s3n, r'動畫提示'), name),  # i18n-exempt
            'S3互動': has(sub(s3n, r'互動反應'), anc),  # i18n-exempt
            'S3§2.7': has(s3_27, name),
            'S4§3.6': row_has(s4_36, f'§{n} | {name}'),
            'S4錨點': has(L4, anc),  # i18n-exempt
            'S4§3.1': has(s4_31, name),
            'UC': has(ALL_UC, name),
        }
        cells = [cell('A 狀態', f'§{n} {name} `{anc}`', c, present[c], state_mask(c, name, anc)) for c in STATE_COLS]  # i18n-exempt
        print('| ' + ' | '.join([str(i), f'§{n}', name, f'`{anc}`'] + cells) + ' |')


# 本清單為權威表之一（見 README.md），新增或移除 SnackBar key 時須同步更新。
SNACK_KEYS = ['openedExternallyMessage', 'externalOpenFailedMessage', 'sourceFileNotFoundSnackbarMessage',
              'sourceFileStillMissingMessage', 'scanCompleteNoGapsSnackbarMessage', 'scanCompleteSnackbarMessage',
              'chooseFolderUnavailableMessage', 'folderUnavailableMessage', 'ticketsTargetNotFoundMessage',
              'ticketsFiltersClearedSnackbarMessage', 'rescanAction', 'viewGapsAction', 'undoAction']
# R9：選擇器／資料夾／Ticket 類 key（undoAction 屬 ticketsFiltersCleared 的復原動作）不在 S3 §2.2 範圍。
NOT_IN_S3_22 = {'chooseFolderUnavailableMessage', 'folderUnavailableMessage', 'ticketsTargetNotFoundMessage',
                'ticketsFiltersClearedSnackbarMessage', 'undoAction'}
SNACK_SCREEN_NODES = (1, 2, 4, 5, 6, 7)
SNACK_ANY_SCREEN = 'S3§3.x 任一節'  # i18n-exempt


def snack_screen_cells(matrix, key):
    """S3 §3.x 畫面節分欄（N2）：任一節出現即其餘 . 為合理不出現；全無則整列真缺漏。"""
    found = [has(section(L3, rf'^### 3\.{n} ', 3), key) for n in SNACK_SCREEN_NODES]
    if not any(found):
        GAPS.append((matrix, f'`{key}`', SNACK_ANY_SCREEN))
        return ['X'] * len(found)
    return [cell(matrix, f'`{key}`', SNACK_ANY_SCREEN, f, 'N2') for f in found]


def snack_matrix():
    s3_213 = section(L3, r'^### 2\.13', 3)
    s3_22 = section(L3, r'^### 2\.2 ', 3)
    s4_426 = section(L4, r'^### 4\.26', 3)
    s4_406 = section(L4, r'^#### 4\.0\.6', 4)
    variants = sub(s4_426, r'^#### 變體')  # i18n-exempt
    slots = sub(s4_426, r'^#### slot 契約')  # i18n-exempt
    i18n = sub(s4_426, r'^#### i18n')
    head = ['key', 'S3§2.2', 'S3§2.13', 'S3§3.1', 'S3§3.2', 'S3§3.4', 'S3§3.5', 'S3§3.6', 'S3§3.7', 'S1§8.2', 'S4§4.26變體', 'S4§4.26slot', 'S4§4.26i18n', 'S4§4.0.6']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    m = 'B SnackBar'
    for k in SNACK_KEYS:
        mk = f'`{k}`'
        row = [mk,
               cell(m, mk, 'S3§2.2', has(s3_22, k), 'R9' if k in NOT_IN_S3_22 else None),
               cell(m, mk, 'S3§2.13', has(s3_213, k))]
        row += snack_screen_cells(m, k)
        row += [cell(m, mk, 'S1§8.2', False, 'R8'),
                cell(m, mk, 'S4§4.26變體', has(variants, k), 'N1'),  # i18n-exempt
                cell(m, mk, 'S4§4.26slot', has(slots, k)),
                cell(m, mk, 'S4§4.26i18n', has(i18n, k)),
                cell(m, mk, 'S4§4.0.6', has(s4_406, k), 'N1')]
        print('| ' + ' | '.join(row) + ' |')


ANCHOR = re.compile(r'`((?:state|action|mode|scroll|drag|badge|panel|menu|option|card|cell|expander|input|nav|project)-[A-Za-z0-9<>\-_*.]+)`')
PLACEHOLDER = re.compile(r'<[^>]+>')
# R10：非互動錨點（佔位符正規化為 * 後）不入互動反應表。
R10_ANCHORS = {'badge-domain-degraded-schema', 'badge-ucFlow-event-orphan-*', 'panel-ucFlow-event-flow', 'badge-switcher-health-*'}
CONTRACT_BACK = re.compile(r'^action-[A-Za-z]+-back$')
# R2 適用的 state 錨點（阻擋三態、空圖、正常類、專案未就緒），與 state_mask 的 R2 判定同源。
R2_STATE_ANCHORS = {anc for _, name, anc in STATES
                    if name.startswith('正常') or name == '空圖'  # i18n-exempt
                    or anc in BLOCKED_ANCHORS or anc.endswith('-project-unready')}


def anchor_mask(col, a):
    """錨點矩陣某欄的合理不出現遮罩 id；無則 None。"""
    if col in ('S3§1.1', 'S3§1.4', 'S3§4', 'S1任一'):  # i18n-exempt
        return 'N1'
    if col == 'S3互動':  # i18n-exempt
        if a in R10_ANCHORS:
            return 'R10'
        if CONTRACT_BACK.match(a):
            return 'R11'
        if a == 'action-ucFlow-back-to-domain':
            return 'R12'
        if a in R2_STATE_ANCHORS:
            return 'R2'
        if '*' in a:
            return 'N3'
    if col == 'S4任一' and a.startswith(('state-', 'action-', 'mode-')):  # i18n-exempt
        return 'R5'
    return None


ANCHOR_COLS = ['S3互動', 'S3§1.1', 'S3§1.4', 'S3§4', 'S3任一', 'S4任一', 'S1任一']  # i18n-exempt
ANCHOR_SKIP = ('nav-item-', 'nav-page-', 'nav-item-*','nav-page-*', 'state-*', 'mode-*', 'scroll-*', 'expander-*', 'state-*-*')


def anchor_matrix():
    def collect(ls):
        s = set()
        for l in ls:
            for a in ANCHOR.findall(l):
                a = a.rstrip('.')
                if '<screen>' not in a:
                    s.add(PLACEHOLDER.sub('*', a))  # <itemId> 與 * 視為同一通式錨點
        return s
    s3_int = set()
    for n in range(1, 8):
        s3_int |= collect(sub(section(L3, rf'^### 3\.{n} ', 3), r'互動反應'))  # i18n-exempt
    s3_all, s4_all, s1_all = collect(L3), collect(L4), collect(L1)
    sets = [s3_int, collect(section(L3, r'^### 1\.1 ', 3)), collect(section(L3, r'^### 1\.4 ', 3)),
            collect(section(L3, r'^## 4\. ', 2)), s3_all, s4_all, s1_all]
    head = ['錨點', 'S3§3.x互動', 'S3§1.1', 'S3§1.4', 'S3§4', 'S3任一', 'S4任一', 'S1任一']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    for a in sorted(s3_all | s4_all | s1_all):
        if a in ANCHOR_SKIP:
            continue
        row = [cell('C 錨點', f'`{a}`', c, a in st, anchor_mask(c, a)) for c, st in zip(ANCHOR_COLS, sets)]  # i18n-exempt
        print('| ' + ' | '.join([f'`{a}`'] + row) + ' |')


def parse_table_rows(section_lines, first_cell_header):
    """回傳資料列儲存格清單；只取表頭首格為 first_cell_header 的表。"""
    rows, in_table = [], False
    for l in section_lines:
        if not l.startswith('|'):
            in_table = False
            continue
        cells = [c.strip() for c in l.strip().strip('|').split('|')]
        if cells[0] == first_cell_header:
            in_table = True
        elif in_table and not set(cells[0]) <= set('-: '):
            rows.append(cells)
    return rows


ANNOTATION = re.compile(r'（[^）]*）')  # i18n-exempt


def norm_state(name):
    """狀態名去除 ** 與全形括號疊加註記後比對。"""
    return ANNOTATION.sub('', name.replace('**', '')).strip()


def state_sets():
    """三個狀態集合，元素為 (畫面, 狀態)：SPEC-001 §1–§7、SPEC-003 §4、本腳本 STATES。"""
    s1 = set()
    for n in range(1, 8):
        for cells in parse_table_rows(section(L1, rf'^## {n}\. ', 2), '狀態'):  # i18n-exempt
            s1.add((SCREEN[n][0], norm_state(cells[0])))
    s3 = {(cells[1], norm_state(cells[2])) for cells in parse_table_rows(section(L3, r'^## 4\. ', 2), '#')}
    own = {(SCREEN[n][0], norm_state(nm)) for n, nm, _ in STATES}
    return {'SPEC-001 §1–§7': s1, 'SPEC-003 §4': s3, 'matrix.py STATES': own}


def state_set_check():
    """SPEC-001 對 SPEC-003 §4、對 STATES 兩組對稱差；逐項列出缺漏方向與名稱，回傳差異項數。"""
    sets = state_sets()
    print('狀態集合大小：' + '、'.join(f'{k}={len(v)}' for k, v in sets.items()))  # i18n-exempt
    diffs = 0
    for a, b in (('SPEC-001 §1–§7', 'SPEC-003 §4'), ('SPEC-001 §1–§7', 'matrix.py STATES')):
        for only_in, missing_from in ((a, b), (b, a)):
            for screen, name in sorted(sets[only_in] - sets[missing_from]):
                print(f'- [集合差] {screen} / {name}：{only_in} 有、{missing_from} 缺')  # i18n-exempt
                diffs += 1
    print(f'狀態集合對稱差：{diffs}')  # i18n-exempt
    return diffs


def summary(state_diffs):
    print('\n## 真缺漏清單（成員 x 位置）\n')  # i18n-exempt
    for m, member, col in GAPS:
        print(f'- [{m}] {member} x {col}')
    print('\n## 遮罩使用（id：次數：出處：理由）\n')  # i18n-exempt
    for k in sorted(MASK_USED, key=lambda x: (x[0], int(x[1:]))):
        print(f'- {k}：{MASK_USED[k]}：{MASKS[k][0]}：{MASKS[k][1]}')  # i18n-exempt
    total = len(GAPS) + state_diffs
    print(f'\n真缺漏數：{len(GAPS)}；狀態集合對稱差：{state_diffs}；合計：{total}（大於 0 則 exit 1）')  # i18n-exempt
    return total


if __name__ == '__main__':
    print('# 機械矩陣（matrix.py 產出）\n\n格值：Y=出現、~<id>=合理不出現（見 MASKS）、X=真缺漏\n\n## A. 狀態 x 位置\n')  # i18n-exempt
    state_matrix()
    print('\n## B. SnackBar key x 位置\n')  # i18n-exempt
    snack_matrix()
    print('\n## C. 錨點 x 位置\n')  # i18n-exempt
    anchor_matrix()
    print('\n## D. 狀態集合相等檢查\n')  # i18n-exempt
    sys.exit(1 if summary(state_set_check()) else 0)
