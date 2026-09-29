#!/usr/bin/env python3
"""0.1.0-W3-335 系列集合同步稽核：成員 x 位置矩陣產生器與閘門（可重跑）。

用法：python3 docs/spec/ui/audit/matrix.py > /tmp/matrix_auto.md; echo $?
（或於任意工作目錄執行：python3 <此檔絕對路徑> > ...）
輸出三張機械矩陣（狀態、SnackBar key、錨點）、狀態集合相等檢查與真缺漏清單。
格值：Y=出現；~<id>=未出現但屬合理不出現（id 見 MASKS，附出處與理由）；
X=未出現且無遮罩，即真缺漏候選（是否真為缺漏由對應 ticket 判讀）。
結尾輸出真缺漏數。基線 baseline.tsv 內的缺漏（key、ticket 必填）不計入。
exit 0＝無基線外缺漏、無過期或不全的基線列、狀態集合差 0、權威表推導差 0；
exit 1＝有基線外新缺漏，或狀態集合／權威表推導差大於 0；
exit 2＝僅基線有過期列（key 已不在輸出）或欄位不全（同時有 1 的條件時取 1）。
遮罩只收有理由的項目：R 編號來自 0.1.0-W3-335.54 Solution〈4. 合理不出現〉，
N 編號為 0.3.3-W3-375 新判定；N6 起為 0.3.3-W3-407 由 baseline 改寫的遮罩（判準見 MASKS）；
不得為了歸零而擴大遮罩。合理不出現一律寫成遮罩，baseline.tsv 只收有追修票的真缺漏。
比對一律為固定字串（去除 ** 粗體標記後），範圍以章節標題切段；變更歷史表列排除。
權威表定義（STATES／SNACK_KEYS／ANCHOR 三個集合的來源）見同目錄 README.md。
（本檔為稽核腳本，字串內中文為比對樣式非 user-facing 字串）  # i18n-exempt
"""
import re
import sys
import glob
from fnmatch import fnmatchcase
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
S1 = str(ROOT / 'docs/spec/ui/SPEC-001-screen-state-matrix.md')
S3 = str(ROOT / 'docs/spec/ui/SPEC-003-interaction-response.md')
S4 = str(ROOT / 'docs/spec/ui/SPEC-004-component-library.md')
ARB = ROOT / 'lib/l10n/app_zh.arb'
BASELINE = Path(__file__).resolve().parent / 'baseline.tsv'
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
    'N1': ('W3-375 新判定；W3-404 收窄', '子集欄：該節／該表本身定義成員子集，非全集必列（現用於 S3§1.1 的非 scroll- 前綴、S3§4 的非導航錨點、S4§4.26 變體的 *Message key）；副作用：子集欄漏列新成員不會被本腳本發現'),  # i18n-exempt
    'N4': ('W3-404（W3-392 遮罩複核）', 'SPEC-001 明文不承載錨點，S1 任一欄宣告不適用'),  # i18n-exempt
    'N5': ('W3-404（W3-392 遮罩複核）', '§2.13 判準結論非 plain／withAction，或為動作文字 key、或不在 §2.13 對照表：無變體歸屬可比'),  # i18n-exempt
    'N2': ('W3-375 新判定', '畫面節分欄：key 只在觸發它的畫面節出現，改以「S3 §3.x 任一節出現」作行層檢查'),  # i18n-exempt
    'N3': ('W3-375 新判定；W3-407 擴及 S3任一／S4任一', '通式錨點（含 *）為命名通則，具體成員各自成列於同矩陣，本欄不逐通式要求'),  # i18n-exempt
    'N6': ('W3-407（W3-392 判讀；SPEC-003 §2.1〈未列轉換的預設〉）', 'S3 動畫提示欄只列與預設 cross-fade 不同的轉場：疊加態、阻擋三態、正常類、泳道衍生態、無法判定破洞屬預設，不逐列'),  # i18n-exempt
    'N7': ('W3-407（W3-392 判讀；SPEC-003 §2.7 覆蓋狀態、SPEC-001 §2–§4）', '由結果進入的空狀態（無 UC／無提案／無 ticket／無破洞）與鏈路斷裂，不以狀態錨點出現於互動反應表，進入由導航表與 §4 承載（R2 的同判準延伸）'),  # i18n-exempt
    'N8': ('W3-407（W3-392 判讀；SPEC-003 §2.7 首段）', '§2.7 只涵蓋空狀態與阻擋狀態元件：資料視圖降級類（鏈路斷裂、有破洞、無法判定破洞、部分損壞）與浮層畫面（§7）不在範圍（R4 的同判準延伸）'),  # i18n-exempt
    'N9': ('W3-407（W3-392 判讀；SPEC-004 §3.1 總表）', '§3.1 資料視圖降級類狀態由容器列以畫面節號標示，不寫狀態名（R6 的同判準延伸）'),  # i18n-exempt
    'N10': ('W3-407（W3-392 判讀；SPEC-003 §2.13 對照表〈既有條文〉欄）', 'SnackBar key 在 §2.13 有列且〈既有條文〉欄以「§N.N：」指名承載節：該承載節即權威處，S3 §2.2 或畫面節不重述 key（無列或欄內無指名者不適用，仍為缺漏；前提是承載節確實含有該 key，指名而未含者不遮蔽，另報「承載節宣告不實」）'),  # i18n-exempt
    'N11': ('W3-407（W3-392 判讀；SPEC-003 殼層通則、NAV_EXCLUDE_PREFIX）', '殼層導航錨點（nav-item-／nav-page-）由殼層通則承載，不入互動反應表，SPEC-004 亦以通式承載'),  # i18n-exempt
    'N12': ('W3-407（W3-392 判讀；W3-395 已修）', '具體錨點被同欄某個通式錨點（含 *）以 fnmatch 涵蓋：腳本不展開通式，涵蓋範圍由通式決定'),  # i18n-exempt
}
GAPS = []            # (矩陣, 成員, 位置)：無遮罩的未出現格
WARNS = []           # 同上，警告等級：列出但不計入合計
MASK_USED = Counter()


