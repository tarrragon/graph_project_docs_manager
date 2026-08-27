---
id: SPEC-OVERVIEW-TAG
title: "Overview Page Tag-based 顯示適配規格"
status: approved
source_proposal: PROP-007
created: "2026-04-05"
updated: "2026-04-05"
version: "1.0.0"
owner: ""
domain: page
subdomain: overview
related_usecases: [UC-05]
related_specs: []
---

# Overview Page Tag-based 顯示適配規格

> **Ticket**: 0.17.2-W1-003
> **版本**: v0.17.2
> **狀態**: Phase 1 設計完成
> **最後更新**: 2026-04-05

---

## 1. Purpose

v0.17.0 完成 Tag-based Book Model 重構後，Overview 頁面仍使用舊的 3 狀態（new/reading/finished）和無 tag 顯示的 UI。本規格定義 Overview 頁面如何適配新的 6 狀態篩選和 tag 顯示/篩選功能。

**現狀分析**:
- 表格欄位：封面、書名、書城來源、進度、狀態（5 欄）
- 篩選：僅文字搜尋（searchBox）+ 排序（title/progress/source）
- 狀態欄位：讀取 `book.status` 字串直接顯示
- 無 tag 相關 UI

**目標**:
- 表格新增 Tag 欄位（6 欄）
- 狀態篩選從無篩選升級為 6 狀態篩選 bar
- 新增 tag 篩選 widget
- 三者組合篩選（狀態 + tag + 文字搜尋）

---

## 2. 6 狀態篩選 UI 規格

### 2.1 資料來源

使用 `BookSchemaV2.READING_STATUS` 列舉值：

| 值 | 中文標籤 | 色彩（引用 design-system-spec.md） | CSS class |
|---|---------|----------------------------------|-----------|
| `unread` | 未開始 | `primaryLightest` `#E3F2FD` | `status-unread` |
| `reading` | 閱讀中 | `primary` `#2196F3` | `status-reading` |
| `finished` | 已完成 | `positive` `#4CAF50` | `status-finished` |
| `queued` | 待讀 | `primaryMedium` `#64B5F6` | `status-queued` |
| `abandoned` | 已放棄 | `negative` `#FF9800` | `status-abandoned` |
| `reference` | 參考用 | `primaryDark` `#1976D2` | `status-reference` |

### 2.2 篩選 Bar DOM 結構

位置：插入於搜尋框 (`#searchBox`) 與操作按鈕區域 (`.export-buttons`) 之間。

```html
<div class="filter-bar" id="filterBar">
  <div class="filter-section filter-section--status">
    <span class="filter-label">閱讀狀態：</span>
    <div class="filter-chips" id="statusFilterChips">
      <button class="filter-chip filter-chip--active" data-status="all">全部</button>
      <button class="filter-chip" data-status="unread">未開始</button>
      <button class="filter-chip" data-status="reading">閱讀中</button>
      <button class="filter-chip" data-status="finished">已完成</button>
      <button class="filter-chip" data-status="queued">待讀</button>
      <button class="filter-chip" data-status="abandoned">已放棄</button>
      <button class="filter-chip" data-status="reference">參考用</button>
    </div>
  </div>
</div>
```

### 2.3 互動規格

| 行為 | 說明 |
|------|------|
| 預設狀態 | 「全部」為 active，顯示所有書籍 |
| 單選切換 | 點擊任一狀態 chip，取消其他 chip 的 active 狀態 |
| 再次點擊已選狀態 | 回到「全部」 |
| active 視覺 | `filter-chip--active` class，背景色使用該狀態色彩，文字白色 |
| 計數顯示 | 每個 chip 顯示該狀態的書籍數量，格式 `未開始 (12)` |
| 與搜尋組合 | 狀態篩選先執行，再套用文字搜尋 |

### 2.4 狀態 Badge（表格內）

取代現有 `book.status` 直接顯示，改為 readingStatus badge：

```html
<span class="status-badge status-{readingStatus}">{中文標籤}</span>
```

對映函式簽名：
```javascript
/**
 * @param {string} readingStatus - READING_STATUS 列舉值
 * @returns {string} 中文標籤
 */
function getStatusLabel(readingStatus)

/**
 * @param {string} readingStatus - READING_STATUS 列舉值
 * @returns {string} CSS class name (e.g. 'status-unread')
 */
function getStatusCssClass(readingStatus)
```

