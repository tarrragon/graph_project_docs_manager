# Book Interchange Format（book-interchange-v1）

**版本**: 3.0.0（approved）
**建立日期**: 2026-06-02
**來源**: 0.19.0-W4-031 ANA（D1-D6）+ W4-031.1（v1）+ W4-031.3 reconciliation（方案 A everything-as-tags，用戶拍板）
**定位**: 本專案（Chrome Extension, book-overview）與配套 Flutter APP（book_overview_app）**雙專案共同 SSOT** 的跨專案匯入匯出 canonical 格式

---

## 0. 版本沿革與分類模型決策

| 版本 | 分類模型 | 狀態 |
|------|---------|------|
| v1.0.0 | 結構化 classification（D2=C draft）| 已被取代 |
| v2.0.0 | 結構化 classification + CCL first-class（方案 C）| **已被取代**（對 APP everything-as-tags 多值資料有損，違反 C1）|
| **v3.0.0（本版）** | **everything-as-tags（方案 A）** | **approved** |

**v3.0.0 決策依據（W4-031.3 reconciliation + 用戶拍板）**：APP v0.32.0 已 ticket 化 everything-as-tags（tag_categories/tags/book_tags 三表、12 系統 tag 類別、CCL tag 樹 ~1000 節點）為**確定方向**。everything-as-tags 是 superset，對兩端無損：APP 內部模型 = canonical（零阻抗），V1 固定欄位包成單元素 tag（無損）。方案 C 對 APP 多值資料（多 author/ISBN/alias/platform）有損，故棄用。

> 完整 WRAP + reality-test 失誤補正見 `docs/work-logs/.../0.19.0-W4-031.3.md`。v1/v2 設計保留於 git history（失敗案例學習原則）。

---

## 1. 定位與 SSOT 聲明

本規格定義 `book-interchange-v1` —— 兩專案間透過 JSON 檔案雙向同步書庫資料的**唯一權威格式（SSOT）**。

| 項目 | 說明 |
|------|------|
| 取代關係 | 取代/升版 V1 `docs/spec/export-interchange-format-v2.md` 與 APP `PROP-007 §5 Interchange Format` 為跨專案共同 SSOT |
| 適用範圍 | 跨專案同步走 **JSON**（本格式）；CSV 為各專案人類可讀匯出，**不**走跨專案互通（見 §10，D6=A）|
| 兩專案責任 | 各專案實作 adapter：內部 model ↔ 本 canonical 雙向轉換（read/write）|

> **Why everything-as-tags**：同一本書可有多版本（多作者譯名、多出版社、多 ISBN、多平台購買）。多值 metadata 本質是 tag 而非單值欄位。APP v0.32.0 確定採此模型；canonical 對齊之以達零阻抗 + 兩端無損。

---

## 2. 設計約束（不可違反）

| # | 約束 | 落地機制 |
|---|------|---------|
| C1 | 雙向互通無損 | everything-as-tags superset + pass-through（§9）；多值欄位全保留 |
| C2 | Extension 能展示 APP 分類 | tags 物件（§5）為 first-class，Extension 至少唯讀讀取 tags.ccl/importance/custom 並渲染 |
| C3 | 兩端內部模型刻意不同不強求統一 | adapter 各自映射（V1 固定欄位 ↔ tag），canonical 為交換層 |
| C4 | id 保留 | 匯入保留原 id、禁重生（§8）|
| C5 | 可擴展（向後相容演進） | formatVersion 版本協商 + pass-through（§8）|

---

## 3. Root 結構