def cell(matrix, member, col, present, mask=None, warn=False):
    """Y／~<id>／X（warn 時為 W）格值；X 登記為真缺漏，W 只登記警告。"""
    if present:
        return 'Y'
    if mask:
        MASK_USED[mask] += 1
        return '~' + mask
    (WARNS if warn else GAPS).append((matrix, member, col))
    return 'W' if warn else 'X'


def gap_key(gap):
    """基線比對鍵：與真缺漏清單輸出行字面（去除行首 '- '）一致。"""
    m, member, col = gap
    return f'[{m}] {member} x {col}'


def row_has(ls, cell_prefix):
    pat = re.compile(r'\| *' + re.escape(cell_prefix) + r'(?: *\||（)')
    return any(pat.search(l) for l in ls)


def has(ls, s):
    return any(s in l for l in ls)



# N7：由結果進入的空狀態名（SPEC-003 §2.7 覆蓋狀態列舉）加鏈路斷裂；N8／N9：資料視圖降級類錨點。
RESULT_EMPTY_ANCHORS = {anc for _, name, anc in STATES if name in ('無 UC', '無提案', '無 ticket', '無破洞')} | {'state-traceability-broken'}  # i18n-exempt
DATA_DEGRADED_ANCHORS = {'state-traceability-broken', 'state-gaps-found', 'state-gaps-undeterminable',
                         'state-nodeDetail-partial', 'badge-tickets-corrupted'}
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
    return state_mask_n(col, anc, normal, blocked, overlay)