---

## 3. Tag 欄位顯示規格

### 3.1 表格欄位變更

現有 5 欄 → 6 欄：

| 欄位 | 現有 | 新增/變更 |
|------|------|----------|
| 封面 | 維持 | - |
| 書名 | 維持 | - |
| 書城來源 | 維持 | - |
| 進度 | 維持 | - |
| 狀態 | 改用 readingStatus badge | 顯示邏輯變更 |
| **Tags** | **無** | **新增欄位** |

表頭 HTML：
```html
<tr>
  <th>封面</th>
  <th>書名</th>
  <th>書城來源</th>
  <th>進度</th>
  <th>狀態</th>
  <th>Tags</th>
</tr>
```

`CONSTANTS.TABLE.COLUMNS` 從 `5` 更新為 `6`。

### 3.2 Tag 顯示元件

每本書的 tag 欄位渲染為 chip 列表：

```html
<td class="book-tags">
  <div class="tag-chips">
    <span class="tag-chip" style="background-color: {category.color}20; color: {category.color}; border: 1px solid {category.color}40;" title="{category.name}: {tag.name}">
      {tag.name}
    </span>
    <!-- 重複每個 tag -->
  </div>
</td>
```

### 3.3 超出處理

| 條件 | 處理方式 |
|------|---------|
| tag 數量 <= 3 | 全部顯示 |
| tag 數量 > 3 | 顯示前 3 個 + `+N` 摺疊指示器 |
| 無 tag | 顯示灰色文字「未分類」 |

摺疊指示器：
```html
<span class="tag-chip tag-chip--more" title="還有 N 個標籤">+{N}</span>
```

點擊 `+N` 展開顯示所有 tag，展開後顯示「收合」按鈕。

常數定義：
```javascript
const TAG_DISPLAY = {
  MAX_VISIBLE: 3,
  EMPTY_LABEL: '未分類'
}
```

### 3.4 Tag 資料解析

書籍物件的 `tagIds` 是 ID 陣列，需要從 tag storage 取得完整 tag 物件（含 name、categoryId）再從 category storage 取得 category 物件（含 name、color）。

函式簽名：
```javascript
/**
 * 批量解析 tagIds 為顯示用資料
 * @param {string[]} tagIds - 書籍的 tagIds
 * @param {Map<string, Object>} tagMap - tag ID → tag 物件的查找表
 * @param {Map<string, Object>} categoryMap - category ID → category 物件的查找表
 * @returns {Array<{ tagId: string, tagName: string, categoryName: string, categoryColor: string }>}
 */
function resolveTagsForDisplay(tagIds, tagMap, categoryMap)
```

---

## 4. Tag 篩選 Widget 規格

### 4.1 位置與結構

位置：在 filter-bar 內，狀態篩選下方。

```html
<div class="filter-section filter-section--tags">
  <span class="filter-label">標籤篩選：</span>
  <div class="tag-filter-controls">
    <button class="tag-filter-toggle" id="tagFilterToggle">
      選擇標籤 <span class="tag-filter-count" id="tagFilterCount"></span>
    </button>
    <div class="tag-filter-mode">
      <label><input type="radio" name="tagFilterMode" value="or" checked> 任一符合 (OR)</label>
      <label><input type="radio" name="tagFilterMode" value="and"> 全部符合 (AND)</label>
    </div>
  </div>
  <div class="tag-filter-dropdown hidden" id="tagFilterDropdown">
    <!-- 動態生成，按 category 分組 -->
  </div>
</div>
```

### 4.2 Dropdown 內容（按 category 分組）

```html
<div class="tag-filter-dropdown" id="tagFilterDropdown">
  <div class="tag-filter-group" data-category-id="{categoryId}">
    <div class="tag-filter-group-header">
      <span class="tag-filter-group-color" style="background-color: {category.color}"></span>
      <span class="tag-filter-group-name">{category.name}</span>
    </div>
    <div class="tag-filter-group-items">
      <label class="tag-filter-item">
        <input type="checkbox" value="{tag.id}">
        <span>{tag.name}</span>
        <span class="tag-filter-item-count">({count})</span>
      </label>
      <!-- 重複每個 tag -->
    </div>
  </div>
  <!-- 重複每個 category -->
  <div class="tag-filter-actions">
    <button class="tag-filter-clear" id="tagFilterClear">清除全部</button>
  </div>
</div>
```