```json
{
  "format": "book-interchange-v1",
  "formatVersion": "3.0.0",
  "metadata": {
    "exportedAt": "2026-06-02T10:00:00.000Z",
    "sourceApp": "book-overview",
    "totalBooks": 928
  },
  "books": [ /* Book 物件，見 §4 */ ],
  "tagTree": {
    "ccl": [
      { "id": "ccl-800", "name": "語言文學", "parentId": null, "locked": true },
      { "id": "ccl-861", "name": "日本文學", "parentId": "ccl-800", "locked": true }
    ],
    "custom": [
      { "id": "c-gift", "name": "送禮清單", "parentId": null },
      { "id": "c2", "name": "送同事", "parentId": "c-gift" }
    ]
  }
}
```

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `format` | string | 是 | 固定字面 `"book-interchange-v1"`（detector 辨識，§8）|
| `formatVersion` | string | 是 | semver，當前 `"3.0.0"` |
| `metadata.exportedAt` | string(ISO8601) | 是 | 匯出時間 |
| `metadata.sourceApp` | string | 是 | 枚舉：`book-overview` / `book_overview_app` |
| `metadata.totalBooks` | number | 是 | books 數量（交叉驗證）|
| `books` | array | 是 | 書籍陣列（§4）|
| `tagTree` | object | 否 | 需同步的階層 tag 樹（ccl + custom），匯入端重建對方 tag 樹（§6）|

---

## 4. Book 物件（everything-as-tags）

```json
{
  "id": "210327003000101",
  "title": "挪威的森林",
  "cover": {
    "thumbnail": "https://...210x315.jpg",
    "medium": "https://...420x630.jpg",
    "original": "https://...full.jpg"
  },
  "crossPlatformId": "cpid_a1b2c3d4",
  "dataFingerprint": "fp_x7y8z9",
  "progress": {
    "percentage": 45.5,
    "currentPage": 120,
    "totalPages": 265,
    "lastReadAt": "2026-03-20T14:22:00.000Z"
  },
  "createdAt": "2026-01-15T08:30:00.000Z",
  "updatedAt": "2026-03-20T14:22:00.000Z",
  "tags": {
    "author":        [{ "id": "a1", "name": "村上春樹" }, { "id": "a2", "name": "Haruki Murakami" }],
    "publisher":     [{ "id": "p1", "name": "時報出版" }],
    "platform":      [{ "id": "pl1", "name": "readmoo" }],
    "language":      [{ "id": "l1", "name": "中文" }],
    "isbn":          [{ "id": "i1", "name": "9789571234567" }],
    "alias":         [{ "id": "al1", "name": "ノルウェイの森" }],
    "readingStatus": [{ "id": "rs-reading", "name": "reading" }],
    "importance":    [{ "id": "imp-4", "name": "推薦分享" }],
    "series":        [],
    "description":   [{ "id": "d1", "name": "一本關於青春與失落的小說..." }],
    "ccl":           [{ "id": "ccl-861", "name": "日本文學", "path": "語言文學/東方文學/日本文學" }],
    "custom":        [{ "id": "c2", "name": "送同事", "path": "送禮清單/送同事" }]
  },
  "activeLoan": null,
  "extensions": {
    "book-overview": { "extractedAt": "2026-01-15T08:30:00.000Z" },
    "book_overview_app": { "apiEnriched": true }
  },
  "_passthrough": {}
}
```

### 4.1 固定欄位（每本書唯一，非 tag）

| 欄位 | 型別 | 必填 | 來源端 | 說明 |
|------|------|------|--------|------|
| `id` | string | 是 | 兩端 | 唯一識別符，匯入保留禁重生（§8）|
| `title` | string | 是 | 兩端 | 主書名（其餘書名版本入 tags.alias）|
| `cover` | object\|string | 否 | 兩端 | 多尺寸 `{thumbnail?, medium?, original?}`；相容單字串（→`original`）|
| `crossPlatformId` | string\|null | 否 | APP（規劃）| 跨平台統一 ID（dedup 軟連結，§8）|
| `dataFingerprint` | string\|null | 否 | APP（規劃）| 資料指紋（dedup 輔助，§8）|
| `progress` | object | 否 | Extension `progress`/`progressInfo` | `{percentage?, currentPage?, totalPages?, lastReadAt?}`；相容單數字（→`percentage`）|
| `createdAt` | string(ISO8601)\|null | 否 | 兩端 | 建立時間 |
| `updatedAt` | string(ISO8601)\|null | 否 | 兩端 | 最後更新時間（衝突解決比較用）|
| `activeLoan` | object\|null | 否 | APP | 借閱資訊（APP-only，Extension carry+pass-through）|
| `extensions` | object | 否 | 兩端 | 平台專屬欄位（對方保留不認識的）：`{book-overview:{...}, book_overview_app:{...}}` |
| `_passthrough` | object | 否 | 兩端 | 未知欄位保留袋（§9）|

