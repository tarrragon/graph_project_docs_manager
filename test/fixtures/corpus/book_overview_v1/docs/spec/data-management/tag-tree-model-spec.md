---
id: SPEC-010
title: "Tag 樹狀 Model + 賴永祥分類法預裝 + Tag 管理規格"
status: draft
source_proposal: PROP-007
source_ticket: 0.20.0-W2-004
created: "2026-06-05"
updated: "2026-06-05"
version: "0.1"
owner: ""

domain: data-management
subdomain: tag-tree

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07]
related_specs: [SPEC-004, SPEC-005, SPEC-001, export-interchange-format-v2, overview-tag-display-spec, search-engine-tag-query-spec]
implements_requirements: []
depends_on_domains: [core, user-experience]
---

# Tag 樹狀 Model + 賴永祥分類法預裝 + Tag 管理規格

> 本規格為 v0.20.0 W2 功能波次 Phase 1 設計文件。來源：SA 前置審查（`0.20.0-W2-001`）方案 A 定案 + 四視角審查校正 + 4 項用戶決策 + 資料授權調查（`0.20.0-W2-003`）。
>
> **TDD 邊界**：本文件只定義「行為契約」與「驗收標準」，不含實作。函式簽名為契約定義，實作由 Phase 3 完成。

---

## 1. Purpose（目的）

現行 `TagSchema.js` 採扁平二層結構（TagCategory → Tag，TagCategory 無 `parentId`），無法表達賴永祥《中文圖書分類法》的階層關係（如「0 總類 → 00 特藏」）。

本功能為 Readmoo 書庫管理器的「中文圖書分類法 Tag 樹」使用者（重度書目整理者）提供：

1. **樹狀分類能力**：TagCategory 透過 `parentId` 形成遞迴樹，Tag 仍掛載於 category，Book 可掛任意層級 category（含非葉粗粒度標記）。
2. **預裝賴永祥分類法**：首次安裝/升級時注入二層分類樹（約 110 節點，`isSystem=true`），與圖書館界通用體系對齊。
3. **Tag 管理功能**：對 category/tag 進行 CRUD、批量操作、搜尋，含階層感知的刪除保護（cascade 分層語意）。

**核心價值**：把扁平標籤升級為可表達標準分類體系的樹，同時保證既有資料零遷移、跨裝置同步不破壞使用者自建內容。

---

## 2. API Signatures（介面定義）

> 簽名以契約描述為主，回傳值採專案 `OperationResult` 慣例（`{ success, error?, data? }`）。實作細節（in-memory 索引、I/O）不在此規範。

### 2.1 Schema 常數與欄位擴展

```js
// src/data-management/TagSchema.js 擴展
const TAG_TREE_MAX_DEPTH = 4 // 根=depth0；賴永祥最深 3 層，預留 1 層緩衝

TAG_CATEGORY_SCHEMA.fields.parentId = {
  type: 'string',
  required: false,
  default: null,            // null = 根節點
  nullable: true
}
// 其餘欄位（id/name/description/color/isSystem/sortOrder/createdAt/updatedAt）不變
```

### 2.2 唯一鍵語意（首要決策項）

```js
// 既有（扁平，全域唯一）：category.name 全域不可重複
// 變更後（樹狀，scoped 唯一）：(parentId, name) 組合唯一
//   → 兄弟節點間 name 不可重複；不同 parent 下可同名

// 抽象共用鍵生成（避免 ARCH-020 第三套平行 dup 檢查）
// 沿用 tag-storage-adapter.js:842 makeTagKey(categoryId, name) 的既有 pattern
function makeCategoryKey (parentId, name) // → `${parentId ?? 'ROOT'}::${name.toLowerCase()}`
```

### 2.3 驗證函式（擴展）

```js
// existingCategories 改傳「同 parentId 的兄弟集合」而非全域集合
validateTagCategory(category, siblingCategories = []) → { valid, errors }
//   新增檢查：
//   - parentId 型別（string|null）
//   - parentId 引用存在性（非 null 時須指向存在 category）
//   - 循環引用防護（category 不可成為自身祖先）
//   - MAX_DEPTH 防護（插入後深度 ≤ TAG_TREE_MAX_DEPTH）
//   - 兄弟唯一鍵：makeCategoryKey(parentId, name) 在 siblingCategories 中唯一
```

### 2.4 Storage Adapter（擴展 / 新增）