### 4.3 互動規格

| 行為 | 說明 |
|------|------|
| 切換 dropdown | 點擊 `#tagFilterToggle` 開關 dropdown |
| 多選 | checkbox 多選，選中即生效（即時篩選） |
| AND/OR 切換 | OR = 書籍有任一選中 tag 即顯示；AND = 書籍必須包含所有選中 tag |
| 預設模式 | OR |
| 計數顯示 | toggle 按鈕旁顯示已選 tag 數量 `(3)` |
| 清除全部 | 取消所有 checkbox，恢復無 tag 篩選 |
| 點擊外部 | 關閉 dropdown |
| 無 tag category | 顯示「尚無標籤分類」提示 |
| 每個 tag 後的計數 | 顯示該 tag 被多少本書使用 |

### 4.4 篩選狀態管理

```javascript
/**
 * Tag 篩選狀態
 * @typedef {Object} TagFilterState
 * @property {Set<string>} selectedTagIds - 已選 tag ID 集合
 * @property {'and'|'or'} mode - 篩選模式
 */
```

---

## 5. 三者組合篩選邏輯

### 5.1 篩選管線

篩選順序：狀態篩選 → tag 篩選 → 文字搜尋。

```
allBooks
  → statusFilter(books, selectedStatus)
  → tagFilter(books, selectedTagIds, mode)
  → textSearch(books, searchTerm)
  → sort(books, sortKey, direction)
  → render(books)
```

### 5.2 各階段邏輯

**狀態篩選**：
```javascript
/**
 * @param {Array} books
 * @param {string|null} selectedStatus - null 或 'all' 表示不篩選
 * @returns {Array}
 */
function filterByStatus(books, selectedStatus)
```
- `selectedStatus === null || 'all'` → 回傳全部
- 否則 → `books.filter(b => b.readingStatus === selectedStatus)`

**Tag 篩選**：
```javascript
/**
 * @param {Array} books
 * @param {Set<string>} selectedTagIds - 空 Set 表示不篩選
 * @param {'and'|'or'} mode
 * @returns {Array}
 */
function filterByTags(books, selectedTagIds, mode)
```
- `selectedTagIds.size === 0` → 回傳全部
- OR 模式 → `book.tagIds` 與 `selectedTagIds` 有交集
- AND 模式 → `selectedTagIds` 是 `book.tagIds` 的子集

**文字搜尋**：
- 維持現有邏輯：`book.title.toLowerCase().includes(searchTerm)`

### 5.3 applyCurrentFilter 重構

現有 `applyCurrentFilter()` 需擴充為支援三重篩選。新增兩個狀態屬性：

```javascript
// 在 constructor 中初始化
this.selectedStatus = null        // null = 全部
this.tagFilterState = {
  selectedTagIds: new Set(),
  mode: 'or'
}
```

---

## 6. 資料載入策略

### 6.1 Tag 資料預載入

Overview 頁面初始化時，與書籍資料同步載入 tag 和 category 資料：

```javascript
/**
 * 載入頁面所需的所有資料
 * @returns {Promise<{ books: Array, tags: Array, categories: Array }>}
 */
async function loadOverviewData()
```

流程：
1. 並行請求 `chrome.storage.local.get(['readmoo_books', 'tags', 'tag_categories'])`
2. 建立 tagMap（`Map<tagId, tagObject>`）和 categoryMap（`Map<categoryId, categoryObject>`）
3. 快取於 controller 實例屬性

### 6.2 快取策略

| 資料 | 快取位置 | 更新時機 |
|------|---------|---------|
| tagMap | `this.tagMap` | 初始載入、storage.onChanged |
| categoryMap | `this.categoryMap` | 初始載入、storage.onChanged |
| 已解析的書籍 tag 顯示資料 | 不快取，每次渲染時計算 | - |

storage.onChanged 監聽需擴充：監聽 `tags` 和 `tag_categories` 的變更（對應 `TagStorageAdapter.STORAGE_KEYS`），更新 map 後重新渲染。

### 6.3 效能考量

| 指標 | 目標 |
|------|------|
| 頁面首次載入（1000 本書 + tag 資料） | < 3 秒 |
| 篩選響應時間（切換狀態/tag/搜尋） | < 200ms |
| 表格渲染（1000 行） | < 500ms |

