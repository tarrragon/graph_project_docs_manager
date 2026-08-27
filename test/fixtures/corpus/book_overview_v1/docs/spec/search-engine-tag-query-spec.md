---
id: SPEC-SEARCH-TAG
title: "SearchEngine Tag-based 查詢適配規格"
status: approved
source_proposal: PROP-007
created: "2026-04-05"
updated: "2026-04-05"
version: "1.0.0"
owner: ""
domain: extraction
subdomain: search
related_usecases: [UC-04]
related_specs: []
---

# SearchEngine Tag-based 查詢適配規格

**Ticket**: 0.17.2-W1-002
**版本**: v0.17.2
**狀態**: Phase 1 設計完成

---

## 1. Purpose

v0.17.0 完成 Tag-based Book Model 重構後，書籍的 tag 從字串陣列（`book.tags: string[]`）改為 ID 參考（`book.tagIds: string[]`），Tag 成為獨立實體（TagSchema）。現有 SearchEngine 和 FilterEngine 需要適配新 model，支援以 tag 作為篩選維度。

**核心問題**：使用者需要按 tag 篩選書籍，支援多 tag 組合查詢（AND/OR），並可與文字搜尋同時使用。

---

## 2. 現有架構分析

### 2.1 現有模組職責

| 模組 | 職責 | Tag 現況 |
|------|------|---------|
| SearchEngine | 文字搜尋（title, author, tags 字串匹配） | 使用舊 `book.tags`（字串陣列），需遷移至 `tagIds` |
| SearchIndexManager | 索引建構（titleIndex, authorIndex, tagIndex） | tagIndex 索引舊字串 tag，需改為 tagId 索引 |
| FilterEngine | 屬性篩選（status, category, progressRange, date） | 無 tag 篩選 |

### 2.2 設計決策：Tag 篩選歸屬 FilterEngine

Tag 篩選是「屬性篩選」而非「文字搜尋」。使用者選擇特定 tag 進行精確篩選，與 status/category 篩選同質。因此 tag 篩選邏輯新增於 **FilterEngine**，而非 SearchEngine。

SearchEngine 的文字搜尋仍保留 tag 名稱的文字匹配能力（輸入「科幻」可搜到含「科幻」tag 的書），但需從字串匹配改為 tagId 解析後比對 tag 名稱。

---

## 3. 資料結構

### 3.1 Book（BookSchemaV2 相關欄位）

```javascript
{
  id: 'book-001',          // string, required
  title: '...',            // string, required
  tagIds: ['tag-01', 'tag-02'],  // string[], optional, default []
  // ... 其他欄位省略
}
```

### 3.2 Tag（TagSchema）

```javascript
{
  id: 'tag-01',            // string, required
  name: '科幻',            // string, required, maxLength 50
  categoryId: 'cat-01',   // string, required
  isSystem: false,         // boolean
  // ... 時間戳省略
}
```

### 3.3 TagCategory（TagCategorySchema）

```javascript
{
  id: 'cat-01',            // string, required
  name: '類別',            // string, required, maxLength 50
  color: '#808080',        // string, hex color
  isSystem: false,         // boolean
  // ... 時間戳省略
}
```

---

## 4. API 介面設計

### 4.1 FilterEngine 新增 tag 篩選

#### 4.1.1 filters 物件擴展

現有 `applyFilters(books, filters)` 的 `filters` 參數新增 `tagIds` 和 `tagOperator` 欄位：

```javascript
/**
 * @typedef {Object} Filters
 * @property {string}   [status]        - 閱讀狀態篩選（現有）
 * @property {string}   [category]      - 書籍類型篩選（現有）
 * @property {Object}   [progressRange] - 進度範圍篩選（現有）
 * @property {string}   [lastReadAfter] - 日期篩選（現有）
 * @property {string}   [lastReadBefore]- 日期篩選（現有）
 * @property {string[]} [tagIds]        - Tag ID 陣列（新增）
 * @property {string}   [tagOperator]   - Tag 邏輯運算子（新增）'AND' | 'OR'，預設 'OR'
 * @property {string[]} [tagCategoryIds]- TagCategory ID 篩選（新增）篩選屬於指定分類的 tag
 */
```

#### 4.1.2 tag 篩選方法