```js
// 既有擴展：parentId 處理落入寫入路徑
createTagCategory(input: { name, description?, color?, parentId? }) → OperationResult
updateTagCategory(id, patch: { name?, ..., parentId? }) → OperationResult
//   ↑ 二者皆須呼叫 validateTagCategory（既有 update 未呼叫 validate，屬 linux#2 校正項）

deleteTagCategory(id, options?: { cascadeSubtree?: boolean }) → OperationResult
//   cascade 分層語意見 §4

checkReferentialIntegrity() → { valid, repaired, orphans }
//   擴展：parentId 引用有效性 + 循環偵測 + 孤兒子樹偵測

// 樹查詢（in-memory，全量載入後操作）
getAncestors(categoryId) → TagCategory[]      // 根→自身路徑（不含自身）
getDescendants(categoryId) → TagCategory[]    // 子樹全部後代
getCategoryPath(categoryId) → string          // 顯示路徑，如 "0 總類 / 00 特藏"

// 預裝注入（獨立於 createTagCategory，繞過隨機 ID）
initializePresets() → OperationResult
//   走確定性 ID upsert，整批原子 storage.local.set
```

### 2.5 Tag 管理 UI 服務契約

```js
// CRUD / 批量 / 搜尋（UI 層服務介面，非 DOM）
renameTagCategory(id, newName) → OperationResult
moveTagCategory(id, newParentId) → OperationResult   // 改 parentId，含循環/深度檢查
batchDeleteTags(tagIds: string[]) → { deleted, failed }
batchMoveTags(tagIds: string[], targetCategoryId) → { moved, failed }
searchTags(query, options?: { includeSubtree?: boolean }) → { categories, tags }
```

---

## 3. GWT Scenarios（行為場景）

### 場景組 A：唯一鍵語意（決策 1 + 三處 dup 校正）

**場景 A1: 跨主類同名次類允許並存（賴永祥核心需求）**
- **Given**: 預裝樹已存在「0 總類」與「1 哲學類」兩個根 category
- **When**: 在「0 總類」下建立「00 特藏」，並在「1 哲學類」下建立另一個名為「總論」的次類；另一主類也有同名「總論」
- **Then**: 兩個「總論」因 parentId 不同而並存，`makeCategoryKey` 不同；不觸發 duplicate_name

**場景 A2: 同一父節點下同名次類被拒**
- **Given**: 「0 總類」下已有「00 特藏」
- **When**: 在「0 總類」下再建一個「00 特藏」
- **Then**: 回傳 `{ success: false, error: 'duplicate_name' }`（兄弟唯一鍵衝突）

**場景 A3: 三處全域 dup 檢查全部改為 scoped**
- **Given**: codebase 既有 3 處全域 name dup 檢查（`TagSchema.js` validateTagCategory:81-83、`tag-storage-adapter.js` createTagCategory:256-258、computeMergeResult:917-918）
- **When**: 引入樹狀 model
- **Then**: 三處全部改用 `makeCategoryKey(parentId, name)`；不得殘留任一處全域 `name` 比對（殘留會誤擋賴永祥跨主類同名次類）

### 場景組 B：parentId 防護（決策落寫入路徑）

**場景 B1: 循環引用被拒**
- **Given**: 存在鏈 A → B → C（C 的祖先含 A）
- **When**: 將 A 的 parentId 設為 C（`moveTagCategory(A, C)`）
- **Then**: 回傳 `{ success: false, error: 'circular_reference' }`，樹結構不變

**場景 B2: 超過 MAX_DEPTH 被拒**
- **Given**: 已存在 depth=3 的葉 category（根 depth=0）
- **When**: 在該葉下再建子 category（將達 depth=4，等於 TAG_TREE_MAX_DEPTH 上限後再加一層）
- **Then**: 回傳 `{ success: false, error: 'max_depth_exceeded' }`

**場景 B3: update 路徑也驗證**
- **Given**: 既有 `updateTagCategory` 不呼叫 validate（linux#2 缺陷）
- **When**: 透過 update 將 parentId 改成不存在的 id
- **Then**: 回傳驗證失敗（`invalid_parent_reference`），不寫入

### 場景組 C：cascade 分層刪除（決策 2，WRAP 分層預設）

**場景 C1: 刪非葉 category 預設禁止**
- **Given**: 「0 總類」下有子 category「00 特藏」
- **When**: `deleteTagCategory('0 總類')`（無 cascade 選項）
- **Then**: 回傳 `{ success: false, error: 'has_children' }`，錯誤訊息引導「請先處理子類」

