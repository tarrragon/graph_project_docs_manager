---
id: SPEC-DESIGN-SYSTEM
title: "UI Design System 規格"
status: draft
source_proposal: null
created: "2026-07-01"
updated: "2026-07-09"
version: "1.2"
owner: ""
domain: ui
subdomain: design-system
related_usecases: []
related_specs: []
---

# UI Design System 規格

**版本**: 1.2
**建立日期**: 2026-07-01
**最後更新**: 2026-07-09
**APP 基準**: `lib/core/ui/ui_config.dart` + `flat_design_config.dart`

---

## 1. 概述

本規格定義 Book Overview App 的統一 UI Design System，所有色彩、間距、圓角、按鈕樣式、陰影等視覺規格皆集中管理，確保跨平台視覺一致性。

**核心原則**：

| # | 原則 | 說明 |
|---|------|------|
| 1 | 三色系統 | 藍色主調 90% / 綠色正向 5% / 橘色負面 5% |
| 2 | 語意化命名 | 命名反映使用意圖（action/confirm/caution），非視覺層級 |
| 3 | 平面化設計 | 使用陰影取代邊框，石碑刻痕風格 |
| 4 | 4px 網格 | 所有間距為 4 的倍數 |
| 5 | Single Source of Truth | 所有視覺值定義於 `lib/core/design_system/`，其他檔案引用 |

**實作檔案結構**（現行）：

```
lib/core/ui/
  ├── ui_config.dart           # UIColors / UISpacing / UIBorderRadius / UIFontSizes / UIShadows / UIComponentSizes
  └── flat_design_config.dart  # FlatDesignConfig（按鈕樣式）
```

**目標檔案結構**（W8-003 重構後）：

```
lib/core/design_system/
  ├── colors.dart              # 配色系統
  ├── spacing.dart             # 間距系統
  ├── border_radius.dart       # 圓角系統
  ├── typography.dart          # 字體系統
  ├── shadows.dart             # 陰影系統
  ├── component_sizes.dart     # 元件尺寸
  └── design_system.dart       # 統一匯出
```

---

## 2. 配色系統

### 2.1 藍色主色調（佔 UI 色彩 90%）

| Token | 色值 | Dart 對應 | 用途 |
|-------|------|----------|------|
| `primary` | `#2196F3` | `UIColors.primary` | 主要按鈕、連結、action 按鈕 |
| `primaryLightest` | `#E3F2FD` | `UIColors.primaryLightest` | 背景區塊 |
| `primaryLight` | `#BBDEFB` | `UIColors.primaryLight` | 次要區塊、neutral 按鈕背景 |
| `primaryMedium` | `#64B5F6` | `UIColors.primaryMedium` | 互動元素 |
| `primaryDark` | `#1976D2` | `UIColors.primaryDark` | 選中狀態 |
| `primaryDarkest` | `#0D47A1` | `UIColors.primaryDarkest` | 重點文字 |

### 2.2 正向色 -- 綠色（佔 5%）

| Token | 色值 | Dart 對應 | 用途 |
|-------|------|----------|------|
| `positive` | `#4CAF50` | `UIColors.positive` | 成功、確認、finished badge |
| `positiveLight` | `#C8E6C9` | `UIColors.positiveLight` | 正向背景 |
| `positiveDark` | `#388E3C` | `UIColors.positiveDark` | 正向強調 |

### 2.3 負面色 -- 橘色（佔 5%）

| Token | 色值 | Dart 對應 | 用途 |
|-------|------|----------|------|
| `negative` | `#FF9800` | `UIColors.negative` | 警告、錯誤、abandoned badge |
| `negativeLight` | `#FFE0B2` | `UIColors.negativeLight` | 負面背景 |
| `negativeDark` | `#F57C00` | `UIColors.negativeDark` | 負面強調 |

### 2.4 背景與表面色

| Token | 色值 | Dart 對應 | 用途 |
|-------|------|----------|------|
| `backgroundLight` | `#FAFAFA` | `UIColors.backgroundLight` | 頁面主背景 |
| `surfaceLight` | `#FFFFFF` | `UIColors.surfaceLight` | 卡片表面 |
| `onBackgroundLight` | `#212121` | `UIColors.onBackgroundLight` | 主文字色 |
| `onSurfaceLight` | `#424242` | `UIColors.onSurfaceLight` | 次要文字色 |
| `onSurfaceMuted` | `#757575` | `UIColors.onSurfaceMuted` | 輔助文字色 |
| `onPrimary` | `#FFFFFF` | `UIColors.onPrimary` | 主色上的文字 |

### 2.5 暗色主題

| Token | 色值 | Dart 對應 | 用途 |
|-------|------|----------|------|
| `backgroundDark` | `#0A0E13` | `UIColors.backgroundDark` | 深藍背景 |
| `surfaceDark` | `#1A1D23` | `UIColors.surfaceDark` | 深藍表面 |
| `onBackgroundDark` | `#E3F2FD` | `UIColors.onBackgroundDark` | 淺藍文字 |
| `onSurfaceDark` | `#BBDEFB` | `UIColors.onSurfaceDark` | 淺藍文字 |

### 2.6 禁止配色

- 紅色已移除，所有錯誤使用橘色表示
- 一個頁面避免超過三色
- 漸層已廢棄，一律使用扁平色

---

## 3. ReadingStatus 配色

### 3.1 配色對照表

Badge 樣式：不透明淺色底（bg）+ 深色字（fg），全 6 狀態達 WCAG AA 4.5:1。

