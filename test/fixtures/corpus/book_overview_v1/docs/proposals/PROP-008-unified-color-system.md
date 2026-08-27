---
id: PROP-008
title: "統一 UI Design System（從 APP 專案移植）"
status: confirmed
evaluation_level: heavy
proposed: "2026-04-08"
confirmed: "2026-04-08"
source: cross-project
target_version: "v0.17.x ~ v0.20.x（分階段）"
reference: "Flutter App 專案 lib/core/ui/ui_config.dart + flat_design_config.dart"
---

# PROP-008: 統一 UI Design System（從 APP 專案移植）

## 1. 問題陳述

### 1.1 發現背景

W2-007.2 Tag 顯示元件實作中，測試硬編碼 `rgb(233, 30, 99)` 驗證色彩，與 fixture 的 `#e91e63` 語義斷裂。深入調查發現 Chrome Extension 專案缺乏統一的 UI 設計系統，而 APP 專案（Flutter）已有完整的 Design System。

### 1.2 Chrome Extension 現況

| 指標 | 數值 |
|------|------|
| 硬編碼色值總數 | 89+ |
| 涉及檔案數 | 10+ |
| 重複定義的色值 | 7+ 組 |
| CSS Variables 數量 | 0 |
| 統一設計規格文件 | 無 |
| Status 色彩缺口 | 3/6 未實作 |

### 1.3 根本問題

Chrome Extension 和 Flutter APP 是同一產品的兩個平台，但：
- Extension 沒有設計系統，色彩、按鈕、間距全部硬編碼散落各處
- APP 已有完整的 8 子系統設計規格（UIColors / UISpacing / UIBorderRadius / ...）
- 兩個平台的視覺語言不一致（Extension 用紫色梯度 #667eea，APP 用藍色系 #2196F3）
- Spec 文件自行定義色彩 → CSS 硬編碼 → test 硬編碼 → 三層各自獨立

---

## 2. APP 專案已有的設計系統（基準）

來源：`~/project/book_overview_app/lib/core/ui/`

### 2.1 配色系統（UIColors）

**三色系統原則**：藍色主調 90% / 綠色正向 5% / 橘色負面 5%

| 分類 | 色彩 | 色值 | 用途 |
|------|------|------|------|
| **藍色主色調** | primary | `#2196F3` | 主要按鈕、連結 |
| | primaryLightest | `#E3F2FD` | 背景區塊 |
| | primaryLight | `#BBDEFB` | 次要區塊、neutral 按鈕 |
| | primaryMedium | `#64B5F6` | 互動元素 |
| | primaryDark | `#1976D2` | 選中狀態 |
| | primaryDarkest | `#0D47A1` | 重點文字 |
| **正向色** | positive | `#4CAF50` | 成功、確認、完成 |
| | positiveLight | `#C8E6C9` | 正向背景 |
| | positiveDark | `#388E3C` | 正向強調 |
| **負面色** | negative | `#FF9800` | 警告、錯誤、刪除 |
| | negativeLight | `#FFE0B2` | 負面背景 |
| | negativeDark | `#F57C00` | 負面強調 |
| **背景/表面** | backgroundLight | `#FAFAFA` | 主背景 |
| | surfaceLight | `#FFFFFF` | 卡片表面 |
| | onBackgroundLight | `#212121` | 主文字 |
| | onSurfaceLight | `#424242` | 次要文字 |
| | onSurfaceMuted | `#757575` | 輔助文字 |

### 2.2 語意化按鈕系統（FlatDesignConfig）

| 按鈕類型 | 語意 | 色彩 | 使用場景 |
|---------|------|------|---------|
| **action** | 一般操作 | 藍色 primary | 儲存、提交、執行 |
| **confirm** | 正向確認 | 綠色 positive | 確認、完成、同意 |
| **caution** | 警告操作 | 橘色 negative | 刪除、移除、取消訂閱 |
| **neutral** | 中性資訊 | 淺藍 primaryLight | 取消、關閉、返回 |
| **ghost** | 輔助低調 | 透明 | 了解更多、輔助連結 |

### 2.3 間距系統（UISpacing）

基於 4dp 網格：

| Token | 值 | 用途 |
|-------|-----|------|
| xxs | 2dp | 最小間距 |
| xs | 4dp | 緊湊元素 |
| sm | 8dp | 按鈕 padding |
| md | 16dp | 標準內容間距 |
| lg | 24dp | 區塊間距 |
| xl | 32dp | 大區塊間距 |
| xxl | 48dp | 頁面級間距 |

### 2.4 圓角系統（UIBorderRadius）