### 4.2 tags 物件（everything-as-tags 核心）

`tags` 為按類別分組的 tag 物件，每類別值為 `[{id, name, path?}]`。

| Tag 類別 | 多值 | 來源映射 | 說明 |
|---------|------|---------|------|
| `author` | 多值 | V1 `authors[]`→各成 tag；APP `author`(單)→單元素 | 作者（多語言/譯名）|
| `publisher` | 多值 | V1/APP `publisher`→tag | 出版社（多版本）|
| `platform` | 多值 | V1 `source`→tag；APP `source`(物件)→平台名 tag | 來源平台（多平台購買）|
| `language` | 多值 | （兩端規劃）| 語言版本 |
| `isbn` | 多值 | V1 `identifiers.isbn`；APP `isbn`(單)→單元素 | ISBN（多版本）|
| `alias` | 多值 | （書名別名）| 其他版本書名 |
| `readingStatus` | **單選** | 兩端 readingStatus（§7 命名正規化）| 閱讀狀態（6 態）|
| `importance` | **單選** | V1（無，APP carry）；APP `importanceLevel`(1-7)→imp-N | 重要程度（7 級，§5.1）|
| `series` | 多值 | （叢書系列）| 系列名稱 + 冊數 |
| `description` | **單值** | APP `description` | 書籍描述 |
| `ccl` | **單選** | 兩端 v0.20+（CCL）| 中文圖書分類法（含 path，is_locked，§5.2）|
| `custom` | 多值 | V1 正規化 tagIds 圖；APP custom tag tree | 使用者自訂 tag（含 path，巢狀）|

**tag node 結構**：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | string | tag id（穩定，dedup 用）|
| `name` | string | tag 名稱 |
| `path` | string | 階層路徑（僅 ccl/custom 等樹狀類別，如 `送禮清單/送同事`）|

---

## 5. 系統 tag 類別語意

### 5.1 importance 7 級（對齊 PROP-007 §3.3）

| id | name | 說明 |
|----|------|------|
| imp-1 | 參考書 | 常查閱的工具書 |
| imp-2 | 重讀收藏 | 喜愛而想重複閱讀 |
| imp-3 | 文獻保存 | 學術或文獻價值 |
| imp-4 | 推薦分享 | 想推薦給他人 |
| imp-5 | 收藏價值 | 收藏目的 |
| imp-6 | 裝飾展示 | 家居裝飾 |
| imp-7 | 可清理 | 可清理或轉讓 |

APP `ImportanceLevel.value`(1-7) ↔ imp-N；V1 carry+display（不編輯）。

### 5.2 ccl 中文圖書分類法（is_locked tag 樹）

CCL 為受控階層分類（使用者不可改分類項，`locked: true`），三層結構（10 大類→100→1000）。

| 層面 | 表示 |
|------|------|
| 書級指派 | `tags.ccl = [{id, name, path}]`（單選，path 為階層路徑）|
| 樹結構同步 | `tagTree.ccl[]`（`{id, name, parentId, locked:true}`，匯入端重建）|

兩端 v0.20+（V1）/ v0.32.0（APP）落地 CCL 時對齊本表示。Extension 至少唯讀展示 `tags.ccl[0].path`（C2）。

---

## 6. tagTree 階層同步

需同步的階層 tag 類別（ccl + custom）的樹結構放 root `tagTree`，匯入端據此重建對方 tag 樹。

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | string | tag id |
| `name` | string | tag 名稱 |
| `parentId` | string\|null | 父 tag（null=頂層）|
| `locked` | boolean | 是否鎖定（ccl=true，custom=false）|