| 狀態 | 中文標籤 | 文字色（fg） | 背景色（bg） | WCAG AA 對比度 |
|------|---------|------------|------------|---------------|
| unread | 未開始 | `#546E7A` | `#ECEFF1` | 4.68:1 |
| queued | 待讀 | `#0D47A1` | `#BBDEFB` | 6.15:1 |
| reading | 閱讀中 | `#0D47A1` | `#E3F2FD` | 7.56:1 |
| finished | 已完成 | `#1B5E20` | `#C8E6C9` | 5.85:1 |
| abandoned | 已放棄 | `#804000` | `#FFE0B2` | 6.25:1 |
| reference | 參考用 | `#311B92` | `#EDE7F6` | 10.20:1 |

> WCAG AA 最低要求：正文 4.5:1、大字 3:1。

---

## 4. 語意化按鈕系統

### 4.1 按鈕類型

| 類型 | 語意 | 背景色 | 文字色 | Dart 對應 | 使用場景 |
|------|------|--------|-------|----------|---------|
| **action** | 一般操作 | `primary` #2196F3 | 白色 | `FlatDesignConfig.actionButton` | 儲存、提交、執行 |
| **confirm** | 正向確認 | `positive` #4CAF50 | 白色 | `FlatDesignConfig.confirmButton` | 確認、完成、同意 |
| **caution** | 警告操作 | `negative` #FF9800 | 白色 | `FlatDesignConfig.cautionButton` | 刪除、移除、警告 |
| **neutral** | 中性資訊 | `primaryLight` #BBDEFB | `primaryDark` #1976D2 | `FlatDesignConfig.neutralButton` | 取消、關閉、返回 |
| **ghost** | 輔助低調 | 透明 | `primary` #2196F3 | `FlatDesignConfig.ghostButton` | 輔助連結 |

### 4.2 按鈕尺寸

| 尺寸 | 高度 | Dart 對應 |
|------|------|----------|
| small | 36px | `UIComponentSizes.buttonSmall` |
| medium（預設） | 48px | `UIComponentSizes.buttonMedium` |
| large | 56px | `UIComponentSizes.buttonLarge` |

### 4.3 按鈕視覺效果

- 預設狀態：石碑凸起效果（`UIShadows.raised`）
- 按下狀態：石碑按壓效果（`UIShadows.pressed`）

---

## 5. 間距系統（基於 4px 網格）

| Token | 值 | Dart 對應 | 用途 |
|-------|-----|----------|------|
| `xxs` | 2px | `UISpacing.xxs` | 最小間距 |
| `xs` | 4px | `UISpacing.xs` | 緊湊元素、badge padding |
| `sm` | 8px | `UISpacing.sm` | 按鈕 padding、元素間距 |
| `md` | 16px | `UISpacing.md` | 標準內容間距、卡片 padding |
| `lg` | 24px | `UISpacing.lg` | 區塊間距 |
| `xl` | 32px | `UISpacing.xl` | 大區塊間距 |
| `xxl` | 48px | `UISpacing.xxl` | 頁面級間距 |
| `xxxl` | 64px | `UISpacing.xxxl` | 最大間距 |

---

## 6. 圓角系統

| Token | 值 | Dart 對應 | 用途 |
|-------|-----|----------|------|
| `xs` | 4px | `UIBorderRadius.xs` | tag chip、badge |
| `sm` | 8px | `UIBorderRadius.sm` | 按鈕、輸入框 |
| `md` | 12px | `UIBorderRadius.md` | 卡片 |
| `lg` | 16px | `UIBorderRadius.lg` | 對話框 |
| `xl` | 20px | `UIBorderRadius.xl` | 特大圓角 |
| `circular` | 999px | `UIBorderRadius.circular` | 圓形 |

---

## 7. 字體系統

### 7.1 字體大小

| Token | 值 | Dart 對應 | 用途 |
|-------|-----|----------|------|
| `headline1` | 32px | `UIFontSizes.headline1` | 主標題 |
| `headline2` | 28px | `UIFontSizes.headline2` | 次標題 |
| `headline3` | 24px | `UIFontSizes.headline3` | 小標題 |
| `headline4` | 20px | `UIFontSizes.headline4` | 段落標題 |
| `titleLarge` | 20px | `UIFontSizes.titleLarge` | 大標題 |
| `titleMedium` | 18px | `UIFontSizes.titleMedium` | 中標題 |
| `titleSmall` | 16px | `UIFontSizes.titleSmall` | 小標題 |
| `bodyLarge` | 16px | `UIFontSizes.bodyLarge` | 大內文 |
| `bodyMedium` | 14px | `UIFontSizes.bodyMedium` | 標準內文 |
| `bodySmall` | 12px | `UIFontSizes.bodySmall` | 小內文 |
| `button` | 14px | `UIFontSizes.button` | 按鈕文字 |
| `caption` | 12px | `UIFontSizes.caption` | 說明文字 |
| `overline` | 10px | `UIFontSizes.overline` | 上標文字 |

### 7.2 字體與字重

| Token | 值 | Dart 對應 |
|-------|-----|----------|
| `fontFamily` | `'PingFang SC', 'Microsoft YaHei', sans-serif` | `UITypography.primaryFontFamily` |
| `light` | 300 | `UITypography.light` |
| `regular` | 400 | `UITypography.regular` |
| `medium` | 500 | `UITypography.medium` |
| `semiBold` | 600 | `UITypography.semiBold` |
| `bold` | 700 | `UITypography.bold` |

### 7.3 行高

| Token | 值 | Dart 對應 |
|-------|-----|----------|
| `tight` | 1.2 | `UITypography.lineHeightTight` |
| `normal` | 1.4 | `UITypography.lineHeightNormal` |
| `relaxed` | 1.6 | `UITypography.lineHeightRelaxed` |

