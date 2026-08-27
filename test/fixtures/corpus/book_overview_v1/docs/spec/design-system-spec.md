---
id: SPEC-DESIGN-SYSTEM
title: "UI Design System 規格"
status: approved
source_proposal: PROP-008
created: "2026-04-08"
updated: "2026-06-05"
version: "2.0.0"
owner: ""
domain: ui
subdomain: design-system
related_usecases: [UC-05]
related_specs: [SPEC-OVERVIEW-TAG]
---

# UI Design System 規格

**版本**: 2.0.0
**建立日期**: 2026-04-08
**最後更新**: 2026-06-05（Phase 2 完成）
**來源**: PROP-008 統一 UI Design System（從 APP 專案移植）
**APP 基準**: `book_overview_app/lib/core/ui/ui_config.dart` + `flat_design_config.dart`

> **Phase 2 完成（2026-06-05）**：design-system.css 產生機制落地（build 自動產生）、頁面硬編碼色值全面改 CSS var()、漸層全面移除改扁平色、徽章配色更新為 WCAG AA 深字淺底新值。See tickets 0.19.1-W2-001 ~ W2-004。

---

## 1. 概述

本規格定義 Chrome Extension 的統一 UI Design System，所有色彩、間距、圓角、按鈕樣式、陰影等視覺規格皆從 Flutter APP 專案移植，確保跨平台視覺一致性。

**核心原則**：

| # | 原則 | 說明 |
|---|------|------|
| 1 | 三色系統 | 藍色主調 90% / 綠色正向 5% / 橘色負面 5% |
| 2 | 語意化命名 | 命名反映使用意圖（action/confirm/caution），非視覺層級 |
| 3 | 平面化設計 | 使用陰影取代邊框，石碑刻痕風格 |
| 4 | 4px 網格 | 所有間距為 4 的倍數 |
| 5 | Single Source of Truth | 所有視覺值定義於 `src/core/design-system/`，其他檔案引用 |

**實作檔案結構**：

```
src/core/design-system/
  ├── colors.js          # 配色系統
  ├── spacing.js         # 間距系統
  ├── typography.js      # 字體系統
  ├── components.js      # 元件尺寸
  ├── shadows.js         # 陰影系統
  └── index.js           # 統一匯出
```

---

## 2. 配色系統

### 2.1 藍色主色調（佔 UI 色彩 90%）

| Token | 色值 | 用途 |
|-------|------|------|
| `primary` | `#2196F3` | 主要按鈕、連結、action 按鈕 |
| `primaryLightest` | `#E3F2FD` | 背景區塊、notStarted badge |
| `primaryLight` | `#BBDEFB` | 次要區塊、neutral 按鈕背景 |
| `primaryMedium` | `#64B5F6` | 互動元素、queued badge |
| `primaryDark` | `#1976D2` | 選中狀態、reference badge |
| `primaryDarkest` | `#0D47A1` | 重點文字 |

### 2.2 正向色 — 綠色（佔 5%）

| Token | 色值 | 用途 |
|-------|------|------|
| `positive` | `#4CAF50` | 成功、確認、finished badge |
| `positiveLight` | `#C8E6C9` | 正向背景 |
| `positiveDark` | `#388E3C` | 正向強調 |

### 2.3 負面色 — 橘色（佔 5%）

| Token | 色值 | 用途 |
|-------|------|------|
| `negative` | `#FF9800` | 警告、錯誤、abandoned badge |
| `negativeLight` | `#FFE0B2` | 負面背景 |
| `negativeDark` | `#F57C00` | 負面強調 |

### 2.4 背景與表面色

| Token | 色值 | 用途 |
|-------|------|------|
| `background` | `#FAFAFA` | 頁面主背景 |
| `surface` | `#FFFFFF` | 卡片、表格表面 |
| `onBackground` | `#212121` | 主文字色 |
| `onSurface` | `#424242` | 次要文字色 |
| `onSurfaceMuted` | `#757575` | 輔助文字色 |