| Token | 值 | 用途 |
|-------|-----|------|
| xs | 4dp | 小圓角（tag chip） |
| sm | 8dp | 標準圓角（按鈕、輸入框） |
| md | 12dp | 中等圓角（卡片） |
| lg | 16dp | 大圓角（對話框） |
| xl | 20dp | 特大圓角 |
| circular | 999dp | 圓形（頭像） |

### 2.5 元件尺寸（UIComponentSizes）

| 元件 | Small | Medium | Large |
|------|-------|--------|-------|
| 按鈕高度 | 36dp | 48dp | 56dp |
| 輸入框高度 | - | 48dp | 56dp |
| 圖示 | 16sp | 24sp | 32sp |

### 2.6 陰影系統（UIShadows — 石碑刻痕風格）

| 陰影類型 | 用途 |
|---------|------|
| card | 卡片浮起效果 |
| button | 按鈕互動效果 |
| floating | 浮動選單、FAB |
| dialog | 對話框 |
| raised | 凸起效果（預設狀態） |
| inset | 凹陷效果（選中/按下） |
| engraved | 刻痕效果（區塊分隔） |

### 2.7 設計原則

1. **平面化設計**：使用陰影取代邊框，石碑刻痕風格
2. **三色系統**：藍 90% / 綠 5% / 橘 5%，選色反映語意
3. **語意化命名**：命名反映使用意圖（action/confirm/caution），而非視覺層級（primary/secondary）
4. **4dp 網格**：所有間距為 4 的倍數

---

## 3. 提議方案

### 3.1 建立 Extension 端的 Design System

不是照搬 Flutter 程式碼（API 完全不同），而是**移植設計規格值**，用 JavaScript + CSS 重新表達。

```
src/core/design-system/
  ├── colors.js          # 配色系統（對齊 UIColors）
  ├── spacing.js         # 間距系統（對齊 UISpacing）
  ├── typography.js      # 字體系統（對齊 UITypography）
  ├── components.js      # 元件尺寸（對齊 UIComponentSizes）
  └── index.js           # 統一匯出

src/core/design-system/
  └── design-system.css  # CSS Variables 定義
```

### 3.2 colors.js 內容（對齊 APP UIColors）

```javascript
const COLORS = {
  // 藍色主色調系統（對齊 UIColors）
  primary:         '#2196F3',  // 標準藍 - 主要按鈕
  primaryLightest: '#E3F2FD',  // 最淺藍 - 背景區塊
  primaryLight:    '#BBDEFB',  // 淺藍 - 次要區塊
  primaryMedium:   '#64B5F6',  // 中藍 - 互動元素
  primaryDark:     '#1976D2',  // 深藍 - 選中狀態
  primaryDarkest:  '#0D47A1',  // 最深藍 - 重點文字

  // 正向色 - 綠色
  positive:      '#4CAF50',
  positiveLight: '#C8E6C9',
  positiveDark:  '#388E3C',

  // 負面色 - 橘色
  negative:      '#FF9800',
  negativeLight: '#FFE0B2',
  negativeDark:  '#F57C00',

  // 背景/表面
  background:      '#FAFAFA',
  surface:         '#FFFFFF',
  onBackground:    '#212121',
  onSurface:       '#424242',
  onSurfaceMuted:  '#757575',

  // Tag 預設色
  tagDefault: '#808080'
}
```

### 3.3 與 APP 專案的差異處理

| 面向 | APP（Flutter） | Extension（Chrome） | 處理方式 |
|------|---------------|--------------------|---------| 
| 色值 | 相同 | 相同 | 直接複用 |
| 單位 | dp/sp（ScreenUtil） | px/rem | 數值相同，單位轉換 |
| 陰影 | BoxShadow | CSS box-shadow | 值轉換為 CSS 語法 |
| 響應式 | ScreenUtil + LayoutType | CSS media queries | Chrome Extension 不需要（固定尺寸） |
| 石碑刻痕效果 | Flutter widget | CSS box-shadow | 轉換為 CSS |

### 3.4 ReadingStatus 配色方案（已確認）

以 APP 的 `ReadingStatusBadge` 三色系統為基準，全部 6 狀態映射到藍/綠/橘色系。

**Badge 樣式**：淡色底（主色 15% alpha）+ 深色字（主色原色），對齊 APP 的 `backgroundColor.withAlpha(0.15)` 邏輯。