---

## 8. 陰影系統（石碑刻痕風格）

### 8.1 基礎陰影

| Token | box-shadow | Dart 對應 | 用途 |
|-------|-----------|----------|------|
| `card` | `0 2px 8px rgba(33,150,243,0.08)` | `UIShadows.card` | 卡片 |
| `button` | `0 2px 6px rgba(33,150,243,0.12)` | `UIShadows.button` | 按鈕 |
| `floating` | `0 4px 12px rgba(33,150,243,0.16)` | `UIShadows.floating` | 浮動選單 |
| `dialog` | `0 8px 16px rgba(33,150,243,0.16)` | `UIShadows.dialog` | 對話框 |

### 8.2 分割陰影（取代分隔線）

| Token | box-shadow | Dart 對應 | 用途 |
|-------|-----------|----------|------|
| `dividerSubtle` | `0 1px 2px rgba(33,150,243,0.06)` | `UIShadows.dividerSubtle` | 細分隔 |
| `dividerNormal` | `0 2px 4px rgba(33,150,243,0.10)` | `UIShadows.dividerNormal` | 標準分隔 |
| `dividerStrong` | `0 3px 6px rgba(33,150,243,0.14)` | `UIShadows.dividerStrong` | 粗分隔 |

### 8.3 石碑刻痕效果

| Token | 效果 | Dart 對應 | 用途 |
|-------|------|----------|------|
| `raised` | 凸起（淺陰影向下） | `UIShadows.raised` | 預設狀態、卡片 |
| `inset` | 凹陷（陰影向上） | `UIShadows.inset` | 選中狀態、按下狀態 |
| `engraved` | 刻痕（上方高光 + 下方陰影） | `UIShadows.engraved` | 區塊分隔 |
| `pressed` | 按壓（緊貼陰影） | `UIShadows.pressed` | 按鈕按下瞬間 |

---

## 9. 元件尺寸

| 元件 | Small | Medium | Large |
|------|-------|--------|-------|
| 按鈕高度 | 36px (`buttonSmall`) | 48px (`buttonMedium`) | 56px (`buttonLarge`) |
| 輸入框高度 | - | 48px (`inputField`) | 56px (`inputFieldLarge`) |
| 圖示 | 16px (`iconSmall`) | 24px (`iconMedium`) | 32px (`iconLarge`) |
| 載入指示器 | 16px (`loadingIndicatorSmall`) | 24px (`loadingIndicatorMedium`) | 32px (`loadingIndicatorLarge`) |

補充尺寸：

| Token | 值 | Dart 對應 | 用途 |
|-------|-----|----------|------|
| `iconXSmall` | 14px | `UIComponentSizes.iconXSmall` | 小型 UI 元素 |
| `icon20` | 20px | `UIComponentSizes.icon20` | 標題區域圖示 |
| `fab` | 56px | `UIComponentSizes.fab` | 浮動按鈕 |
| `fabSmall` | 40px | `UIComponentSizes.fabSmall` | 小型浮動按鈕 |

---

## 10. 常數配置策略

Design token 的程式碼配置位置依**消費者數量**決定：

| 消費者範圍 | 配置位置 | 範例 |
|-----------|---------|------|
| 僅 1 個 domain 使用 | `domains/{domain}/constants/` | `TagNames`（僅 library domain） |
| 跨 2+ domain 或跨層使用 | `core/design_system/` | 色值、間距、圓角、陰影 |

**強制規則**：

- 所有 design token（色值、間距、圓角、陰影、字體）必須集中於 `core/design_system/` 目錄
- 禁止 design token 散落在各 feature 目錄
- 禁止跨層 import domain 常數（如 infrastructure 層 import domains/ 的常數）

**判斷決策表**：

| 問題 | 是 | 否 |
|------|-----|-----|
| 此常數是否為視覺 token（色值/間距/圓角/陰影/字體）？ | 放 `core/design_system/` | 繼續下題 |
| 此常數是否被 2+ domain 使用？ | 放 `core/` 對應子目錄 | 放所屬 `domain/constants/` |

---

## 11. 跨語言目錄結構對照

| 技術棧 | 集中目錄 | token 檔案形式 |
|--------|---------|---------------|
| Flutter/Dart | `lib/core/design_system/` | `.dart` class（`static const`） |
| JS/TS（vanilla） | `src/core/design_system/` | `.ts` / `.js` export const |
| React | `src/theme/` | theme object / CSS-in-JS |
| Vue | `src/styles/tokens/` | CSS custom properties / composable |
| Chrome Extension | `src/core/design_system/` | `.js` export + CSS Variables |

---

## 12. 跨平台對齊

| Token 類別 | 共用/獨有 | 說明 |
|-----------|----------|------|
| 配色系統（2.1-2.4） | 共用 | 與 v1 Chrome Extension 完全一致 |
| 間距系統（xxs-xxl） | 共用 | 與 v1 Chrome Extension 一致 |
| 圓角系統（xs-xl） | 共用 | 與 v1 Chrome Extension 一致 |
| ReadingStatus 配色 | 共用 | 與 v1 Chrome Extension 一致（WCAG AA） |
| 按鈕語意系統 | 共用 | 五種按鈕類型與 v1 一致 |
| 陰影系統 | 共用 | 石碑刻痕效果與 v1 一致 |
| 字體系統 | 獨有差異 | APP 使用 `rsp` 響應式單位，Extension 使用固定 px |
| 元件尺寸 | 獨有差異 | APP 有響應式三版型適配，Extension 為固定尺寸 |
| xxxl 間距（64px） | APP 獨有 | v1 不含此 token |