def state_mask_n(col, anc, normal, blocked, overlay):
    """W3-407 自 baseline 改寫的狀態遮罩（N6–N9）。"""  # i18n-exempt
    if col == 'S3動畫' and (blocked or overlay or normal  # i18n-exempt
                           or anc.startswith('state-domain-swimlane') or anc == 'state-gaps-undeterminable'):
        return 'N6'
    if col == 'S3互動' and anc in RESULT_EMPTY_ANCHORS:  # i18n-exempt
        return 'N7'
    if col == 'S3§2.7' and (anc in DATA_DEGRADED_ANCHORS or anc.startswith('state-switcher-')):
        return 'N8'
    if col == 'S4§3.1' and anc in DATA_DEGRADED_ANCHORS:
        return 'N9'
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
              'ticketsFiltersClearedSnackbarMessage', 'rescanAction', 'viewGapsAction', 'undoAction',
              'workspaceNotRemembered', 'scanCompleteUndeterminableSnackbarMessage']  # W3-405：補 W3-404 推導浮出的 2 key
# R9：選擇器／資料夾／Ticket 類 key（undoAction 屬 ticketsFiltersCleared 的復原動作）不在 S3 §2.2 範圍。
# workspaceNotRemembered 屬資料夾類（W3-405 延伸；SPEC-003 §2.13 列 15、§3.7）。
NOT_IN_S3_22 = {'chooseFolderUnavailableMessage', 'folderUnavailableMessage', 'ticketsTargetNotFoundMessage',
                'ticketsFiltersClearedSnackbarMessage', 'undoAction', 'workspaceNotRemembered'}
SNACK_SCREEN_NODES = (1, 2, 4, 5, 6, 7)
SNACK_ANY_SCREEN = 'S3§3.x 任一節'  # i18n-exempt
ARB_LINES = open(ARB, encoding='utf-8').read().splitlines() if ARB.exists() else []
KEY_TOKEN = re.compile(r'`([a-z][A-Za-z0-9]+)(?:\([^)]*\))?`')
VARIANT_NAMES = ('plain', 'withAction')


def derive_snack_keys():
    """由規格推導 SnackBar key 聯集：§2.13 對照表首欄 key、§2.2 i18n 表的 *SnackbarMessage／*Action、4.26 變體的 *Action。"""
    keys = set()
    for cells in parse_table_rows(section(L3, r'^### 2\.13', 3), '#'):
        if len(cells) > 1 and cells[1].startswith('`'):
            keys.add(KEY_TOKEN.match(cells[1]).group(1))
    for cells in parse_table_rows(section(L3, r'^### 2\.2 ', 3), 'key'):
        k = cells[0].strip('`')
        if k.endswith(('SnackbarMessage', 'Action')):
            keys.add(k)
    variants = sub(section(L4, r'^### 4\.26', 3), r'^#### 變體')  # i18n-exempt
    keys |= {k for l in variants for k in KEY_TOKEN.findall(l) if k.endswith('Action')}
    return keys - set(VARIANT_NAMES)  # withAction 是變體名，不是 i18n key


def snack_keys_effective():
    """矩陣列 = 寫死清單 ∪ 推導聯集（推導多出的成員也逐列核對）。"""
    return SNACK_KEYS + sorted(derive_snack_keys() - set(SNACK_KEYS))


def variant_conclusions():
    """§2.13 對照表判準結論為 plain／withAction 者：key -> 結論集合。"""
    out = {}
    for cells in parse_table_rows(section(L3, r'^### 2\.13', 3), '#'):
        if len(cells) > 6 and cells[1].startswith('`') and cells[6].strip('`') in VARIANT_NAMES:
            out.setdefault(KEY_TOKEN.match(cells[1]).group(1), set()).add(cells[6].strip('`'))
    return out


def variant_consistent(variants_ls, key, conclusions):
    """key 若在 4.26 變體表被具名，只能出現在其判準結論對應的變體列，且結論列必須有。"""
    rows = {c[0].strip('`'): ' '.join(c) for c in parse_table_rows(variants_ls, '變體')}  # i18n-exempt
    want = conclusions.get(key, set())
    return all((f'`{key}`' in rows.get(v, '')) == (v in want) for v in VARIANT_NAMES)


CARRIER = re.compile(r'§(\d+(?:\.\d+)*)：')


def carrier_section(key):
    """§2.13 對照表中含 key 的列，其〈既有條文〉欄（第 8 欄）以「§N.N：」指名的承載節；無則 None（N10）。"""  # i18n-exempt
    for cells in parse_table_rows(section(L3, r'^### 2\.13', 3), '#'):
        m = CARRIER.match(cells[7]) if len(cells) > 7 else None
        if m and re.search(rf'`{key}(?:\([^)]*\))?`', ' '.join(cells[1:6])):
            return m.group(1)
    return None