**場景 C2: 刪葉 category，掛載的 tag 轉 Uncategorized**
- **Given**: 葉 category「001 善本」下直接掛載 3 個 tag
- **When**: `deleteTagCategory('001 善本')`
- **Then**: category 刪除；3 個 tag 的 categoryId 轉至 Uncategorized（與既有 checkReferentialIntegrity 自癒一致）；Book.tagIds 關聯不變、tag 不刪

**場景 C3: 刪整棵子樹（opt-in）**
- **Given**: 用戶自建子樹（根「我的分類」含 2 子類 + 5 tag）
- **When**: `deleteTagCategory('我的分類', { cascadeSubtree: true })`，UI 先彈確認對話框顯示「2 子類 / 5 tag 受影響」
- **Then**: 用戶確認後整棵子樹 + 其下 tag 刪除（tag 轉 Uncategorized 或一併刪由確認對話框明示）

**場景 C4: isSystem 預裝節點不可刪**
- **Given**: 預裝「0 總類」`isSystem=true`
- **When**: 任何刪除請求（含 cascadeSubtree）
- **Then**: 回傳 `{ success: false, error: 'system_protected' }`

### 場景組 D：預裝載入機制（MV3 校正）

**場景 D1: 首次安裝注入預裝樹**
- **Given**: 全新安裝，無任何 category
- **When**: `chrome.runtime.onInstalled`（reason=install）觸發
- **Then**: 約 110 個賴永祥二層 category 以確定性 ID（如 `sys_cat_0`、`sys_cat_00`）整批原子 `storage.local.set` 注入；全部 `isSystem=true`

**場景 D2: listener 頂層同步註冊（避免漏接事件）**
- **Given**: MV3 service worker 非持久；既有 `background.js:217` listener 註冊在多個 await 之後（缺陷）
- **When**: SW 因事件喚醒
- **Then**: `onInstalled` / `onStartup` listener 在 SW 腳本頂層同步註冊（無前置 await），確保事件不漏接

**場景 D3: onStartup 補償冪等**
- **Given**: 某次 onInstalled 因 SW 提前終止未完成注入
- **When**: 瀏覽器重啟觸發 `chrome.runtime.onStartup`
- **Then**: 補償檢查預裝完整性；以「確定性 ID + isSystem upsert」冪等補注，已存在則跳過，不重複建立、不覆蓋用戶對預裝節點的本地修改策略依 §同步

**場景 D4: 預裝走獨立 upsert 不經隨機 ID**
- **Given**: `createTagCategory` 用 `Date.now()+random` 生成 ID（line 266）
- **When**: `initializePresets` 注入
- **Then**: 不呼叫 createTagCategory；走獨立 upsert 以確定性 ID 寫入（否則跨裝置/重裝無法比對）

### 場景組 E：同步與打包（MV3-Q2/Q3/Q4）

**場景 E1: 預裝資料必須 storage.local**
- **Given**: 預裝主體約 16.5KB（110 節點）
- **When**: 寫入 storage
- **Then**: 寫入 `storage.local`（非 `storage.sync`）；放 sync 會撞 8KB/item 上限直接 reject

**場景 E2: 三層同步策略**
- **Given**: 兩裝置皆已預裝
- **When**: 跨裝置同步
- **Then**: (a) 預裝主體本地各自重建、不進 sync 通道；(b) 用戶差異（自建 category/tag + 對預裝的覆寫）走 sync，採 LWW（updatedAt）+ tombstone 刪除標記；(c) 預裝版本 flag 存 local

**場景 E3: 資料檔打包**
- **Given**: `chinese-classification.json` 不在 `build.js` COPY_PATHS
- **When**: build
- **Then**: 採 bundle 決策（見 §決策固化），資料檔隨產物打包；build.js 影響項明確記錄

### 場景組 F：Tag 管理 UI（CRUD/批量/搜尋）

**場景 F1: 重命名兄弟唯一鍵衝突**
- **Given**: 「0 總類」下有「00 特藏」「01 目錄學」
- **When**: 將「01 目錄學」重命名為「00 特藏」
- **Then**: 回傳 duplicate_name（兄弟唯一鍵）