```javascript
/**
 * 依 tagIds 篩選書籍
 *
 * @param {Array<Book>} books - 書籍陣列
 * @param {string[]} tagIds - 要篩選的 tag ID 陣列
 * @param {string} operator - 'AND' | 'OR'
 * @returns {Array<Book>} 篩選後的書籍
 *
 * AND: 書籍必須同時包含所有指定 tagIds
 * OR:  書籍包含任一指定 tagId 即匹配
 */
_applyTagFilter(books, tagIds, operator = 'OR')
```

#### 4.1.3 tagCategory 篩選方法

```javascript
/**
 * 依 tagCategoryId 篩選書籍
 * 需要 TagResolver 將 categoryId 展開為該分類下所有 tagIds，再套用 OR 邏輯
 *
 * @param {Array<Book>} books - 書籍陣列
 * @param {string[]} tagCategoryIds - TagCategory ID 陣列
 * @param {Function} resolveCategoryToTagIds - categoryId => tagId[] 解析函式
 * @returns {Array<Book>} 篩選後的書籍
 */
_applyTagCategoryFilter(books, tagCategoryIds, resolveCategoryToTagIds)
```

### 4.2 FilterEngine 建構函式擴展

```javascript
/**
 * @param {Object} options
 * @param {Object}   options.eventBus
 * @param {Object}   options.logger
 * @param {Object}   [options.config]
 * @param {Function} [options.tagResolver] - (tagId) => Tag | null，用於解析 tag 名稱
 * @param {Function} [options.categoryResolver] - (categoryId) => tagId[]，用於展開分類
 */
constructor(options = {})
```

### 4.3 _applyFilterLogic 擴展

在現有 filterSteps 陣列中新增 tag 篩選步驟：

```javascript
const filterSteps = [
  { condition: filters.status, method: this._applyStatusFilter.bind(this), args: [filters.status] },
  { condition: filters.category, method: this._applyCategoryFilter.bind(this), args: [filters.category] },
  { condition: filters.progressRange, method: this._applyProgressRangeFilter.bind(this), args: [filters.progressRange] },
  { condition: filters.lastReadAfter, method: this._applyDateFilter.bind(this), args: [filters.lastReadAfter, 'after'] },
  { condition: filters.lastReadBefore, method: this._applyDateFilter.bind(this), args: [filters.lastReadBefore, 'before'] },
  // 新增
  { condition: filters.tagIds, method: this._applyTagFilter.bind(this), args: [filters.tagIds, filters.tagOperator || 'OR'] },
  { condition: filters.tagCategoryIds, method: this._applyTagCategoryFilter.bind(this), args: [filters.tagCategoryIds, this._categoryResolver] }
]
```

### 4.4 SearchEngine tag 文字搜尋適配

SearchEngine 的文字搜尋需要從舊的 `book.tags`（字串陣列）遷移到 `book.tagIds`（ID 陣列）+ tag 名稱解析。

#### 4.4.1 SearchEngine 建構函式擴展

```javascript
/**
 * @param {Object} options
 * @param {Object}   options.indexManager
 * @param {Object}   options.eventBus
 * @param {Object}   options.logger
 * @param {Object}   [options.config]
 * @param {Function} [options.getCurrentTime]
 * @param {Function} [options.tagResolver] - (tagId) => Tag | null（新增）
 */
constructor(options = {})
```

#### 4.4.2 _matchesSearchCriteria 修改

現有程式碼檢查 `book.tags`（字串陣列）。修改為：

```javascript
// 舊：直接比對 book.tags 字串
// 新：透過 tagResolver 將 book.tagIds 解析為 tag 名稱後比對
_matchesSearchCriteria(book, query) {
  // ... title, author 比對不變 ...

  // tag 名稱比對（新邏輯）
  if (book.tagIds && Array.isArray(book.tagIds) && this._tagResolver) {
    for (const tagId of book.tagIds) {
      const tag = this._tagResolver(tagId)
      if (tag && tag.name) {
        const tagNameLower = tag.name.toLowerCase()
        if (tagNameLower.includes(query)) return true
        if (this.config.enableFuzzySearch) {
          const fuzzyScore = this._calculateFuzzyScore(tagNameLower, query)
          if (fuzzyScore > 0) return true
        }
      }
    }
  }

  // 向下相容：如果有舊 book.tags 且無 tagResolver，使用舊邏輯
  if (book.tags && Array.isArray(book.tags) && !this._tagResolver) {
    // ... 現有邏輯保留 ...
  }

  return false
}
```