| 狀態 | 主色（fg） | UIColors 常數 | 背景色（bg = 主色 15% alpha） | 語意 |
|------|----------|--------------|------|------|
| notStarted/unread | `#E3F2FD` | primaryLightest | `rgba(227,242,253,0.15)` | 中性/尚未開始 |
| queued | `#64B5F6` | primaryMedium | `rgba(100,181,246,0.15)` | 排隊等待 |
| reading | `#2196F3` | primary | `rgba(33,150,243,0.15)` | 進行中 |
| finished | `#4CAF50` | positive | `rgba(76,175,80,0.15)` | 正向完成 |
| abandoned | `#FF9800` | negative | `rgba(255,152,0,0.15)` | 負面放棄 |
| reference | `#1976D2` | primaryDark | `rgba(25,118,210,0.15)` | 參考用（深藍區分 reading） |

**與 Extension 現有 spec 的差異**：

| 狀態 | Extension spec 舊色 | 新色（對齊 APP） | 變更原因 |
|------|-------------------|----------------|---------|
| reading | `#F57C00`（橘） | `#2196F3`（藍） | 閱讀中非負面語意，改用主色調 |
| queued | `#7B1FA2`（紫） | `#64B5F6`（中藍） | 紫色超出三色系統 |
| reference | `#00838F`（青） | `#1976D2`（深藍） | 青色超出三色系統，用深藍區分 reading |
| abandoned | `#757575`（灰） | `#FF9800`（橘） | 放棄是負面語意，應用負面色 |

**APP 端同步修改**：`reading_status_badge.dart` 的 reference 從 `UIColors.primary` 改為 `UIColors.primaryDark`（解決 reading/reference 撞色問題）。

### 3.5 品牌梯度換色（已確認）

Extension 現有紫色梯度（`#667eea` → `#764ba2`）將替換為藍色系梯度，對齊 APP 設計系統：

| 項目 | 舊值 | 新值 |
|------|------|------|
| 梯度起始色 | `#667eea`（紫） | `#2196F3`（primary） |
| 梯度結束色 | `#764ba2`（深紫） | `#1976D2`（primaryDark） |

---

## 4. 分階段實施建議

### Phase 1：建立基礎 + 常數化（v0.17.x）

| 任務 | 說明 |
|------|------|
| 建立 `src/core/design-system/colors.js` | 從 APP UIColors 移植色值 |
| 建立 `src/core/design-system/spacing.js` | 從 APP UISpacing 移植間距 |
| 合併 3 個重複 DEFAULT_COLOR | 統一引用 `colors.tagDefault` |
| ThemeManagementService 改為引用 design-system | 消除重複定義 |
| 補齊 Status 色彩 CSS | 新增 queued/abandoned/reference |

**風險**：低（純常數化，行為不變）

### Phase 2：CSS Variables + 語意化按鈕（v0.18.x+）

| 任務 | 說明 |
|------|------|
| 建立 `design-system.css` | `:root` CSS Variables |
| 更新 overview.css / popup.html | 硬編碼色值 → `var(--color-xxx)` |
| 定義 5 種語意化按鈕 CSS class | action/confirm/caution/neutral/ghost |
| 定義間距和圓角 CSS Variables | `--spacing-sm`, `--radius-md` 等 |

**風險**：中（CSS 重構需視覺回歸測試）

### Phase 3：完整 Design System（v0.20.x+）

| 任務 | 說明 |
|------|------|
| Dark Mode CSS | `prefers-color-scheme` 媒體查詢 |
| 陰影系統 CSS | 石碑刻痕效果轉換為 CSS |
| Tag Category 預定義調色盤 | 8-12 個預設色供選擇 |
| Spec 文件全面更新 | 所有色彩/間距引用統一指向 design-system |

**風險**：中高（多層重構）

---

## 5. 不做的事

| 排除項目 | 原因 |
|---------|------|
| 照搬 Flutter 程式碼 | API 完全不同，只移植設計值 |
| ScreenUtil 響應式 | Chrome Extension popup/overview 是固定尺寸 |
| Tailwind/CSS-in-JS | Chrome Extension 環境不適合 |
| 重新設計配色 | 複用 APP 已定義的配色，不重新發明 |

---

## 6. 討論結果

### 已確認（2026-04-08）

| # | 問題 | 決策 |
|---|------|------|
| 1 | Status 色彩衝突（queued 紫 / reference 青超出三色系統） | 沿用三色系統，全部映射到藍/綠/橘。見 3.4 節配色表 |
| 2 | reading 狀態色（Extension spec 用橘色） | 對齊 APP，改用藍色 `#2196F3`。Extension spec 的橘色是當初隨機選的 |
| 3 | 品牌梯度（Extension 用紫色 #667eea） | 替換為藍色系 `#2196F3` → `#1976D2`。見 3.5 節 |
| 4 | APP reference 撞色 reading | reference 改用 primaryDark `#1976D2`，APP 端需同步修改 |
| 5 | Badge 樣式 | 淡色底 + 深色字（對齊 APP 的 15% alpha 邏輯） |