**場景 F2: 搜尋含子樹聚合（決策 1 連動）**
- **Given**: Book 掛在非葉 category「0 總類」（粗粒度），另一 Book 掛在「00 特藏」
- **When**: 以「0 總類」搜尋且 `includeSubtree=true`
- **Then**: 結果聚合根節點直掛 + 整棵子樹下的 Book/tag

**場景 F3: 批量移動 tag**
- **Given**: 選取 5 個 tag
- **When**: `batchMoveTags(ids, '02 資訊科學')`
- **Then**: 5 個 tag 的 categoryId 改至目標；回傳 `{ moved: 5, failed: 0 }`

---

## 4. Error Handling（錯誤處理）

> 全部採專案 `ErrorCodes` + `OperationResult` 慣例（`docs/project-conventions.md`），禁止 `throw new Error('msg')`。

| 錯誤情境 | error code | 回傳 | 副作用回滾 |
|---------|-----------|------|-----------|
| 兄弟同名 | `duplicate_name` | `{ success:false }` | 無寫入 |
| parentId 指向不存在 | `invalid_parent_reference` | `{ success:false }` | 無寫入 |
| 循環引用 | `circular_reference` | `{ success:false }` | 無寫入 |
| 超過深度 | `max_depth_exceeded` | `{ success:false }` | 無寫入 |
| 刪非葉（無 cascade） | `has_children` | `{ success:false, hint }` | 無刪除 |
| 刪 isSystem | `system_protected` | `{ success:false }` | 無刪除 |
| 配額不足 | `quota_exceeded` | `{ success:false }` | 無寫入 |
| 預裝注入部分失敗 | `preset_init_failed` | `{ success:false }` | 整批原子 set，失敗則整批不生效 |
| cascade 刪除中途失敗 | `cascade_partial` | `{ success:false, rolledBack:true }` | 子樹刪除須回滾至刪前狀態 |

**孤兒子樹**：`checkReferentialIntegrity` 偵測到 parentId 指向已刪 category 的孤兒節點時，上提至最近存活祖先或根（自癒），記錄 repaired 計數。

### 邊界與狀態補述（/spec validate 迭代回答）

| # | 問題 | 結論 |
|---|------|------|
| Q1 | Uncategorized 自身語意 | Uncategorized 為 `isSystem=true` 根 category，不可刪；葉刪除轉移前若不存在則惰性建立（確定性 ID `sys_cat_uncategorized`） |
| Q2 | move 非葉導致子樹超深 | `moveTagCategory` 計算「目標 parent 深度 + 子樹最大相對深度」，> MAX_DEPTH 則整個 move 被拒（`max_depth_exceeded`），不部分移動 |
| Q3 | 預裝時配額已滿 | quota=blocked 時 `initializePresets` 回 `preset_init_failed` 不強寫；記錄待補旗標，onStartup 補償時重試；UI 提示使用者清理配額 |
| Q4 | 同步裁決 isSystem 節點 | 預裝主體不進 sync 通道（場景 E2-a），故 isSystem 節點本身無跨裝置 LWW 衝突；使用者對預裝節點的「覆寫差異」才走 sync，以 updatedAt LWW |
| Q5 | 預裝版本升級覆蓋使用者改名 | upsert 策略：新增缺失節點、不覆蓋既存節點的使用者修改欄位（name/color/sortOrder）；僅補新類目，保留使用者本地調整（保守 merge，非全量覆寫） |
| Q6 | 混合樹下刪 isSystem 祖先 | 刪 isSystem 祖先本被 `system_protected` 擋（不發生）；若使用者要移除自建子樹，對自建子節點執行 `cascadeSubtree`，不影響 isSystem 祖先；自建節點掛在預裝節點下為合法混合樹（決策 1 允許任意層級） |

---

## 5. Dependencies（依賴）

| 依賴 | 內容 | 前置條件 |
|------|------|---------|
| `TagSchema.js` | parentId 欄位、MAX_DEPTH、makeCategoryKey | 本 spec 定義 |
| `tag-storage-adapter.js` | 3 處 dup 檢查改 scoped、樹查詢、initializePresets、cascade | 上者 |
| `background.js` / SW | onInstalled/onStartup 頂層同步註冊 | W2-002 IMP 修復 listener 註冊時機（相依但獨立 ticket） |
| `build.js` | COPY_PATHS 納入 `chinese-classification.json`（bundle 決策） | §決策固化 |
| 跨裝置同步子系統 `src/background/domains/data-management/services/` | 三層同步策略接入 | 需 Phase 3 接線 |
| IF-v2 匯出（`export-interchange-format-v2`） | parentId 序列化 + `metadata.formatVersion`（非 schema_version） | §決策固化 |
| 賴永祥資料檔 | 110 節點精確類號+類目，**取自 NCL 類表編 PDF/HTML**，不沿用 W2-003 暫定名稱 | W2-003 授權調查（低風險，建議標註出處 + 函詢 NCL） |
| `overview-tag-display-spec` / `search-engine-tag-query-spec` | 階層路徑顯示 + 子樹搜尋聚合 | 擴展非 breaking |