### 2.5 功能色

| Token | 色值 | 用途 |
|-------|------|------|
| `tagDefault` | `#808080` | Tag Category 預設色 |

### 2.6 品牌梯度（DEPRECATED）

> **DEPRECATED — 0.19.1-W2-001 D2 決策廢棄**：全專案 UI 無漸層色（W1 章程）。以下 token 已廢棄，CSS 中改用扁平色替代。

| Token | 色值 | 狀態 |
|-------|------|------|
| `gradientStart` | `#2196F3`（primary） | DEPRECATED — 改用 `primary` |
| `gradientEnd` | `#1976D2`（primaryDark） | DEPRECATED — 改用 `primaryDark` |

~~CSS 表達：`linear-gradient(135deg, #2196F3 0%, #1976D2 100%)`~~

**取代舊值**：`#667eea` → `#764ba2`（紫色梯度已廢棄）

**D2 替代方案**：凡規格或實作使用漸層的場景，一律改用扁平色 `primary` (`#2196F3`) 或 `primaryDark` (`#1976D2`)。

---

## 3. ReadingStatus 配色

### 3.1 配色對照表

Badge 樣式：不透明淺色底（bg）+ 深色字（fg），全 6 狀態達 WCAG AA 4.5:1（D3 修正，0.19.1-W2-001）。

| 狀態 | 文字色（fg） | 背景色（bg） | 對比度 | CSS class |
|------|------------|------------|--------|-----------|
| unread | `#546E7A` | `#ECEFF1` | 4.68:1 | `status-unread` |
| queued | `#0D47A1` | `#BBDEFB` | 6.15:1 | `status-queued` |
| reading | `#0D47A1` | `#E3F2FD` | 7.56:1 | `status-reading` |
| finished | `#1B5E20` | `#C8E6C9` | 5.85:1 | `status-finished` |
| abandoned | `#804000` | `#FFE0B2` | 6.25:1 | `status-abandoned` |
| reference | `#311B92` | `#EDE7F6` | 10.20:1 | `status-reference` |

### 3.2 Badge HTML 結構

```html
<span class="reading-status-badge status-{readingStatus}">
  {中文標籤}
</span>
```

### 3.3 Badge CSS 規則（D3 修正後 — WCAG AA 深字淺底）

> **D3 設計變更（0.19.1-W2-001）**：舊設計「彩色文字 + 15% alpha 透明背景」對淺色狀態（unread 1.12:1）幾乎不可見，違反 WCAG AA 4.5:1。新設計改為「深色文字 + 不透明淺色背景」，6 狀態全達 WCAG AA。`colors.js` STATUS_COLORS 為 SSOT，下方 CSS 值與之對應。

```css
.reading-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;  /* UIBorderRadius.xs */
  font-size: 12px;
  font-weight: 500;
}

/* D3 新值：深字淺底，與 colors.js STATUS_COLORS 一致 */
.status-unread    { background-color: #ECEFF1; color: #546E7A; }
.status-queued    { background-color: #BBDEFB; color: #0D47A1; }
.status-reading   { background-color: #E3F2FD; color: #0D47A1; }
.status-finished  { background-color: #C8E6C9; color: #1B5E20; }
.status-abandoned { background-color: #FFE0B2; color: #804000; }
.status-reference { background-color: #EDE7F6; color: #311B92; }
```

### 3.4 中文標籤對照

| 狀態值 | 中文標籤 |
|-------|---------|
| `unread` | 未開始 |
| `queued` | 待讀 |
| `reading` | 閱讀中 |
| `finished` | 已完成 |
| `abandoned` | 已放棄 |
| `reference` | 參考用 |

### 3.5 與舊 spec 的差異（SPEC-OVERVIEW-TAG 需同步更新）