def carrier_holds(key):
    """N10 前提：§2.13 指名的承載節（§N.N 標題段）確實含有 key。"""
    sec = carrier_section(key)
    return bool(sec) and has(section(L3, rf'^### {re.escape(sec)} ', 3), key)


def carrier_false_claims(matrix, key):
    """§2.13 指名承載節（§2.2 除外，該節由 S3§2.2 欄自行檢查）但該節未含 key：登記「承載節宣告不實」。"""  # i18n-exempt
    sec = carrier_section(key)
    if sec and sec != '2.2' and not carrier_holds(key):
        GAPS.append((matrix, f'`{key}`', f'承載節宣告不實（§2.13 指名 §{sec}）'))  # i18n-exempt


def snack_screen_cells(matrix, key):
    """S3 §3.x 畫面節分欄（N2）：任一節出現即其餘 . 為合理不出現；全無則整列真缺漏（N10 承載節指名者除外）。"""  # i18n-exempt
    found = [has(section(L3, rf'^### 3\.{n} ', 3), key) for n in SNACK_SCREEN_NODES]
    if not any(found) and carrier_holds(key):
        MASK_USED['N10'] += 1
        return ['~N10'] * len(found)
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
    union_406 = s4_406 + s3_22 + ARB_LINES
    conclusions = variant_conclusions()
    head = ['key', 'S3§2.2', 'S3§2.13', 'S3§3.1', 'S3§3.2', 'S3§3.4', 'S3§3.5', 'S3§3.6', 'S3§3.7', 'S1§8.2', 'S4§4.26變體', 'S4§4.26一致', 'S4§4.26slot', 'S4§4.26i18n', 'S4§4.0.6聯集']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    m = 'B SnackBar'
    for k in snack_keys_effective():
        mk = f'`{k}`'
        row = [mk,
               cell(m, mk, 'S3§2.2', has(s3_22, k), 'R9' if k in NOT_IN_S3_22 else
                    ('N10' if carrier_holds(k) and carrier_section(k) != '2.2' else None)),
               cell(m, mk, 'S3§2.13', has(s3_213, k))]
        row += snack_screen_cells(m, k)
        carrier_false_claims(m, k)
        row += [cell(m, mk, 'S1§8.2', False, 'R8'),
                cell(m, mk, 'S4§4.26變體', has(variants, k), None if k.endswith('Action') else 'N1'),  # i18n-exempt
                cell(m, mk, 'S4§4.26一致', variant_consistent(variants, k, conclusions), None if k in conclusions and has(variants, k) else 'N5'),  # i18n-exempt
                cell(m, mk, 'S4§4.26slot', has(slots, k)),
                cell(m, mk, 'S4§4.26i18n', has(i18n, k)),
                cell(m, mk, 'S4§4.0.6聯集', has(union_406, k))]  # i18n-exempt
        print('| ' + ' | '.join(row) + ' |')


ANCHOR = re.compile(r'`((?:state|action|mode|scroll|drag|badge|panel|menu|option|card|cell|expander|input|nav|project)-[A-Za-z0-9<>\-_*.]+)`')
PLACEHOLDER = re.compile(r'<[^>]+>')
# R10：非互動錨點（佔位符正規化為 * 後）不入互動反應表。
# 與 derive_r10()（規格中非狀態錨點的 badge-／panel-）比對，差異計入合計（W3-404 對齊，補入推導多出的 5 項）。
R10_ANCHORS = {'badge-domain-degraded-schema', 'badge-ucFlow-event-orphan-*', 'panel-ucFlow-event-flow', 'badge-switcher-health-*',
               'badge-gaps-builtin-path-pattern', 'badge-tickets-corrupted-*', 'badge-traceability-broken-*',
               'panel-domain-cell-detail-empty', 'panel-domain-schema-detail'}