#### 4.4.3 SearchIndexManager tagIndex 適配

tagIndex 從索引 tag 字串改為索引 tag 名稱（透過 tagResolver 解析）：

```javascript
/**
 * 建構 tag 索引
 * @param {Array<Book>} books
 * @param {Function} tagResolver - (tagId) => Tag | null
 */
_buildTagIndex(books, tagResolver) {
  for (const book of books) {
    if (book.tagIds && Array.isArray(book.tagIds)) {
      for (const tagId of book.tagIds) {
        const tag = tagResolver ? tagResolver(tagId) : null
        if (tag && tag.name) {
          const normalizedName = tag.name.toLowerCase()
          // 索引完整名稱
          this._addToIndex(this.tagIndex, normalizedName, book)
          // 索引分詞
          const words = normalizedName.split(/\s+/)
          for (const word of words) {
            if (word.length > 0) {
              this._addToIndex(this.tagIndex, word, book)
            }
          }
        }
      }
    }
  }
}
```

---

## 5. AND/OR 語義定義

### 5.1 運算子語義

| 運算子 | 語義 | 範例 |
|--------|------|------|
| OR（預設） | 書籍包含**任一**指定 tag 即匹配 | tagIds: ['科幻', '推理'] → 含科幻或推理的書 |
| AND | 書籍必須**同時包含所有**指定 tag | tagIds: ['科幻', '推理'] → 同時含科幻和推理的書 |

### 5.2 實作邏輯

```javascript
_applyTagFilter(books, tagIds, operator = 'OR') {
  if (!tagIds || tagIds.length === 0) return books

  if (operator === 'AND') {
    return books.filter(book => {
      const bookTagIds = book.tagIds || []
      return tagIds.every(tagId => bookTagIds.includes(tagId))
    })
  }

  // OR（預設）
  return books.filter(book => {
    const bookTagIds = book.tagIds || []
    return tagIds.some(tagId => bookTagIds.includes(tagId))
  })
}
```

### 5.3 預設值選擇理由

預設 OR：使用者通常期望「顯示更多結果」。選擇多個 tag 時，OR 語義更符合「我想看這些類型的書」的直覺。AND 適用於進階精確篩選場景。

---

## 6. 文字搜尋 + Tag 篩選組合執行流程

### 6.1 組合邏輯

文字搜尋（SearchEngine）和 tag 篩選（FilterEngine）的結果取**交集**（AND 語義）：

```
最終結果 = 文字搜尋結果 AND tag 篩選結果
```

使用者輸入搜尋文字「程式」+ 選擇 tag「JavaScript」= 含「程式」文字且標記為「JavaScript」的書。

### 6.2 執行順序

```
1. 使用者輸入查詢條件
   ├── textQuery: "程式"
   ├── tagIds: ["tag-js"]
   └── tagOperator: "OR"

2. SearchEngine.search(textQuery, allBooks)
   → textResults（文字匹配結果）

3. FilterEngine.applyFilters(textResults, { tagIds, tagOperator, ...otherFilters })
   → finalResults（篩選後結果）

4. 特殊情況：
   - 僅文字搜尋（無 tag）：跳過 FilterEngine tag 篩選步驟
   - 僅 tag 篩選（無文字）：SearchEngine 空查詢回傳所有書 → FilterEngine 篩選
   - 無任何條件：回傳所有書籍
```

### 6.3 呼叫端整合（SearchCoordinator 層級）

組合邏輯由 SearchCoordinator（或 Overview 頁面 Controller）負責串接，不在 SearchEngine 或 FilterEngine 內部處理：

```javascript
async executeSearch(textQuery, filters) {
  // Step 1: 文字搜尋
  const textResults = await this.searchEngine.search(textQuery, this.allBooks)

  // Step 2: 屬性篩選（含 tag 篩選）
  const filterResult = await this.filterEngine.applyFilters(textResults, filters)

  return filterResult
}
```

---

## 7. Tag 索引策略

### 7.1 tagId-to-bookIds 反向索引

為加速 tag 篩選，建議在 FilterEngine 或獨立模組中維護反向索引：

```javascript
// tagId → Set<bookId>
const tagToBookIndex = new Map()
// 範例: 'tag-01' → Set(['book-001', 'book-003', 'book-007'])
```