### 待確認

| # | 問題 | 備註 |
|---|------|------|
| 6 | Phase 1 版本歸屬 | v0.17.x 或 v0.18.x？ |
| 7 | CSS Variables 注入方式 | JS 注入 或 建置時生成？ |

---

## 7. 相關文件

| 文件 | 關聯 |
|------|------|
| APP `lib/core/ui/ui_config.dart` | 配色/間距/圓角/陰影/元件尺寸基準 |
| APP `lib/core/ui/flat_design_config.dart` | 語意化按鈕/卡片/對話框規格 |
| APP `docs/ui_design_specification.md` | UI 設計規格文件 |
| Extension `src/background/.../theme-management-service.js` | 現有主題色定義（待替換） |
| Extension `docs/spec/overview-tag-display-spec.md` | Status/Tag 色彩規格 |
| PROP-007 | Tag-based Model 重構 |

---

---

## 替代方案

> 本節為 heavy evaluation 必填章節，彙整候選方案評估的決策脈絡。

### 已評估的候選方案

| 方案 | 決策 | 理由 |
|------|------|------|
| 方案 A：從 APP 移植設計規格值（本提案） | 採用 | 設計一致性最高，只移植值不移植 API，成本可控 |
| 方案 B：完全自訂 Extension 專屬設計系統 | 不採用 | 重新發明配色耗時且兩平台視覺語言分歧風險高 |
| 方案 C：引入外部 CSS 框架（Tailwind/Bootstrap） | 不採用 | Chrome Extension 環境不適合（build 複雜度、CSP 限制） |
| 方案 D：維持現狀（硬編碼色值散落各處） | 不採用 | 89+ 硬編碼色值難維護，測試語意斷裂問題持續累積 |

### 不採用方案的邊界說明

- 方案 B 雖具最大彈性，但現有 APP 設計規格已成熟（8 子系統），重新設計的邊際收益遠低於對齊成本
- 方案 C 在 Chrome Extension MV3 的 CSP 限制下需要額外工程繞路，引入複雜度超過收益
- 方案 D 是現狀，色彩重複定義（7+ 組）與測試硬編碼的技術債持續累積，無法支撐後續多狀態擴充

---

## 失敗防護

> 本節為 heavy evaluation 必填章節，涵蓋主要失敗情境與對應防護措施。

### 失敗情境矩陣

| 失敗情境 | 失敗前兆 | 防護措施 |
|---------|---------|---------|
| CSS Variables 注入與 MV3 CSP 衝突 | popup 白屏或 console CSP 錯誤 | Phase 2 開始前先驗證注入方式（JS 注入 vs 建置時生成），確認 CSP 相容後再展開 |
| 色值移植錯誤導致視覺回歸 | E2E 截圖對比失敗或人工 review 發現色差 | Phase 1 純常數化（行為不變），以 Puppeteer E2E 截圖驗證視覺一致性 |
| APP 端設計系統後續更新導致兩端分歧 | APP UIColors 有新色但 Extension 未同步 | PROP-008 實施後在 design-system/ 加入 APP 版本標記，升級時必須 diff 對齊 |
| Phase 2 CSS 重構引入視覺破壞 | 按鈕色彩、間距視覺異常 | Phase 2 必須配合視覺回歸測試（Puppeteer 截圖 + 人工 review）再 merge |

### 降級設計

若 Phase 2 CSS Variables 重構遭遇 CSP 或渲染問題，系統可退回 Phase 1 成果（JavaScript 常數層），已消除的硬編碼重複定義仍保留收益，不需完整回滾。

---

## Reality Test

> 本節為 heavy evaluation 必填章節，以觸發案例與假設驗證對提案前提進行實證檢核。

### 觸發案例驗證（W2-007.2）

| 驗證項目 | 假設 | 實際狀況 | 結論 |
|---------|------|---------|------|
| 測試硬編碼色值是否造成語意斷裂 | 是 | W2-007.2 測試用 `rgb(233, 30, 99)` 驗色，與 fixture `#e91e63` 為等值但形式不同，語意斷裂確認 | 假設成立，問題真實存在 |
| Extension 是否缺乏設計系統 | 是 | 掃描確認 89+ 硬編碼色值、CSS Variables 數量 0 | 假設成立，現況數據支持提案 |
| APP 設計規格可直接移植色值 | 是 | UIColors（18 個色彩 token）、UISpacing（7 個間距 token）已明確定義值，單位轉換規則（dp→px）簡單 | 假設成立，移植可行性確認 |