---

## 13. 驗收標準

- [ ] design token 集中目錄存在且匯出完整 token
- [ ] 所有色值與 `ui_config.dart` UIColors 一致
- [ ] 現有硬編碼值替換為 token 引用
- [ ] ReadingStatus badge 使用本 spec 定義的 6 狀態配色
- [ ] 5 種語意化按鈕 widget 可用
- [ ] 測試中的色彩驗證引用 design-system 常數，非硬編碼值

---

## 14. 元件庫

本章定義 Book Overview App 的統一元件庫規範，將原則 3「以陰影取代邊框」從 token 層延伸至元件層。所有 `lib/presentation/` UI 不得直接建構原生 Material 元件，須改用本章定義的封裝元件；豁免場景見 14.5。本章同時作為 style-guardian 偵測規則的權威來源。

> 來源：PROP-016 元件庫統一化（confirmed）。本章為 spec 增補，不變更既有 1-13 章 token 值與視覺風格；實作遷移屬後續票。

### 14.1 元件清單

元件庫共 8 元件（既有 7 + 新增 AppDivider），皆為 StatelessWidget、採 Factory 模式、經 `components.dart` barrel 匯出。

| 元件 | 職責 | Factory 變體 | 狀態 |
|------|------|-------------|------|
| AppButton | 語意化按鈕 | .action / .confirm / .caution / .neutral / .ghost / .icon | 既有 |
| AppCard | 卡片容器（陰影定界） | .raised / .inset / .engraved / .interactive | 既有 |
| AppDialog | 對話框（收斂 showDialog 入口） | .confirm / .alert / .form / .custom / .loading | 既有 |
| AppBadge | 狀態標籤 | .success / .warning / .info / .muted | 既有 |
| AppTextField | 文字輸入（內建 inset 陰影） | .text / .email / .password / .search / .multiline / .number | 既有 |
| AppChip / 徽章家族 | 狀態標示 | 依語意收斂至 AppBadge | 既有 |
| AppIconButton 替代 | 圖示操作 | 見 14.5，豁免直用原生 IconButton | 既有（豁免） |
| AppDivider | 分隔（以陰影實作刻痕） | .subtle / .normal / .strong | 新增（14.2） |

### 14.2 AppDivider 規範

#### 設計依據

§8.2 已定義分割陰影 token（`UIShadows.dividerSubtle/Normal/Strong`），但 presentation 現有 7 處直用原生 `Divider`（實作為實線邊框，與石碑刻痕風格衝突）。AppDivider 將「分隔語意」封裝為以陰影實作的元件，杜絕原生 Material Divider。

#### 元件 API

| 項目 | 規範 |
|------|------|
| 類別名 | AppDivider（StatelessWidget，Factory 模式，與既有 7 元件一致） |
| barrel export | `components.dart` 新增 `export 'app_divider.dart';`（依字母序置於 `app_dialog.dart` 後） |
| 變體枚舉 | `enum AppDividerVariant { subtle, normal, strong }`（對映三 token） |
| 方向枚舉 | `enum AppDividerAxis { horizontal, vertical }`（表格隔線需垂直分隔） |

#### Factory 變體對照

| Factory | 對映 token | 用途 | 對應原生 |
|---------|-----------|------|---------|
| AppDivider.subtle() | UIShadows.dividerSubtle | 列表項間細分隔、密集內容 | Divider(height:x, thickness:0.5) |
| AppDivider.normal() | UIShadows.dividerNormal | 標準區塊分隔（預設） | Divider() |
| AppDivider.strong() | UIShadows.dividerStrong | 主要區段界線、標題下方 | Divider(thickness:2) |

#### 實作約束（供後續遷移票）

- 分隔線本體為薄 Container（height: 1.h 水平 / width: 1.w 垂直），decoration: BoxDecoration(boxShadow: 對映 token)，不使用 border/實線。
- 響應式：厚度與間距用 rsp（.h/.w/.r），遵循 §12 APP 端約束。
- 縮排參數 indent / endIndent（可選，double?，預設 0），對齊 Material Divider API 以降低遷移摩擦。
- 表格隔線場景（垂直分隔儲存格）用 AppDivider.subtle(axis: vertical)。
- 顏色 token 已存在（UIColors.dividerSubtle/Normal/Strong），禁止新增 token。
- 遷移防護：先在單一頁面（建議 `lib/presentation/library/widgets/loan_info_card.dart`，僅 1 處 `const Divider`，為 7 處中最單純案例）試點目視比對後，再全面遷移 7 處。試點頁選定須經 `grep -rn "Divider" lib/presentation` 實證含 Divider，禁止未驗證即指定（IMP-APP-002）。

### 14.3 原生元件禁用對照表

「禁用」指 `lib/presentation/` 不得直接建構；豁免場景見 14.5。本表為 style-guardian 偵測規則的權威來源。