為達成效能目標：
- tag 解析使用 Map 查找（O(1)），避免陣列遍歷
- 篩選使用管線式處理，每階段只遍歷一次
- 表格渲染使用 `DocumentFragment` 批量 DOM 操作

---

## 7. 空狀態處理

| 情境 | 顯示內容 |
|------|---------|
| 無書籍資料 | 維持現有空狀態（「目前沒有書籍資料」） |
| 篩選/搜尋結果為空 | 「沒有符合條件的書籍。嘗試調整篩選條件或搜尋關鍵字。」 |
| 書籍無 tag | tag 欄位顯示灰色「未分類」 |
| 系統無任何 tag/category | tag 篩選 widget 顯示「尚無標籤分類」，widget 可操作但無 checkbox |
| tag 篩選選中但無符合書籍 | 同篩選結果為空提示，額外提示「目前選中的標籤組合無符合書籍」 |

空狀態 DOM：
```html
<tr class="empty-state-row">
  <td colspan="6" class="empty-state-cell">
    <div class="empty-state-message">{訊息文字}</div>
  </td>
</tr>
```

注意 `colspan` 從 `5` 更新為 `6`。

---

## 8. CSS 規範

### 8.1 新增 CSS Classes

```css
/* 篩選 Bar */
.filter-bar { }
.filter-section { }
.filter-section--status { }
.filter-section--tags { }
.filter-label { }
.filter-chips { }
.filter-chip { }
.filter-chip--active { }

/* Tag 欄位 */
.book-tags { }
.tag-chips { }
.tag-chip { }
.tag-chip--more { }

/* Tag 篩選 Dropdown */
.tag-filter-controls { }
.tag-filter-toggle { }
.tag-filter-count { }
.tag-filter-mode { }
.tag-filter-dropdown { }
.tag-filter-group { }
.tag-filter-group-header { }
.tag-filter-group-color { }
.tag-filter-group-name { }
.tag-filter-group-items { }
.tag-filter-item { }
.tag-filter-item-count { }
.tag-filter-actions { }
.tag-filter-clear { }

/* 狀態 Badge（擴充） */
.status-unread { }
.status-reading { }  /* 現有，保留 */
.status-finished { } /* 現有，保留 */
.status-queued { }
.status-abandoned { }
.status-reference { }

/* 空狀態 */
.empty-state-row { }
.empty-state-cell { }
.empty-state-message { }
```

### 8.2 命名規範

- BEM-like 命名：`block--modifier`、`block__element`（但本專案現有 CSS 未嚴格使用 BEM，新增部分使用 `block-element` 連字號風格保持一致）
- 篩選相關：`filter-*`
- Tag 相關：`tag-*`
- 狀態相關：`status-*`

### 8.3 響應式設計

| 斷點 | 調整 |
|------|------|
| > 768px | filter-bar 橫向排列，tag 篩選 dropdown 固定寬度 300px |
| <= 768px | filter-bar 垂直堆疊，dropdown 全寬 |
| <= 480px | 狀態 chips 換行顯示，tag 欄位隱藏（僅展開時顯示） |

### 8.4 狀態 Badge 樣式

Badge 樣式遵循 design-system-spec.md 3.1 節定義：淡色底（主色 15% alpha）+ 深色字（主色原色）。

```css
/* 色值引用 design-system-spec.md Token，勿硬編碼修改 */
.status-unread    { background-color: rgba(227,242,253,0.15); color: #E3F2FD; } /* primaryLightest */
.status-reading   { background-color: rgba(33,150,243,0.15);  color: #2196F3; } /* primary */
.status-finished  { background-color: rgba(76,175,80,0.15);   color: #4CAF50; } /* positive */
.status-queued    { background-color: rgba(100,181,246,0.15);  color: #64B5F6; } /* primaryMedium */
.status-abandoned { background-color: rgba(255,152,0,0.15);   color: #FF9800; } /* negative */
.status-reference { background-color: rgba(25,118,210,0.15);  color: #1976D2; } /* primaryDark */
```

---

## 9. 行為場景（Given-When-Then）

### 場景 1: 6 狀態篩選 - 基本切換

```
Given: 頁面已載入 100 本書，其中 30 本 unread、40 本 reading、30 本 finished
When: 使用者點擊「閱讀中」chip
Then: 表格只顯示 40 本 reading 書籍，displayedBooks 顯示 40，「閱讀中」chip 變為 active
```