| 狀態 | 舊色 | 新色 | 變更原因 |
|------|------|------|---------|
| reading | `#F57C00`（橘） | `#2196F3`（藍） | 非負面語意，改用主色調 |
| queued | `#7B1FA2`（紫） | `#64B5F6`（中藍） | 紫色超出三色系統 |
| reference | `#00838F`（青） | `#1976D2`（深藍） | 青色超出三色系統 |
| abandoned | `#757575`（灰） | `#FF9800`（橘） | 放棄是負面語意 |

---

## 4. 語意化按鈕系統

### 4.1 五種按鈕類型

| 類型 | 語意 | 背景色 | 文字色 | 使用場景 |
|------|------|--------|-------|---------|
| **action** | 一般操作 | `primary` #2196F3 | 白色 | 儲存、提交、匯出、重新載入 |
| **confirm** | 正向確認 | `positive` #4CAF50 | 白色 | 確認匯入、完成操作 |
| **caution** | 警告操作 | `negative` #FF9800 | 白色 | 刪除書籍、清除資料 |
| **neutral** | 中性資訊 | `primaryLight` #BBDEFB | `primaryDark` #1976D2 | 取消、關閉 |
| **ghost** | 輔助低調 | 透明 | `primary` #2196F3 | 輔助連結、「了解更多」 |

### 4.2 按鈕 CSS 規則

```css
/* 共用按鈕基底 */
.btn {
  border: none;
  border-radius: 8px;    /* UIBorderRadius.sm */
  padding: 8px 16px;     /* UISpacing.sm / UISpacing.md */
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s ease;
}

.btn:hover { opacity: 0.9; }
.btn:active { opacity: 0.8; }

/* 語意化類型 */
.btn--action  { background-color: #2196F3; color: #FFFFFF; }
.btn--confirm { background-color: #4CAF50; color: #FFFFFF; }
.btn--caution { background-color: #FF9800; color: #FFFFFF; }
.btn--neutral { background-color: #BBDEFB; color: #1976D2; }
.btn--ghost   { background-color: transparent; color: #2196F3; }
```

### 4.3 按鈕尺寸

| 尺寸 | CSS class | 高度 | padding |
|------|-----------|------|---------|
| small | `btn--sm` | 36px | 4px 12px |
| medium（預設） | `btn--md` | 48px | 8px 16px |
| large | `btn--lg` | 56px | 12px 24px |

### 4.4 Extension 現有按鈕映射

| 現有按鈕 | 語意類型 | 說明 |
|---------|---------|------|
| 匯出 CSV | action | 一般操作 |
| 匯出 JSON | action | 一般操作 |
| 匯入 JSON | confirm | 正向操作（資料匯入） |
| 選取全部 | neutral | 中性操作 |
| 重新載入 | action | 一般操作 |

---

## 5. 間距系統

### 5.1 間距 Token（基於 4px 網格）

| Token | 值 | CSS Variable | 用途 |
|-------|-----|-------------|------|
| `xxs` | 2px | `--spacing-xxs` | 最小間距 |
| `xs` | 4px | `--spacing-xs` | 緊湊元素、badge padding |
| `sm` | 8px | `--spacing-sm` | 按鈕 padding、元素間距 |
| `md` | 16px | `--spacing-md` | 標準內容間距、卡片 padding |
| `lg` | 24px | `--spacing-lg` | 區塊間距 |
| `xl` | 32px | `--spacing-xl` | 大區塊間距 |
| `xxl` | 48px | `--spacing-xxl` | 頁面級間距 |

---

## 6. 圓角系統

| Token | 值 | CSS Variable | 用途 |
|-------|-----|-------------|------|
| `xs` | 4px | `--radius-xs` | tag chip、badge |
| `sm` | 8px | `--radius-sm` | 按鈕、輸入框、filter chip |
| `md` | 12px | `--radius-md` | 卡片 |
| `lg` | 16px | `--radius-lg` | 對話框 |
| `xl` | 20px | `--radius-xl` | 特大圓角 |

---

## 7. 字體系統