| 原生元件 | 禁用 | 目標元件 | 遷移對映 | 存量 |
|---------|------|---------|---------|------|
| TextButton | 是 | AppButton | → .action / .neutral（取消類）/ .ghost（純文字連結） | 15 |
| ElevatedButton | 是 | AppButton | → .action（主操作）/ .confirm（正向） | 3 |
| Card | 是 | AppCard | → .raised / .inset / .engraved / .interactive | 11 |
| AlertDialog | 是 | AppDialog | → AppDialog.confirm / .alert | 9 |
| showDialog(...) | 是（入口收斂） | AppDialog.* | → confirm/alert/form/custom/loading（皆內部呼叫 showDialog） | 14 |
| Divider | 是 | AppDivider | → .subtle / .normal / .strong（見 14.2） | 7 |
| Chip / ChoiceChip | 是 | AppBadge / 個案 | 純狀態標示 → AppBadge.*；可移除互動則收斂 | 8+2 |
| FilterChip | 否（個案判讀） | 保留 or 未來 AppFilterChip | 互動型過濾器，本版豁免直用 + 列白名單 | 4 |
| Border.all | 條件式（見 14.4） | AppCard/AppTextField/AppDivider/豁免 | 依語意分類 | 43 |
| IconButton | 否（豁免直用） | 保留直用 + token 約束 | 見 14.5 評估結論 | 26 |
| BorderSide | 隨 Border.all 連動 | 同 Border.all 分類 | 多為 Border.all 內部參數，隨父分類處理 | 8 |

#### showDialog 入口對映細則（14 處）

| 原始用法 | AppDialog 對映 |
|---------|---------------|
| showDialog + 確認/取消雙鈕 | AppDialog.confirm（含 isDangerous 供刪除類） |
| showDialog + 單一提示鈕 | AppDialog.alert（含 isWarning） |
| showDialog + 表單輸入 | AppDialog.form&lt;T&gt; |
| showDialog + 完全自訂內容 | AppDialog.custom&lt;T&gt;（barrierDismissible 可控） |
| showDialog + 進度顯示 | AppDialog.loading |

> 偵測規則注意：Card / ElevatedButton / Chip 三者 naive grep 會嚴重高估。style-guardian 須用 word-boundary（`\bCard\(`）+ 排除 `ThemeData` 後綴 + 排除 `_build*` 方法定義行，否則自製元件（`*Card`）、theme 設定類（`*ThemeData`）、helper 方法（`_build*Chip`）會誤計。

### 14.4 Border.all 分類框架

43 處 Border.all 依語意分 5 類，遷移票須逐一機械判定並記錄歸類。

#### 決策樹

```
Border.all 實例
├─ 父容器同時有 borderRadius + 純色 bg(surfaceLight)？ 且無 isSelected 條件 → 【A 卡片邊框】→ AppCard.raised/engraved（陰影取代邊框）
├─ border color 依 isSelected/isEnabled 三元切換？ → 【B 選中狀態框】→ AppCard.interactive（陰影凹凸表達選中）或 FilterChip（互動型）
├─ 父容器 bg 為語意淺色(positiveLight/negativeLight/primaryLightest) + 同語意 border？ → 【C 語意提示框】→ AppCard 語意變體 或 保留（見豁免）
├─ 包裹輸入/日期選擇元件？ → 【D 輸入框邊框】→ AppTextField（內建 inset 陰影）
└─ 以上皆非（theme helper / 第三方包裹 / 特殊視覺） → 【E 豁免】→ 記錄理由，列 hook 白名單
```

#### 五類收斂目標與實測分布

| 類別 | 判準 | 收斂目標 | 預估佔比 |
|------|------|---------|---------|
| A 卡片邊框 | 純色 bg + borderRadius + dividerNormal 邊框，無狀態切換 | AppCard.raised（去邊框，陰影定界） | 高(~15) |
| B 選中狀態框 | 邊框色 isSelected ? primary : dividerNormal | AppCard.interactive；互動過濾器 → FilterChip | 中(~10) |
| C 語意提示框 | 語意淺色 bg + 同語意色邊框(success/error/riskColor) | AppCard + 語意 boxShadow(UIShadows.positive/negative) | 中(~10) |
| D 輸入框邊框 | 包裹日期/文字輸入 | AppTextField（內建 inset） | 低(~4) |
| E 豁免 | theme helper／視覺無法以陰影表達 | 保留 + 白名單 | 低(~4) |

> 佔比為設計性預估，遷移票須逐一實測歸類並記錄於 ticket。BorderSide 8 處多為 Border.all/Border 內部參數，隨父實例同類處理。

#### 收斂原則

- A/C 類（純邊框/語意框）：石碑風格「以陰影取代邊框」是 §1 核心原則 3，為主要收斂對象，收斂後移除 `border:` 改用對應 boxShadow。
- B 類（選中框）：選中狀態用 AppCard.interactive 的 inset/raised 陰影切換表達；純過濾互動者用 Chip 家族。
- E 類：必須逐處寫豁免理由（路徑 + 為何無法收斂），供 hook 白名單引用。豁免非預設，需實證。

### 14.5 豁免清單

#### IconButton 評估結論：豁免直用 + token 約束 + 列 hook 白名單

不新增 AppIconButton 包裝。評估依據：

| 面向 | 觀察 | 判斷 |
|------|------|------|
| 樣式自由度 | IconButton 透明無填色、無陰影，26 處外觀本已一致 | 包裝的「樣式統一」收益趨近零 |
| Material 內建行為依賴 | 大量使用 tooltip、iconSize、padding: EdgeInsets.zero、constraints | 包裝須重實作 48px tap target、tooltip、InkResponse，成本高易退化 |
| 既有替代 | AppButton.icon 存在但 tooltip 僅映 semanticLabel、不支援 iconSize/padding 細調 | 無法覆蓋 26 處需求，強推造成功能回退 |
| 風險 | 提案風險表已列「IconButton 包裝收益不明 → 過度設計」 | 包裝屬過度設計 |

IconButton 豁免的配套約束（避免豁免變成無防線）：

| 約束 | 規範 |
|------|------|
| icon 顏色 | 必須用 UIColors.*，禁硬編碼色值 |
| icon 尺寸 | 必須用 UIComponentSizes.*（iconSmall/Medium/Large/icon20/iconXSmall），禁裸數字 |
| tooltip | 具操作語意的 IconButton 必須提供 tooltip（無障礙） |