> book.tags.{ccl,custom} 的 tag node 以 id ref 進 tagTree；扁平類別（author/publisher 等）不需 tagTree。

---

## 7. readingStatus 6 態正規化（單選 tag）

`tags.readingStatus` 為單選 tag，canonical name 採 6 態：

| canonical name | Extension v2 | APP ReadingStatus | PROP-007 |
|----------------|-------------|-------------------|----------|
| not_started | unread | notStarted | not_started |
| queued | queued | queued | queued |
| reading | reading | reading | reading |
| finished | finished | finished | finished |
| abandoned | abandoned | abandoned | abandoned |
| reference | reference | （無→pass-through 原值）| reference |

> 採 PROP-007 命名（`not_started` 等），對齊 APP v0.32.0 將實作的 reading_status tag。V1 adapter `unread→not_started` 映射；缺對應態時記 `_passthrough.readingStatusRaw`（C1）。

---

## 8. 版本協商 + detector + dedup（D4 / D5 / C5）

匯入 detector 辨識來源優先序（高→低）：

| 優先序 | 條件 | 判定 |
|--------|------|------|
| 1 | `format === "book-interchange-v1"` | 本 canonical（讀 formatVersion 分流 1.x/2.x/3.x）|
| 2 | `metadata.formatVersion` 以 `2.` 開頭（無 `format`）| V1 舊內部 v2 格式（相容讀）|
| 3 | 含 `backup_info`/`export_info` wrapper + `books[]` | APP legacy fixed-field（v0.31.x，經 legacy adapter）|
| 4 | 純陣列 或 `{books:[]}` 無版本標記 | flat v1（legacy converter）|

**id 保留（D5）**：所有來源匯入保留原 `id`，禁重生。

**dedup（C5）**：以 id 為主鍵；`crossPlatformId`（跨平台軟連結）/ `dataFingerprint`（內容指紋）為 optional 輔助，**不取代 id**。APP 自建書（`book_{timestamp}`）與 Extension readmoo stable id 各自保留。

**版本演進（C5）**：formatVersion semver；major 升級時 detector 優先序 1 內依 formatVersion 分流，pass-through 保護舊資料。

---

## 9. pass-through 機制（D3）

匯入端對**未知欄位**原樣保留，禁止 strip。

| 機制 | 說明 |
|------|------|
| `extensions` | 平台專屬已知欄位（`book-overview.extractedAt` / `book_overview_app.apiEnriched` 等），對方保留 |
| `_passthrough` | 完全未知的頂層欄位保留袋；匯出時平鋪回頂層 |
| 目的 | 一端不認識的欄位（對方版本新增/專屬）round-trip 不丟（C1）|

---

## 10. CSV 定位（D6=A）

| 項目 | 決策 |
|------|------|
| 跨專案同步 | **僅走 JSON**（本 canonical），完整保真 |
| CSV | 各專案維持自身人類可讀 CSV 匯出，**不要求跨專案 round-trip** |
| 理由 | everything-as-tags（tags 物件 + tagTree 階層）本質無法無損攤平為扁平 CSV |

**CSV 受眾定位**：CSV 給**想自行整理書目而不透過配套 APP 的用戶**（匯入 spreadsheet 自訂排序/篩選/標記）。故 CSV 欄位刻意單純、不含自訂欄位；跨專案無損不是 CSV 的保證——雙向無損同步一律走本 JSON canonical。CSV 的「無損不可能」是配合此受眾定位的刻意取捨，而非缺陷。本專案內部（自身匯出 → 自身匯入）仍支援 id-based round-trip，服務 spreadsheet 使用者的本地工作流。

> 各專案 CSV 欄位/分隔符規格各自維護（本專案見 `docs/spec/csv-export-spec.md`，tags 分隔符 `; `）。跨專案匯入 CSV **不在本 canonical 保證範圍**。