CONTRACT_BACK = re.compile(r'^action-[A-Za-z]+-back$')
# R2 適用的 state 錨點（阻擋三態、空圖、正常類、專案未就緒），與 state_mask 的 R2 判定同源。
R2_STATE_ANCHORS = {anc for _, name, anc in STATES
                    if name.startswith('正常') or name == '空圖'  # i18n-exempt
                    or anc in BLOCKED_ANCHORS or anc.endswith('-project-unready')}


ANCHOR_SETS = {}     # anchor_matrix 填入：欄名 -> 該欄出現的錨點集合（N12 通式涵蓋判定）
NAV_ANCHORS = set()   # anchor_matrix 填入：S3 §3.x〈導航跳轉與退出〉出現的錨點（S3§4 欄的檢查對象）
# S3§4 欄排除：殼層導航出口（SPEC-003 殼層通則承載）與規格明文宣告的外部動作不屬 §4 導航反應欄。
NAV_EXCLUDE_PREFIX = ('nav-item-', 'nav-page-')
# 外部動作不以名稱判定（open-* 中 action-nodeDetail-open-source 規格算同畫面轉換），
# 改由規格推導：SPEC-003 內與下列宣告語同一子句（以「。」「；」切分）出現的錨點。
EXTERNAL_DECLARATION = re.compile(r'不計為導航反應|不計為退出路徑')  # i18n-exempt
CLAUSE_SPLIT = re.compile(r'[。；]')  # i18n-exempt


def derive_external_anchors():
    """SPEC-003 中被明文宣告為外部動作（不計為導航反應／退出路徑）的錨點集合。"""
    found = set()
    for line in L3:
        for clause in CLAUSE_SPLIT.split(line):
            if EXTERNAL_DECLARATION.search(clause):
                found |= collect([clause])
    return found


def anchor_mask(col, a):
    """錨點矩陣某欄的合理不出現遮罩 id；無則 None。"""
    if col == 'S3§1.1':  # i18n-exempt
        return None if a.startswith('scroll-') else 'N1'
    if col == 'S3§1.4':  # i18n-exempt
        return None if a.startswith(('expander-', 'menu-')) else 'N1'
    if col == 'S3§4':  # i18n-exempt
        excluded = a.startswith(NAV_EXCLUDE_PREFIX) or a in derive_external_anchors()
        return None if a in NAV_ANCHORS and not excluded else 'N1'
    if col == 'S1任一':  # i18n-exempt
        return 'N4'
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
        if a in RESULT_EMPTY_ANCHORS:
            return 'N7'
    if col in ('S3任一', 'S4任一') and '*' in a:  # i18n-exempt
        return 'N3'
    if col == 'S4任一' and a.startswith(('state-', 'action-', 'mode-')):  # i18n-exempt
        return 'R5'
    if col in ('S3互動', 'S4任一'):  # i18n-exempt
        if a.startswith(NAV_EXCLUDE_PREFIX):
            return 'N11'
        if '*' not in a and any('*' in p and fnmatchcase(a, p) for p in ANCHOR_SETS.get(col, ())):
            return 'N12'
    return None


ANCHOR_COLS = ['S3互動', 'S3§1.1', 'S3§1.4', 'S3§4', 'S3任一', 'S4任一', 'S1任一']  # i18n-exempt
ANCHOR_SKIP = ('nav-item-', 'nav-page-', 'nav-item-*','nav-page-*', 'state-*', 'mode-*', 'scroll-*', 'expander-*', 'state-*-*')


def collect(ls):
    s = set()
    for l in ls:
        for a in ANCHOR.findall(l):
            a = a.rstrip('.')
            if '<screen>' not in a:
                s.add(PLACEHOLDER.sub('*', a))  # <itemId> 與 * 視為同一通式錨點
    return s


def derive_r10():
    """由規格推導非互動錨點：badge-／panel- 前綴、不是狀態錨點（STATES）者。"""
    state_anchors = {anc for _, _, anc in STATES}
    found = collect(L1) | collect(L3) | collect(L4)
    return {a for a in found if a.startswith(('badge-', 'panel-')) and a not in state_anchors and a not in ANCHOR_SKIP}