#### 豁免三條件（AND，全滿足才可豁免）

1. 場景屬結構性無法收斂：第三方套件內部元件、測試檔斷言、或視覺語意無對應元件庫元件。
2. 記錄理由：每筆豁免須寫「路徑 + 具體理由」，禁「暫時豁免」「之後處理」等無 trigger 表述（decision-trigger-binding 規則）。
3. 列入 hook 白名單：豁免項登記於 style-guardian 白名單（路徑 + 理由），使工具與文件一致。

#### 預設豁免類別

| 豁免類別 | 範例 | 理由 |
|---------|------|------|
| 第三方套件內部 | package 內部建構的原生元件 | 非本專案可控 |
| 測試檔 | test/** 的 find.byType(TextButton) 等 | 測試斷言需引用原生型別（CLAUDE.md 7.5 已規範遷移為 AppButton 斷言，mock/第三方測試除外） |
| IconButton | 26 處直用 | 樣式統一收益低、無障礙依賴高（本節評估結論） |
| FilterChip | 4 處互動過濾器 | 互動型，本版無對應元件庫元件，個案判讀（未來可建 AppFilterChip） |
| Border.all E 類 | theme.dart helper、匯入預覽特殊框 | 視覺語意無法以陰影表達或屬 theme 設定層 |

#### 豁免治理

- 豁免非預設狀態：預設一律收斂，豁免需實證。
- hook 分階段：style-guardian 先以 WARNING 模式上線一個版本觀察誤報率，白名單隨誤報回報增補，誤報率達標後再升 deny。
- 豁免清單審查：每版本發布前檢視豁免清單，評估是否有已可收斂項（避免豁免永久化）。

### 14.6 跨平台元件對照表

> contract-version: v1

延續 §12 token 對齊模式擴展到元件層。本表是 APP（Flutter）↔ v1（Chrome Extension）的元件命名契約，供 v1 端 PROP-013 依此實作。APP 端為契約權威。僅命名契約，不跨 repo 改碼。

#### 元件命名契約總表

| 元件語意 | APP 元件.變體 | v1 工廠.variant | 共用 token | v1 現況 |
|---------|--------------|----------------|-----------|---------|
| 按鈕 | AppButton.action | createButton({variant:'primary'}) | 語意按鈕系統(§4) | 已有 createButton |
| 按鈕 | AppButton.confirm | createButton({variant:'confirm'}) | positive | v1 待補 confirm |
| 按鈕 | AppButton.caution | createButton({variant:'danger'}) | negative | 已有 danger |
| 按鈕 | AppButton.neutral | createButton({variant:'secondary'}) | primaryLight | 已有 secondary |
| 按鈕 | AppButton.ghost | createButton({variant:'ghost'}) | transparent | v1 待補 |
| 卡片 | AppCard.raised | createCard({variant:'raised'}) | UIShadows.raised | v1 待建 |
| 卡片 | AppCard.inset | createCard({variant:'inset'}) | UIShadows.inset | v1 待建 |
| 卡片 | AppCard.engraved | createCard({variant:'engraved'}) | UIShadows.engraved | v1 待建 |
| 對話框 | AppDialog.confirm | createDialog({variant:'confirm'}) | UIShadows.dialog | v1 待建 |
| 對話框 | AppDialog.alert | createDialog({variant:'alert'}) | UIShadows.dialog | v1 待建 |
| 標籤 | AppBadge.success | createBadge({variant:'success'}) | positiveLight/Dark | v1 待建 |
| 標籤 | AppBadge.warning | createBadge({variant:'warning'}) | negativeLight/Dark | v1 待建 |
| 標籤 | AppBadge.info | createBadge({variant:'info'}) | primaryLight/Dark | v1 待建 |
| 標籤 | AppBadge.muted | createBadge({variant:'muted'}) | surfaceDark/onSurfaceMuted | v1 待建 |
| 分隔 | AppDivider.subtle | createDivider({variant:'subtle'}) | dividerSubtle | v1 待建 |
| 分隔 | AppDivider.normal | createDivider({variant:'normal'}) | dividerNormal | v1 待建 |
| 分隔 | AppDivider.strong | createDivider({variant:'strong'}) | dividerStrong | v1 待建 |
| 輸入框 | AppTextField.text/email/password/search/multiline/number | createInput({type:'text'/'email'/...}) | inset | v1 待建 |

#### 命名契約規則

| 規則 | 內容 |
|------|------|
| 語意名對齊 | 變體語意名雙端一致（confirm/caution≈danger/neutral≈secondary）。v1 既有 primary/secondary/danger 保留為別名，新增契約以語意名為準 |
| variant 映射 | APP factory 方法名 = v1 factory 的 variant 參數值 |
| size 對齊 | 雙端共用 small/medium/large（對映 §9 元件尺寸） |
| token 引用 | 雙端引用同名 token（§2-8），不各自定義 |
| 差異標記 | (1) 單位差異：APP 用 rsp 響應式、v1 用固定 px（§12 既有差異，屬實作層非契約層）；(2) **色值平台校準層**：primary 系 APP `#2196F3` / v1 `#1A56DB`（v1 為 WCAG AA 校色，0.19.1-W3-001），雙端各自維持不歸一——同名 token 值刻意不同屬「平台校準」非漂移，全量對照與分類（shared/calibrated/platformOnly）以 v1 repo `src/core/design-system/token-manifest.json` 為機器可讀權威（PROP-018/PROP-014 方案 D） |
| 版本標記 | 本章標 contract-version: v1；章節變更視為契約變更，須同步通知 v1（交接票 1.5.0-W5-025 已標依賴） |

#### 預設文案 l10n key 契約

元件庫元件的「強語意預設文案」（見 14.8 第二層）必須引用下表 l10n key，不得各自定義字面。本表屬 14.6 命名契約的一部分（contract-version: v1），雙端（APP ARB / v1 messages）以同名 key 對齊，防止預設文案漂移。

| l10n key | 用途 | 使用元件 | APP ARB 現況 |
|----------|------|---------|-------------|
| confirm | 確認鈕預設文字 | AppDialog.confirm | 已有 |
| cancel | 取消鈕預設文字 | AppDialog.confirm / .form | 已有 |
| loading | 載入提示預設文字 | AppDialog.loading（現為 nullable 無預設，若未來加預設須用此 key） | 已有 |
| search | 搜尋輸入 hint | AppHeader.withSearch / AppTextField.search | 已有（待遷移引用） |
| enterEmail | Email 輸入 hint | AppTextField.email | 已有（待遷移引用） |
| enterPassword | 密碼輸入 hint | AppTextField.password | 已有（待遷移引用） |
| invalidEmailFormat | Email 格式驗證錯誤訊息 | AppTextField 內建 email validator | 已有（待遷移引用） |

> key 新增規則：元件庫新增強語意預設文案時，先確認 ARB 是否已有語意相同 key（優先重用），無則新增並同步登記本表。

### 14.7 元件狀態綁定與重繪邊界

本節定義元件庫元件的狀態接收標準形式與重繪邊界寫法，為「元件庫雙向約束」方法論 L2 判準（Flutter + Riverpod 3.0）的專案落地，與 CLAUDE.md §6.1（MVVM + Riverpod 3.0）一致。

#### 狀態接收標準形式：收值 + callback

| 規則 | 內容 |
|------|------|
| 元件收值 | 元件庫元件一律為 StatelessWidget，透過建構參數接收「已解析的值」（String / bool / enum / callback），不接收 Provider / Notifier / Stream 等 observable |
| 狀態變更走 callback | 使用者互動以 `onPressed` / `onChanged` / `onSearch` 等 callback 上拋，由呼叫端（頁面層）決定如何處理 |
| ViewModel 為狀態權威 | 狀態變更由頁面層 callback 轉交 ViewModel（`Notifier<T>`）處理；元件庫元件禁止 `ref.watch` / `ref.read`、禁止依賴 ConsumerWidget |
| 短暫 UI 狀態豁免 | 純視覺短暫狀態（按壓水波、輸入框 focus、密碼顯示切換）可由元件內部 `_XxxState` 私有 State 持有，不上拋 ViewModel |

**Why**：元件庫是跨頁面重用層，綁定特定 Provider 會使元件與單一功能耦合、無法重用且 Widget 測試需架 ProviderScope；收值 + callback 使元件可獨立測試、重繪範圍由呼叫端精準控制。

#### 重繪邊界標準寫法

呼叫端（頁面層）使用元件庫元件時，依下表五方案控制重繪邊界（來源：parsley-flutter-developer §2.1，ARCH-010 教訓）：

| 方案 | 適用場景 | 標準寫法 |
|------|---------|---------|
| `select` | 頁面只依賴 ViewModel 部分狀態 | `ref.watch(provider.select((s) => s.count))` |
| `const` Widget | 子樹不依賴變動資料 | `const AppDivider.normal()` |
| `ValueKey` | 列表中的 StatefulWidget 需跨 rebuild 保持 State | `key: ValueKey(item.id)` |
| StatefulWidget 本地狀態 | 狀態僅該 Widget 使用（展開/摺疊等） | 元件內私有 `_isExpanded` |
| 外部狀態管理 | 狀態跨 Widget / 跨頁面共享 | Riverpod `Notifier<T>`（ViewModel） |

選擇順序由簡至繁：先驗證框架內建機制（Key / const / 本地 State）是否足夠，不足才升級至 `select` 與外部狀態管理（ARCH-010 防護）。

#### 高頻場景效能檢核

長列表、搜尋即時過濾、掃描進度等高頻重繪場景，遷移或新頁面實作時逐項檢核：

- [ ] 列表項使用 `ValueKey(穩定 id)`，非 index key
- [ ] 列表項元件為 const 或以 `select` 縮小監聽範圍，單筆資料變更不觸發全列表 rebuild
- [ ] 不變子樹（圖示、分隔、固定文字）標 `const`
- [ ] 高頻更新狀態（進度百分比、輸入中文字）不放進整頁 state；以獨立 provider + `select` 或本地 State 隔離
- [ ] `ListView.builder` / `GridView.builder` 惰性建構，禁一次性 `children: [...]` 生成長列表

### 14.8 元件文字歸屬（i18n-first）

元件庫元件內的使用者可見文字依三層判準歸屬（「元件庫雙向約束」方法論 i18n-first 條款落地）：

#### 三層判準

| 層 | 判準 | 規則 | 範例 |
|----|------|------|------|
| 1 呼叫端文字 | 文字語意由使用場景決定 | 禁寫死於元件；由呼叫端以參數傳入，呼叫端走 ARB/l10n | AppButton child、AppBadge label、AppDialog title/message |
| 2 強語意預設文案 | 文字語意由元件自身決定，跨場景恆定 | 元件得引用 l10n key 作預設，參數可覆蓋；key 登記 14.6「預設文案 l10n key 契約」 | AppDialog confirm/cancel 鈕（`l10n.confirm` / `l10n.cancel`）、AppTextField hint 預設 |
| 3 非語意排版字元 | 對使用者無語意的排版符號 | 可內嵌字面 | 空字串 `''`、分隔符、省略號拼接 |

判準順序：先問「這段文字的語意由誰決定？」呼叫場景決定 → 第 1 層；元件自身決定 → 第 2 層；無語意 → 第 3 層。禁止以「只是預設值」為由把第 1 層文字寫死在元件內。

#### 既有元件字面寫死盤點（2026-07-09，lib/core/ui/components/ 實測）

| 元件 | 盤點結果 | 歸類 |
|------|---------|------|
| AppButton | 無寫死文字（child 由呼叫端傳入） | 合規 |
| AppCard | 無文字 | 合規 |
| AppBadge | 無寫死文字（label 必填由呼叫端傳入） | 合規 |
| AppDialog | confirm/cancel 預設鈕已用 `l10n.confirm` / `l10n.cancel`；loading message nullable 無預設 | 合規（第二層標準範例） |
| AppDivider | 無文字 | 合規 |
| AppPageScaffold | `title ?? ''`（app_page_scaffold.dart:208） | 豁免（第三層，空字串非語意） |
| AppHeader | `searchHint ?? '搜尋...'`（app_header.dart:130） | 待遷移 → `l10n.search` |
| AppTextField | `'請輸入電子郵件'`（:174）、`'請輸入密碼'`（:206）、`'搜尋...'`（:237）、`'請輸入有效的電子郵件格式'`（:344，email validator） | 待遷移 → `l10n.enterEmail` / `l10n.enterPassword` / `l10n.search` / `l10n.invalidEmailFormat`（ARB key 皆既有） |

**遷移注意**：AppTextField factory 為 static 建構、無 BuildContext，預設文案解析須移入 `build()`（或改於 `_AppTextFieldState.build` 以 `AppLocalizations.of(context)` 解析 null 參數），不可在 factory 內取 l10n。遷移屬實作票範疇，非本 spec 變更。

---

## 15. 觸控目標規範

本章定義所有可互動元素的觸控目標底線，為新元件設計與既有元件審查的驗收依據。

### 15.1 強制規則

| 規則 | 要求 |
|------|------|
| 最小觸控目標 | 48x48dp（Material 標準）；視覺尺寸可小於 48dp，但可點擊區域（hit area）不得小於 48x48dp |
| 點擊區域涵蓋視覺行區域 | 可互動元素的點擊區域必須涵蓋其視覺行區域——使用者直覺可點範圍即實際可點範圍，不得僅圖示或局部子區域可點 |
| 展開/收合控制項整行可點 | 展開/收合類控制項（樹狀節點、可折疊清單、accordion）必須整行可點，不得僅限 trailing 箭頭圖示；箭頭圖示點擊行為維持不變 |

### 15.2 元素類型要求對照表

| 元素類型 | 最低要求 | 常見違規 |
|---------|---------|---------|
| 按鈕（AppButton 各變體） | 高度 >= 48dp（`buttonMedium` 起）；icon 變體 hit area >= 48x48dp | icon 按鈕以 `padding: EdgeInsets.zero` + `constraints` 壓縮至 < 48dp |
| 展開/收合控制項 | 整行（含名稱文字與圖示）皆可點，hit area 高度 >= 48dp | 僅 trailing 箭頭 IconButton 可點，名稱文字區域無回應 |
| 清單項（ListTile 類） | 整行可點，行高 >= 48dp | 僅行內某個子元件掛 GestureDetector |
| 核取/切換元件（Checkbox、Switch） | 元件加其標籤文字皆可點，合計 hit area >= 48x48dp | 僅 Checkbox 本體 40x40dp 可點，標籤文字不可點 |
| 獨立圖示（可點擊 Icon） | 以 IconButton 或 InkResponse 包裝，hit area >= 48x48dp | 裸 `GestureDetector` + `Icon`（視覺 24dp 即 hit area 24dp） |
| 文字連結 | 行高 >= 48dp 或垂直 padding 補足 hit area | 內嵌 TextSpan recognizer 無 padding，實際可點高度僅字高 |

### 15.3 驗收方式

- 新元件進入元件庫（第 14 章）前，須逐項對照 15.2 表確認無常見違規樣態
- 實機驗收：使用者直覺可點範圍（如整行）點擊須有回應；點擊區域擴大不得改變既有子元件（如箭頭圖示）的行為

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-07-01 | 初始版本（從 ui_design_specification.md 抽出 design token，格式對齊 v1 design-system-spec.md） |
| 1.1 | 2026-07-09 | 新增第 14 章「元件庫」（PROP-016 元件庫統一化）：元件清單、AppDivider 規範、原生元件禁用對照表、Border.all 分類框架、豁免清單、跨平台元件對照表（contract-version: v1） |
| 1.2 | 2026-07-09 | 增補 §14.7 元件狀態綁定與重繪邊界（收值+callback、五方案重繪表、高頻場景檢核）、§14.8 元件文字歸屬 i18n-first（三層判準 + 7 元件盤點）、§14.6 預設文案 l10n key 契約（0.38.0-W3-009） |
| 1.3 | 2026-07-13 | §14.6 差異標記補記色值平台校準層條目（primary APP `#2196F3` / v1 `#1A56DB`，WCAG AA 校色），並登記 token-manifest.json 為 token 值對照機器可讀權威（0.38.0-W10-001，PROP-018 工作項 3） |
| 1.4 | 2026-07-16 | 新增第 15 章「觸控目標規範」：最小 48x48dp、點擊區域涵蓋視覺行區域、展開/收合控制項整行可點、元素類型要求對照表（0.38.1-W1-095） |