### 場景 2: 6 狀態篩選 - 回到全部

```
Given: 目前篩選為「閱讀中」，顯示 40 本
When: 使用者再次點擊已 active 的「閱讀中」chip
Then: 回到「全部」，顯示 100 本
```

### 場景 3: Tag 顯示 - 正常顯示

```
Given: 書籍 A 有 2 個 tag（「小說」、「推理」）
When: 頁面渲染書籍 A 的 tag 欄位
Then: 顯示 2 個 tag chip，各自有 category 色彩
```

### 場景 4: Tag 顯示 - 超出摺疊

```
Given: 書籍 B 有 5 個 tag
When: 頁面渲染書籍 B 的 tag 欄位
Then: 顯示前 3 個 tag chip + 「+2」指示器
```

### 場景 5: Tag 顯示 - 無 tag

```
Given: 書籍 C 的 tagIds 為空陣列
When: 頁面渲染書籍 C 的 tag 欄位
Then: 顯示灰色「未分類」文字
```

### 場景 6: Tag 篩選 - OR 模式

```
Given: 已選 tag「小說」和「推理」，模式為 OR
When: 篩選執行
Then: 顯示有「小說」或「推理」tag 的所有書籍
```

### 場景 7: Tag 篩選 - AND 模式

```
Given: 已選 tag「小說」和「推理」，模式為 AND
When: 篩選執行
Then: 只顯示同時有「小說」和「推理」tag 的書籍
```

### 場景 8: 三重組合篩選

```
Given: 狀態篩選為「閱讀中」，tag 篩選選中「小說」(OR)，搜尋框輸入「三體」
When: 篩選管線執行
Then: 只顯示 readingStatus=reading 且有「小說」tag 且書名含「三體」的書籍
```

### 場景 9: 篩選結果為空

```
Given: 狀態篩選為「已放棄」，系統中無 abandoned 書籍
When: 篩選執行
Then: 表格顯示空狀態訊息「沒有符合條件的書籍...」
```

### 場景 10: 無 tag category 時的 tag 篩選 widget

```
Given: 系統中無任何 tag category
When: 使用者開啟 tag 篩選 dropdown
Then: 顯示「尚無標籤分類」提示，無 checkbox
```

---

## 10. 驗收標準

- [ ] 6 狀態篩選 bar 顯示於搜尋框下方，6 個狀態 + 「全部」按鈕
- [ ] 每個狀態 chip 顯示對應書籍數量
- [ ] 點擊狀態 chip 正確篩選，再次點擊回到全部
- [ ] 表格新增 Tag 欄位，正確顯示 tag chip（含 category 色彩）
- [ ] tag 超過 3 個時正確摺疊，點擊 +N 可展開
- [ ] 無 tag 書籍顯示「未分類」
- [ ] tag 篩選 dropdown 按 category 分組，支援多選
- [ ] AND/OR 模式切換正確運作
- [ ] 三重組合篩選（狀態 + tag + 文字搜尋）正確運作
- [ ] 篩選結果為空時顯示適當空狀態訊息
- [ ] 頁面載入時間 < 3 秒（1000 本書 + tag 資料）
- [ ] 篩選響應時間 < 200ms
- [ ] 響應式設計在 768px 和 480px 斷點正確顯示
- [ ] 狀態欄位使用 readingStatus badge（非舊 status 字串）

---

## 11. 實作影響清單

| 檔案 | 變更類型 | 說明 |
|------|---------|------|
| `src/overview/overview.html` | 修改 | 新增 filter-bar、表格 th 新增 Tags 欄 |
| `src/overview/overview.css` | 新增 | 所有新增 CSS classes |
| `src/overview/overview-page-controller.js` | 修改 | 篩選狀態管理、tag 資料載入、渲染邏輯 |
| `src/overview/overview.js`（打包入口） | 可能修改 | 引入 BookSchemaV2、TagStorageAdapter |

新增依賴：
- `BookSchemaV2.READING_STATUS` — 狀態列舉和標籤對映
- `tag-storage-adapter` — 取得 tag 和 category 資料（或直接讀 chrome.storage）

---

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| v1.0 | 2026-04-05 | 初始版本（0.17.2-W1-003） |
| v1.0.1 | 2026-04-05 | 修正 storage key 名稱對齊 TagStorageAdapter 實際定義（tags、tag_categories） |