def authority_diffs():
    """SNACK_KEYS、R10_ANCHORS 寫死清單與規格推導值的對稱差；逐項印出並回傳項數。"""
    diffs = 0
    for label, pinned, derived in (('SNACK_KEYS', set(SNACK_KEYS), derive_snack_keys()),
                                   ('R10_ANCHORS', set(R10_ANCHORS), derive_r10())):
        for name in sorted(derived - pinned):
            print(f'- [權威表差] {label}：規格推導有、寫死清單缺 `{name}`')  # i18n-exempt
            diffs += 1
        for name in sorted(pinned - derived):
            print(f'- [權威表差] {label}：寫死清單有、規格推導缺 `{name}`')  # i18n-exempt
            diffs += 1
    print(f'權威表推導對稱差：{diffs}')  # i18n-exempt
    return diffs


SAME_AS = re.compile(r'同 #(\d+)')  # i18n-exempt
# 排除出處：
# - nav-item-／nav-page-（NAV_EXCLUDE_PREFIX）與 project-switcher-entry（SHELL_ANCHORS）：
#   SPEC-003 §4 表頭段「本表不逐列列出『返回』『導覽』『切換專案』這三項」。
# - state- 前綴：轉換目標（→ 右側），不是觸發錨點，本身不需出現在 §4 觸發欄。
# - 外部動作：由 derive_external_anchors() 自規格明文推導，非名稱規則。
SHELL_ANCHORS = ('project-switcher-entry',)


def nav_row_gaps():
    """S3§4 逐列比對（畫面, 狀態, 錨點）：§3.x〈導航跳轉與退出〉每列的觸發錨點須出現在 §4 同（畫面, 狀態）列；
    §4 列以「同 #N」承接者，併入被承接列的錨點。缺者逐列登記。"""  # i18n-exempt
    external = derive_external_anchors()
    rows4 = {c[0]: c for c in parse_table_rows(section(L3, r'^## 4\. ', 2), '#')}
    by_key = {(c[1], norm_state(c[2])): c for c in rows4.values()}

    def row_anchors(c):
        got = collect([c[4]])
        for ref in SAME_AS.findall(c[4]):
            if ref in rows4 and rows4[ref] is not c:
                got |= row_anchors(rows4[ref])
        return got

    for n in range(1, 8):
        nav = sub(section(L3, rf'^### 3\.{n} ', 3), r'導航跳轉與退出')  # i18n-exempt
        for cells in parse_table_rows(nav, '狀態'):  # i18n-exempt
            key = (SCREEN[n][0], norm_state(cells[0]))
            want = {a for a in collect([' | '.join(cells)])
                    if not a.startswith(NAV_EXCLUDE_PREFIX + SHELL_ANCHORS + ('state-',))
                    and a not in external}
            got = row_anchors(by_key[key]) if key in by_key else set()
            for a in sorted(want - got):
                GAPS.append(('C 錨點', f'`{a}`', f'S3§4 逐列（{key[0]} / {key[1]}）'))  # i18n-exempt


def anchor_matrix():
    s3_int = set()
    for n in range(1, 8):
        s3_int |= collect(sub(section(L3, rf'^### 3\.{n} ', 3), r'互動反應'))  # i18n-exempt
        NAV_ANCHORS.update(collect(sub(section(L3, rf'^### 3\.{n} ', 3), r'導航跳轉與退出')))  # i18n-exempt
    s3_all, s4_all, s1_all = collect(L3), collect(L4), collect(L1)
    sets = [s3_int, collect(section(L3, r'^### 1\.1 ', 3)), collect(section(L3, r'^### 1\.4 ', 3)),
            collect(section(L3, r'^## 4\. ', 2)), s3_all, s4_all, s1_all]
    ANCHOR_SETS.update(zip(ANCHOR_COLS, sets))
    head = ['錨點', 'S3§3.x互動', 'S3§1.1', 'S3§1.4', 'S3§4', 'S3任一', 'S4任一', 'S1任一']  # i18n-exempt
    print('| ' + ' | '.join(head) + ' |')
    print('|' + '---|' * len(head))
    for a in sorted(s3_all | s4_all | s1_all):
        if a in ANCHOR_SKIP:
            continue
        row = [cell('C 錨點', f'`{a}`', c, a in st, anchor_mask(c, a), warn=(c == 'S3§1.4')) for c, st in zip(ANCHOR_COLS, sets)]  # i18n-exempt
        print('| ' + ' | '.join([f'`{a}`'] + row) + ' |')
    nav_row_gaps()


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