#### 7.1.1 索引建構

```javascript
/**
 * 建構 tag 反向索引
 * @param {Array<Book>} books
 * @returns {Map<string, Set<string>>} tagId → bookId Set
 */
function buildTagToBookIndex(books) {
  const index = new Map()
  for (const book of books) {
    if (book.tagIds && Array.isArray(book.tagIds)) {
      for (const tagId of book.tagIds) {
        if (!index.has(tagId)) {
          index.set(tagId, new Set())
        }
        index.get(tagId).add(book.id)
      }
    }
  }
  return index
}
```

#### 7.1.2 索引使用時機

| 書籍數量 | 策略 |
|---------|------|
| < 100 | 直接線性篩選，不建索引 |
| >= 100 | 使用反向索引加速 |

**理由**：Chrome Extension 場景中，個人書庫通常 100-2000 本。100 本以下線性篩選足夠快（< 1ms），建索引的記憶體開銷不值得。

### 7.2 索引更新策略

| 事件 | 索引操作 |
|------|---------|
| 書籍新增 | 將書籍 tagIds 加入反向索引 |
| 書籍刪除 | 從反向索引移除該書籍 |
| 書籍 tag 變更 | 移除舊 tagIds 映射，加入新 tagIds 映射 |
| Tag 刪除 | 從反向索引移除該 tagId 項目 |

---

## 8. 邊界情況處理

### 8.1 書籍無 tag

| 情境 | 行為 |
|------|------|
| `book.tagIds` 為 `undefined` | 視為空陣列 `[]`，不匹配任何 tag 篩選 |
| `book.tagIds` 為 `[]` | 不匹配任何 tag 篩選 |
| 篩選結果為空 | 回傳空陣列，UI 顯示「無符合條件的書籍」 |

### 8.2 已刪除的 tag

| 情境 | 行為 |
|------|------|
| 書籍的 `tagIds` 包含已刪除的 tagId | 該 tagId 在篩選時不匹配（因為不在使用者選擇的 tagIds 中） |
| tagResolver 回傳 null | 文字搜尋時跳過該 tag，不影響其他 tag 匹配 |
| 篩選面板不顯示已刪除 tag | UI 層職責，不在本規格範圍 |

### 8.3 無效輸入

| 輸入 | 行為 |
|------|------|
| `tagIds: null` | 跳過 tag 篩選，等同未設定 |
| `tagIds: []` | 跳過 tag 篩選，等同未設定 |
| `tagIds` 含非字串元素 | 忽略非字串元素，只處理有效字串 |
| `tagOperator` 為無效值 | 使用預設值 'OR' |
| `tagIds` 含不存在的 tagId | 該 tagId 不匹配任何書籍，不報錯 |

### 8.4 效能邊界

| 情境 | 限制 |
|------|------|
| tagIds 數量上限 | MAX_TAGS_PER_BOOK（100），超過時截斷並記錄 warning |
| 書籍數量上限 | 沿用 SearchEngine.config.maxResults（1000） |

---

## 9. 效能基準與量測

### 9.1 效能目標

| 操作 | 目標 | 量測方式 |
|------|------|---------|
| 純 tag 篩選（1000 本書，5 個 tag，OR） | < 50ms | performance.now() 計時 |
| 純 tag 篩選（1000 本書，5 個 tag，AND） | < 50ms | performance.now() 計時 |
| 文字搜尋 + tag 篩選組合（1000 本書） | < 1000ms | 端到端計時（符合 UC-06 要求） |
| tag 反向索引建構（1000 本書） | < 100ms | 索引建構計時 |

### 9.2 效能量測整合

沿用 FilterEngine 現有的統計機制（`this.statistics`），新增 tag 篩選相關統計：

```javascript
// FilterEngine.statistics 擴展
{
  // ... 現有統計 ...
  tagFilterCount: 0,       // tag 篩選執行次數
  tagFilterTotalTime: 0,   // tag 篩選累計時間
  tagFilterAvgTime: 0,     // tag 篩選平均時間
  indexHitRate: 0           // 反向索引命中率
}
```

### 9.3 效能警告

tag 篩選時間超過 `performanceWarningThreshold`（預設 1000ms）時，透過 eventBus 發送警告事件：