### 關鍵假設清單

| 假設 | 風險等級 | 驗證方式 |
|------|---------|---------|
| Chrome Extension popup/overview 是固定尺寸，不需 ScreenUtil 響應式 | 低 | 現有 popup/overview 實作確認為固定寬度 |
| Phase 1 常數化不影響現有功能行為 | 低 | 純替換常數引用，E2E 測試可驗證無行為回歸 |
| CSS Variables 在 Chrome Extension MV3 context 中可正常運作 | 中 | Phase 2 開始前需要 POC 驗證 CSP 相容性 |

---

## 多視角審查

> 本節為 heavy evaluation 必填章節，從多個角色視角審查提案的可行性與邊界。

### 開發者視角

**收益**：消除 89+ 硬編碼色值的重複維護負擔；新增狀態色彩只需改常數層，不需全局搜尋替換。

**顧慮**：Phase 2 CSS Variables 重構改動範圍廣（10+ 檔案），視覺回歸風險需配合測試控制。

**結論**：分三階段實施（Phase 1 純常數化、Phase 2 CSS 重構、Phase 3 完整 Design System），每階段風險可控。

### 測試維護者視角

**收益**：測試引用語意化常數（`COLORS.primary`）取代硬編碼色值（`'#2196F3'`），色值變更時測試不需修改。

**顧慮**：E2E 視覺測試需要更新截圖基線（Phase 2 色系替換後視覺確實改變）。

**結論**：Phase 1 完成後更新 E2E 基線截圖，Phase 2 後同步再更新，基線更新成本一次性且可預期。

### 產品跨平台一致性視角

**收益**：Extension 與 APP 共用相同色彩語意（三色系統藍/綠/橘），使用者在兩個平台的視覺體驗一致。

**顧慮**：APP 後續若改設計系統，Extension 端需人工同步更新，無自動化機制。

**結論**：短期人工同步成本可接受；長期可考慮將 design-system/ 抽為獨立 npm 套件（PROP-008 範圍外）。

### 架構設計視角

**收益**：`src/core/design-system/` 作為單一設計真相來源（Single Source of Truth），符合 DRY 原則。

**顧慮**：若 design-system/ 模組被多個 entry point 引用，build 時需確認 esbuild 正確 bundle 不重複打包。

**結論**：Phase 1 實施時配合 build 驗證，確認 esbuild bundle 行為正確後再推進 Phase 2。

---

## 機會成本

> 本節為 heavy evaluation 必填章節，分析採用本提案相對於替代行動的機會成本。

### 採用本提案的機會成本

| 機會成本維度 | 說明 |
|------------|------|
| 工程成本（Phase 1） | 預估 1 個 Wave（建立 colors.js / spacing.js + 合併重複常數），等同於延後一個 Wave 的其他功能開發 |
| 工程成本（Phase 2） | CSS Variables 重構影響 10+ 檔案，需配合視覺回歸測試，預估 1-2 個 Wave |
| 維護成本 | design-system/ 需與 APP UIColors 版本保持同步，新增 APP 色彩 token 時 Extension 端需人工對齊 |
| 學習成本 | 開發者需熟悉語意化色彩命名（action/confirm/caution）取代直覺色彩選擇 |

### 不採用的機會成本

| 不採用後果 | 說明 |
|----------|------|
| 技術債累積加速 | 89+ 硬編碼色值隨功能增加只增不減，每次新增狀態需全局搜尋色值，維護成本線性增長 |
| 跨平台視覺分歧 | Extension 紫色梯度（#667eea）與 APP 藍色系（#2196F3）持續分歧，產品一致性降低 |
| 測試語意斷裂持續 | 色值以 hex/rgb 多種形式散落測試，語意斷裂引發誤判的機率隨測試規模增長 |

### 決策評估結論

Phase 1 工程投入（1 個 Wave）相對於長期維護收益（消除硬編碼重複、建立設計系統基礎）具備正向 ROI。Phase 2/3 的後續延伸視 Phase 1 實際成效與 v0.18.x 進度決定，不預先過度承諾。

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-04-08 | 初始建立（僅配色系統） |
| 2.0 | 2026-04-08 | 升級為完整 UI Design System，納入 APP 專案設計規格作為基準 |
| 2.1 | 2026-04-08 | 記錄討論結果：6 狀態配色確認、品牌梯度換色、Badge 樣式、APP reference 撞色修復 |
| 3.0 | 2026-05-05 | 補 evaluation_level=heavy + 5 必填章節（替代方案 / 失敗防護 / Reality Test / 多視角審查 / 機會成本）；對應 0.18.0-W10-098.8 |