| Token | 值 | 用途 |
|-------|-----|------|
| `fontFamily` | `'PingFang SC', 'Microsoft YaHei', sans-serif` | 中文字體堆疊 |
| `headline3` | 24px | 頁面標題 |
| `titleLarge` | 20px | 區塊標題 |
| `titleMedium` | 18px | 卡片標題 |
| `titleSmall` | 16px | 小標題 |
| `bodyLarge` | 16px | 大內文 |
| `bodyMedium` | 14px | 標準內文 |
| `bodySmall` | 12px | 小內文、badge |
| `caption` | 12px | 說明文字 |
| `overline` | 10px | 上標文字 |

字重定義：

| Token | 值 |
|-------|-----|
| `light` | 300 |
| `regular` | 400 |
| `medium` | 500 |
| `semiBold` | 600 |
| `bold` | 700 |

---

## 8. 陰影系統（石碑刻痕風格）

### 8.1 基礎陰影

| Token | CSS box-shadow | 用途 |
|-------|---------------|------|
| `card` | `0 2px 8px rgba(33,150,243,0.08)` | 卡片 |
| `button` | `0 2px 6px rgba(33,150,243,0.12)` | 按鈕 |
| `floating` | `0 4px 12px rgba(33,150,243,0.16)` | 浮動選單 |
| `dialog` | `0 8px 16px rgba(33,150,243,0.16)` | 對話框 |

### 8.2 分割陰影（取代分隔線）

| Token | CSS box-shadow | 用途 |
|-------|---------------|------|
| `dividerSubtle` | `0 1px 2px rgba(33,150,243,0.06)` | 細分隔 |
| `dividerNormal` | `0 2px 4px rgba(33,150,243,0.10)` | 標準分隔 |
| `dividerStrong` | `0 3px 6px rgba(33,150,243,0.14)` | 粗分隔 |

### 8.3 石碑刻痕效果

| Token | 效果 | 用途 |
|-------|------|------|
| `raised` | 凸起（淺陰影向下） | 預設狀態、卡片 |
| `inset` | 凹陷（陰影向上） | 選中狀態、按下狀態 |
| `engraved` | 刻痕（上方高光 + 下方陰影） | 區塊分隔 |
| `pressed` | 按壓（緊貼陰影） | 按鈕按下瞬間 |

---

## 9. 元件尺寸

| 元件 | Small | Medium | Large |
|------|-------|--------|-------|
| 按鈕高度 | 36px | 48px | 56px |
| 輸入框高度 | - | 48px | 56px |
| 圖示 | 16px | 24px | 32px |

---

## 10. CSS Variables 定義

所有 token 透過 CSS Variables 提供，以便 CSS 檔案引用：

```css
:root {
  /* 配色 */
  --color-primary: #2196F3;
  --color-primary-lightest: #E3F2FD;
  --color-primary-light: #BBDEFB;
  --color-primary-medium: #64B5F6;
  --color-primary-dark: #1976D2;
  --color-primary-darkest: #0D47A1;
  --color-positive: #4CAF50;
  --color-positive-light: #C8E6C9;
  --color-positive-dark: #388E3C;
  --color-negative: #FF9800;
  --color-negative-light: #FFE0B2;
  --color-negative-dark: #F57C00;
  --color-background: #FAFAFA;
  --color-surface: #FFFFFF;
  --color-on-background: #212121;
  --color-on-surface: #424242;
  --color-on-surface-muted: #757575;
  --color-tag-default: #808080;

  /* 間距 */
  --spacing-xxs: 2px;
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
  --spacing-xl: 32px;
  --spacing-xxl: 48px;

  /* 圓角 */
  --radius-xs: 4px;
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
  --radius-xl: 20px;

  /* 字體 */
  --font-family: 'PingFang SC', 'Microsoft YaHei', sans-serif;

  /* 梯度：DEPRECATED — D2 廢棄，改用扁平色 --color-primary / --color-primary-dark */
  /* --gradient-primary: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); */
}
```

---