---

## 11. 兩端 adapter 映射總表（V1 ↔ canonical ↔ APP）

| canonical | V1（Extension）內部 | APP（book_overview_app）內部 | 映射性質 |
|-----------|---------------------|------------------------------|---------|
| id | id | id | 直通（保留）|
| title | title | title | 直通 |
| cover{} | cover(URL) | coverImageUrl(URL) / 多尺寸 | 單字串→{original} |
| progress{} | progress(num)+progressInfo | ReadingProgress VO（規劃）| 物件化 |
| crossPlatformId/dataFingerprint | _passthrough | crossPlatformId/dataFingerprint | dedup 軟連結 |
| tags.author | authors[]→各 tag | tags.author（內部即 tag）| V1 固定欄位→tag |
| tags.platform | source→tag | tags.platform | V1 固定欄位→tag |
| tags.publisher/isbn | publisher/identifiers→tag | tags.publisher/isbn | V1 固定欄位→tag |
| tags.readingStatus | readingStatus(enum)→單選 tag | tags.reading_status | §7 命名正規化 |
| tags.importance | （carry）| importanceLevel→imp-N tag | APP-only，V1 carry+display |
| tags.ccl | （v0.20+）→ccl tag | （v0.32.0）ccl tag | is_locked 樹（§5.2）|
| tags.custom | 正規化 tagIds 圖→custom tag | custom tag tree | 兩端自訂 tag |
| tags.description/series/language/alias | （pass-through/carry）| 對應 tag | APP 較完整，V1 carry |
| activeLoan | （pass-through）| BookLoan | APP-only，V1 carry |
| extensions.book-overview | extractedAt/updatedAt 等 | （pass-through）| V1-only |
| extensions.book_overview_app | （pass-through）| status/apiEnriched/modificationHistory 等 | APP-only |

**V1 adapter 核心轉換**：固定欄位 ↔ tag 類別雙向機械映射（匯出包成單元素 tag，匯入取出還原固定欄位）。無損但較方案 C 複雜（已知代價）。

---

## 12. 落地（spawn 自 W4-031）

| ticket | 範圍 | 狀態 |
|--------|------|------|
| 0.19.0-W4-031.1 | v1.0.0 draft | completed |
| 0.19.0-W4-031.3 | reconciliation 升版 v3.0.0（everything-as-tags）| completed |
| 0.19.0-W4-031.2（V1 adapter）| read/write canonical v3 + detector 四來源 + 固定欄位↔tag 映射 + APP legacy 無損匯入（含「APP 誤判 v1」止血）| completed |
| APP repo DOC（W4-031.4 對應）| PROP-007 + APP specs 對齊本 canonical | 待建（跨 repo）|
| APP repo IMP | APP adapter：emit/read canonical（內部 everything-as-tags 直映射）+ formatVersion | 待建（跨 repo）|

---

## 相關文件

- `docs/work-logs/v0/v0.19/v0.19.0/tickets/0.19.0-W4-031.md` — 來源 ANA（D1-D6 + 雙向欄位矩陣）
- `docs/work-logs/v0/v0.19/v0.19.0/tickets/0.19.0-W4-031.3.md` — reconciliation ANA（WRAP + 方案 A 決策 + reality-test 失誤補正）
- `docs/spec/export-interchange-format-v2.md` — V1 內部 v2 格式（被本 canonical 取代為跨專案 SSOT）
- `docs/spec/csv-export-spec.md` — V1 CSV 人類匯出規格（不跨專案互通）
- 配套 APP：`/Users/tarragon/Projects/book_overview_app/docs/proposals/PROP-007-cross-project-spec-alignment.md`（everything-as-tags 設計，本 canonical 對齊來源）

---

**Last Updated**: 2026-06-18 | **Version**: 3.0.0（approved）| **Status**: approved — 兩端 adapter 實作驗證完成（W5-002 SC-1~SC-5 全 PASS，W5-004 wire key 修復）+ 用戶 review 通過（2026-06-18）