def load_baseline():
    """讀 baseline.tsv（欄位 key／ticket／note，ticket 必填）；回傳 (key -> ticket, 欄位不全的列描述)。"""
    entries, bad = {}, []
    if not BASELINE.exists():
        return entries, bad
    for no, raw in enumerate(open(BASELINE, encoding='utf-8'), 1):
        line = raw.rstrip('\n')
        if not line.strip() or line.startswith('#') or line.startswith('key\t'):
            continue
        f = line.split('\t')
        key, ticket = f[0].strip(), (f[1].strip() if len(f) > 1 else '')
        if not key or not ticket:
            bad.append(f'baseline.tsv 第 {no} 列 ticket 欄缺漏：{key or line!r}')  # i18n-exempt
        entries[key] = ticket
    return entries, bad


def summary(state_diffs, auth_diffs):
    """輸出真缺漏（基線外）、基線狀態與合計；回傳 exit code（0／1／2）。"""
    baseline, bad = load_baseline()
    current = {gap_key(g) for g in GAPS}
    new = [g for g in GAPS if gap_key(g) not in baseline]
    stale = sorted(k for k in baseline if k not in current)
    print('\n## 真缺漏清單（成員 x 位置；基線外）\n')  # i18n-exempt
    for g in new:
        print(f'- {gap_key(g)}')
    print('\n## 警告（不計入合計）\n')  # i18n-exempt
    for g in WARNS:
        print(f'- {gap_key(g)}')
    print('\n## 基線（baseline.tsv）\n')  # i18n-exempt
    print(f'基線列數：{len(baseline)}；命中：{len(baseline) - len(stale)}；過期：{len(stale)}；欄位不全：{len(bad)}')  # i18n-exempt
    for k in stale:
        print(f'- [基線過期] {k}（ticket {baseline[k] or "-"}）')  # i18n-exempt
    for msg in bad:
        print(f'- [基線欄位不全] {msg}')  # i18n-exempt
    print('\n## 遮罩使用（id：次數：出處：理由）\n')  # i18n-exempt
    for k in sorted(MASK_USED, key=lambda x: (x[0], int(x[1:]))):
        print(f'- {k}：{MASK_USED[k]}：{MASKS[k][0]}：{MASKS[k][1]}')  # i18n-exempt
    total = len(new) + state_diffs + auth_diffs
    code = 1 if total else (2 if stale or bad else 0)
    print(f'\n真缺漏數（基線外）：{len(new)}；基線內：{len(GAPS) - len(new)}；狀態集合對稱差：{state_diffs}；'  # i18n-exempt
          f'權威表推導對稱差：{auth_diffs}；合計：{total}；exit={code}（0 乾淨／1 新缺漏或漂移／2 基線過期或不全）')  # i18n-exempt
    return code


if __name__ == '__main__':
    print('# 機械矩陣（matrix.py 產出）\n\n格值：Y=出現、~<id>=合理不出現（見 MASKS）、X=真缺漏\n\n## A. 狀態 x 位置\n')  # i18n-exempt
    state_matrix()
    print('\n## B. SnackBar key x 位置\n')  # i18n-exempt
    snack_matrix()
    print('\n## C. 錨點 x 位置\n')  # i18n-exempt
    anchor_matrix()
    print('\n## D. 狀態集合相等檢查\n')  # i18n-exempt
    state_diffs = state_set_check()
    print('\n## E. 權威表推導對稱差\n')  # i18n-exempt
    sys.exit(summary(state_diffs, authority_diffs()))