## 11. 跨平台對齊要求

### 11.1 APP 端同步修改（book_overview_app follow-up）

> **D4 決策（0.19.1-W2-001）**：APP 端對齊不納入本次，標為 `book_overview_app` follow-up。原因：跨 repo 範圍蔓延，本 Wave 聚焦 Chrome Extension。

| 檔案 | 修改 | 狀態 |
|------|------|------|
| `reading_status_badge.dart` | D3 新配色：深字淺底 6 組（對應 STATUS_COLORS 新值） | **book_overview_app follow-up** |
| `ui_config.dart` | 漸層 token 對應廢棄 | **book_overview_app follow-up** |

### 11.2 Extension 端需更新的現有檔案

| 檔案 | 變更 |
|------|------|
| `src/overview/overview.css` | 狀態色、梯度色、背景色改為 CSS Variables |
| `src/popup/popup.html` | inline style 梯度和色彩改為 CSS Variables |
| `src/popup/popup.js` | 動態色彩改為引用 design-system |
| `src/data-management/TagSchema.js` | DEFAULT_COLOR 引用 design-system |
| `src/storage/adapters/tag-storage-adapter.js` | DEFAULT_CATEGORY_COLOR 引用 design-system |
| `src/ui/search/tag-resolver.js` | FALLBACK_CATEGORY_COLOR 引用 design-system |
| `src/background/.../theme-management-service.js` | 主題色改為引用 design-system |
| `docs/spec/overview-tag-display-spec.md` | 狀態色彩表更新為本 spec 定義值 |

---

## 12. 驗收標準

- [ ] `src/core/design-system/colors.js` 存在且匯出完整配色 token
- [ ] 所有色值與 APP `ui_config.dart` UIColors 一致
- [ ] 3 個重複 DEFAULT_COLOR 合併為單一引用
- [ ] ReadingStatus badge 使用本 spec 定義的 6 狀態配色
- [ ] 品牌梯度從紫色更換為藍色系
- [ ] CSS Variables 定義於 `:root`
- [ ] 現有硬編碼色值替換為 CSS Variables 引用
- [ ] 5 種語意化按鈕 CSS class 可用
- [ ] APP 端 reference badge 色已更新為 primaryDark
- [ ] 測試中的色彩驗證引用 design-system 常數，非硬編碼值

---

## 13. 實施影響清單

| 檔案 | 變更類型 | Phase |
|------|---------|-------|
| `src/core/design-system/colors.js` | 新增 | 1 |
| `src/core/design-system/spacing.js` | 新增 | 1 |
| `src/core/design-system/typography.js` | 新增 | 1 |
| `src/core/design-system/shadows.js` | 新增 | 2 |
| `src/core/design-system/components.js` | 新增 | 2 |
| `src/core/design-system/index.js` | 新增 | 1 |
| `src/core/design-system/design-system.css` | 新增 | 2 |
| `src/data-management/TagSchema.js` | 修改 | 1 |
| `src/storage/adapters/tag-storage-adapter.js` | 修改 | 1 |
| `src/ui/search/tag-resolver.js` | 修改 | 1 |
| `src/overview/overview.css` | 修改 | 2 |
| `src/popup/popup.html` | 修改 | 2 |
| `src/popup/popup.js` | 修改 | 2 |
| `src/background/.../theme-management-service.js` | 修改 | 1 |
| `docs/spec/overview-tag-display-spec.md` | 修改 | 1 |

---

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| v2.0.0 | 2026-06-05 | Phase 2 完成：§2.6 漸層 token 標記 DEPRECATED、§3.1/3.3 徽章配色更新為 D3 WCAG AA 深字淺底新值（6 組）、§10 梯度 CSS var 標記廢棄、§11.1 APP 對齊改標 book_overview_app follow-up（ticket 0.19.1-W2-001.4） |
| v1.0.0 | 2026-04-08 | 初始版本（從 PROP-008 v2.1 轉為正式規格） |