**環境假設**：Chrome Storage 全量載入後 in-memory 樹操作（無效能瓶頸）；storage.local 5MB 配額，110 節點佔 0.33%。

---

## 6. Acceptance（驗收條件）

對應 ticket `0.20.0-W2-004` 6 條 acceptance：

- [ ] **schema 規格**：`TAG_CATEGORY_SCHEMA` 加 `parentId`（nullable, default null）+ `TAG_TREE_MAX_DEPTH=4`；唯一鍵語意明定為 `(parentId, name)`，列為首要決策項，含 3 處全域 dup 檢查改 scoped 的明確位置清單（TagSchema:81-83、adapter:256-258、merge:917-918）
- [ ] **cascade 規格**：分層預設（刪非葉禁止 / 刪葉轉 Uncategorized / 子樹刪除 opt-in + 確認對話框 / isSystem 保護）已用 GWT 定義；parentId 防護（循環/MAX_DEPTH/引用存在性）落 create + update 雙寫入路徑
- [ ] **載入機制規格**：onInstalled 頂層同步註冊 + onStartup 補償冪等 + 整批原子 `storage.local.set`；明文 storage.local（非 sync）；預裝走獨立 upsert 不經 createTagCategory 隨機 ID（確定性 ID）
- [ ] **同步與打包規格**：三層同步策略（預裝本地重建不 sync / 用戶差異 LWW+tombstone / version flag local）；資料檔打包決策（bundle + build.js COPY_PATHS 影響）；scoped-uniqueness 經 `makeCategoryKey` 抽象共用，避免 ARCH-020 第三套平行 dup
- [ ] **決策固化**：允許 Tag/Book 掛任意層級 category；IF-v2 用 `metadata.formatVersion`（非 schema_version）；第三層 lazy-load 範圍縮減（預裝至二層）；Tag 管理 UI 規格（CRUD/批量/搜尋）已定義服務契約
- [ ] **/spec validate 通過**：需求完善度驗證通過，產出可進 Phase 2 測試設計的功能規格

---

## 決策固化（用戶已定 + 校正項）

| # | 決策 | 結論 | 來源 |
|---|------|------|------|
| 1 | Tag/Book 掛載層級 | 允許掛任意層級 category（含非葉粗粒度）；連動：渲染顯路徑、搜尋子樹聚合、唯一鍵 + cascade 複雜度 | 用戶決策 1 |
| 2 | 刪中間節點 cascade | WRAP 分層預設（禁非葉 / 葉轉 Uncategorized / 子樹 opt-in / isSystem 保護）；可逆性原則 | 用戶決策 2 + WRAP |
| 3 | 資料來源/授權 | 自建扁平類號-類目對照（~110 節點）+ 標註出處「國家圖書館《中文圖書分類法》2007 年版」；散布前建議函詢 NCL（低風險，需法務最終確認） | W2-003 |
| 4 | IF-v2 版本欄位 | 用 `metadata.formatVersion`（SA 引用的 schema_version 不存在，Plan#7 事實校正） | Plan 校正 |
| 5 | 預裝深度 | 二層（主類 + 次類，~110）；第三層 lazy-load 從 scope 移除（Plan#8 範圍縮減） | Plan 校正 |
| 6 | 唯一鍵抽象 | 經 `makeCategoryKey` 共用，沿用既有 `makeTagKey` pattern，避免 ARCH-020 | linux#4a |
| 7 | 資料檔打包 | bundle（隨產物打包，非 runtime fetch）；理由：離線可用 + 無 CSP/網路依賴；build.js COPY_PATHS 需新增 | MV3-Q4 |

---

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 0.1 | 2026-06-05 | 初稿。方案 A model + 賴永祥二層預裝 + Tag 管理 + cascade 分層 + 三層同步 + 打包決策（`0.20.0-W2-004` Phase 1） |