```javascript
this.eventBus.emit('FILTER.PERFORMANCE.WARNING', {
  type: 'slow_tag_filter',
  filterTime,
  threshold: this.config.performanceWarningThreshold,
  tagCount: tagIds.length,
  bookCount: books.length,
  timestamp: Date.now()
})
```

---

## 10. 向下相容

### 10.1 遷移策略

| 階段 | 行為 |
|------|------|
| 遷移前（書籍有 `tags` 無 `tagIds`） | SearchEngine 沿用舊 `book.tags` 字串匹配 |
| 遷移後（書籍有 `tagIds`） | SearchEngine 使用 `tagResolver` 解析 tag 名稱 |
| 混合狀態 | 優先使用 `tagIds`，若無則回退到 `tags` |

### 10.2 tagResolver 缺失時

若未注入 `tagResolver`：
- SearchEngine 文字搜尋：跳過 tag 名稱匹配（不影響 title/author 搜尋）
- FilterEngine tag 篩選：純 tagId 比對（不需要 resolver）
- SearchIndexManager：跳過 tag 索引建構，記錄 warning

---

## 11. 行為場景（Given-When-Then）

### 場景 1: OR 邏輯 tag 篩選

```
Given: 書庫中有 3 本書
  - Book A: tagIds = ['tag-sf', 'tag-novel']
  - Book B: tagIds = ['tag-sf']
  - Book C: tagIds = ['tag-history']
When: 使用者以 tagIds=['tag-sf', 'tag-history'], tagOperator='OR' 篩選
Then: 回傳 Book A, Book B, Book C（任一 tag 匹配即可）
```

### 場景 2: AND 邏輯 tag 篩選

```
Given: 同場景 1 的書庫
When: 使用者以 tagIds=['tag-sf', 'tag-novel'], tagOperator='AND' 篩選
Then: 僅回傳 Book A（同時包含兩個 tag）
```

### 場景 3: 文字搜尋 + tag 篩選組合

```
Given: 書庫中有 3 本書
  - Book A: title='JavaScript 入門', tagIds=['tag-prog']
  - Book B: title='JavaScript 進階', tagIds=['tag-prog', 'tag-advanced']
  - Book C: title='Python 入門', tagIds=['tag-prog']
When: 使用者搜尋文字 'JavaScript' + tagIds=['tag-prog']
Then: 回傳 Book A, Book B（文字匹配 AND tag 匹配的交集）
```

### 場景 4: 無 tag 的書籍

```
Given: Book D: tagIds = [] (或 undefined)
When: 使用者以任何 tagIds 篩選
Then: Book D 不出現在結果中
```

### 場景 5: 已刪除 tag 的處理

```
Given: Book E: tagIds = ['tag-deleted', 'tag-sf']
  - 'tag-deleted' 的 Tag 物件已從 TagStorage 刪除
When: 使用者以 tagIds=['tag-sf'] 篩選
Then: Book E 出現在結果中（因為仍有 'tag-sf'）
```

### 場景 6: 空 tagIds 篩選條件

```
Given: 書庫中有書籍
When: 使用者以 tagIds=[] 或 tagIds=null 篩選
Then: 跳過 tag 篩選，回傳所有書籍（由其他篩選條件決定）
```

### 場景 7: tag 文字搜尋

```
Given: Book F: tagIds=['tag-sf'], tag-sf 的名稱為 '科幻小說'
When: 使用者在搜尋框輸入 '科幻'
Then: Book F 出現在搜尋結果中（透過 tagResolver 解析 tag 名稱後比對）
```

---

## 12. Phase 2 Handoff 驗收標準

- [ ] FilterEngine `_applyTagFilter` 函式簽名和 AND/OR 語義明確
- [ ] FilterEngine filters 物件擴展（tagIds, tagOperator, tagCategoryIds）明確
- [ ] SearchEngine `_matchesSearchCriteria` 的 tagId 解析邏輯明確
- [ ] SearchIndexManager tagIndex 適配方案明確
- [ ] 文字搜尋 + tag 篩選的組合邏輯（交集）明確
- [ ] 所有邊界情況（無 tag、已刪除 tag、無效輸入）有明確處理方式
- [ ] 效能目標量化（< 1s for 1000 books）
- [ ] 7 個行為場景覆蓋正常流程、異常流程、邊界條件
- [ ] 向下相容策略（tagResolver 缺失、混合狀態）明確
