---
name: dart-style-guardian
description: "Dart／Flutter 專案樣式與文字的執法工具：掃出裸色碼、裸間距、裸字級、裸圓角與寫死文字，指出各自該改用哪個 token 或 i18n key，並以 PostEdit hook 擋下新增違規。觸發詞：裸值、硬編碼顏色、寫死文字、樣式違規、style guardian、token 沒用到、i18n 漏翻。Do NOT use for 建立 token 體系（用 foundation-design）或元件契約設計（用 component-contract-design）。"
metadata:
  version: 1.2.0
  category: ui-design
---

# Dart Style Guardian

掃出程式碼裡沒有走 design token 與 i18n 的地方，並指出每一處該改成什麼。

**產出是兩樣東西**：掃描器輸出的違規清單（檔案、行號、違規類別、建議改法、豁免計數），以及依該清單改完的程式碼。清單本身不是交付物——違規歸零或每一條剩餘違規都有豁免標記，才算做完。

**本 skill 只回答「不該怎麼做」。** 正面的「該怎麼做」分屬兩處：token 體系該有哪些階、怎麼命名，是 `foundation-design` 的 UI 維度；元件該有哪些契約欄位、容器怎麼承載排列，是 `component-contract-design`。被本 skill 擋下之後要查的是那兩處，不是本檔。元件層約束原則（禁自製元件、豁免三條件、白名單治理、WARNING 升阻擋判準）見 `.claude/methodologies/component-library-bidirectional-constraint-methodology.md`，本 skill 是它的「工具執法」層實作。

## 起手

**第一個動作是讀 `.claude/config/dart-style-guardian.json`**，確認本專案的 token 類別名（`tokens` 欄位）與 i18n 存取子形態（`i18n.accessor`）。不先讀它就掃，拿到的建議會是「改用專案 design system 的 color token」這種無法直接照做的描述性敘述。

校準檔缺席時**不要自己編一組類別名**——指名一套不存在的命名，讀者照做會寫出編譯不過的程式碼。缺席的正確處置見〈Project Calibration〉。

確認之後跑掃描：

```bash
uv run .claude/skills/dart-style-guardian/scripts/style_checker.py scan lib/
```

## 全程

| 步 | 做什麼 | 在哪 |
|----|--------|------|
| 起手 | 讀校準檔，確認 token 類別名與 i18n 存取子 | 本檔上一節、〈Project Calibration〉 |
| 1 | 跑掃描，取得違規清單 | 〈Detection Script Usage〉 |
| 2 | 逐條對照違規類別，查該類的正確寫法 | 下方〈五類約束〉表 |
| 3 | 改碼；改不動而確有正當理由者加豁免標記 | 〈Common Violations and Fixes〉、〈Project Calibration〉的 `exempt_markers` |
| 4 | 重掃確認歸零，並確認豁免計數與你標的數量相符 | 〈Detection Script Usage〉 |

## 五類約束與按需讀取

正文的五節給的是速查與判定；要改的東西落在邊界上、或要新增階與新寫法時，讀對應的完整規範。

| 約束類別 | 正文速查 | 完整規範 | 什麼時候要讀完整規範 |
|---------|---------|---------|-------------------|
| 顏色 | 〈Color System〉 | `references/color-system.md` | 要新增色階、或判不出某個顏色該歸 primary／positive／negative 哪一類 |
| 間距 | 〈Spacing System〉 | `references/spacing-system.md` | 需要的值不在 4dp 網格上，要判斷是該取近似值還是該加一階 |
| 字級 | 〈Typography System〉 | `references/typography-system.md` | 要加響應式字級、新字重，或處理跨形態的字級縮放 |
| 圓角 | 〈Border Radius System〉 | 無獨立 reference，正文即全部 | — |
| i18n | 〈Internationalization (i18n)〉 | `references/i18n-guidelines.md` | 寫使用者可見文字、ViewModel 要回傳訊息、或要判斷某段文字算不算使用者可見 |

## 與相鄰資產的交界

執行時不需要先讀本節。不確定某件事該由本 skill 還是別處處理時再查。

| 相鄰資產 | 它管什麼 | 交界落在哪 |
|---------|---------|-----------|
| `foundation-design` skill | 地基入口與路由；token 體系是它 UI 維度的產物 | 本 skill 消費 token 名並執法，不決定該有哪些 token。**掃不到東西時先查這裡**——token 層還沒建，本 skill 的掃描範圍就是空的 |
| `component-contract-design` skill | 元件契約欄位表、容器排列不變式 | 本 skill 抓裸值與原生元件直用，屬元件層；**組合層的重疊與截斷本 skill 掃不到**，那要靠該 skill 的判別問句 |
| `ux-design-evaluation` skill | 畫面級狀態、回饋的時間門檻與通知形式 | 本 skill 只看程式碼字面，不判斷回饋設計是否合理。「按鈕沒有 loading 態」不是本 skill 的違規類別 |
| `version-bootstrap` skill 地基波 | 編排 i18n → design-system → UX 審查 → 元件庫四塊的順序 | 本 skill 是四塊完成後的常態執法層。**四塊未完成時先不要接 hook**——見〈Project Calibration〉的 baseline 說明 |

## Core Principles

### Design Philosophy: Flat Design 2.0 + Monochrome System

| Principle | Description | Source |
|-----------|-------------|--------|
| Minimalism | Clean, uncluttered layouts | Flat Design |
| 2D Styling | Simple, flat shapes without 3D effects | Flat Design |
| Subtle Shadows | Shadows hint at interactivity (Flat 2.0) | Material Design |
| Monochrome | Primarily use different saturations of blue | Project Design Spec |
| Three-Color System | Blue (primary) + Green (positive) + Orange (negative) | Project Design Spec |

### Key Files

檔案位置因專案而異，故以角色描述而非路徑列出——寫死某專案的路徑，其他專案讀到的就是一份指向不存在檔案的清單。實際位置見 `.claude/config/dart-style-guardian.json` 的 `tokens` 欄位所指的類別，以及專案的 `l10n.yaml`。

| Role | 內容 |
|------|------|
| Design system tokens | 顏色、間距、字級、圓角的 SSOT；掃描器據此判定何謂「已使用 token」 |
| Theme | 組裝 tokens 為 ThemeData 的入口 |
| Localization 設定 | `l10n.yaml` 決定 ARB 位置與存取子形態 |
| UI 設計規格 | 設計稿與元件規範文件（如有） |

---

## Color System

### Primary Color (Blue, 90% usage)

| Hardcoded | UIColors | Purpose | Hex |
|-----------|----------|---------|-----|
| `Colors.blue` | `UIColors.primary` | Primary buttons | #2196F3 |
| `Color(0xFF2196F3)` | `UIColors.primary` | Primary buttons | #2196F3 |
| `Colors.blue[50]` | `UIColors.primaryLightest` | Background blocks | #E3F2FD |
| `Colors.blue[100]` | `UIColors.primaryLight` | Secondary blocks | #BBDEFB |
| `Colors.blue[300]` | `UIColors.primaryMedium` | Interactive elements | #64B5F6 |
| `Colors.blue[700]` | `UIColors.primaryDark` | Selected states | #1976D2 |
| `Colors.blue[900]` | `UIColors.primaryDarkest` | Emphasis text | #0D47A1 |

### Positive Color (Green, 5% usage)

| Hardcoded | UIColors | Purpose |
|-----------|----------|---------|
| `Colors.green` | `UIColors.positive` | Success, confirmation |
| `Colors.green[100]` | `UIColors.positiveLight` | Success backgrounds |
| `Colors.green[700]` | `UIColors.positiveDark` | Success emphasis |

### Negative Color (Orange, 5% usage)

| Hardcoded | UIColors | Purpose |
|-----------|----------|---------|
| `Colors.orange` | `UIColors.negative` | Warning, error |
| `Colors.amber` | `UIColors.negative` | Warning, caution |
| `Colors.red` | `UIColors.negative` | **Project does NOT use red** |

### Background Colors

| Hardcoded | UIColors | Purpose |
|-----------|----------|---------|
| `Colors.white` | `UIColors.surfaceLight` | Card backgrounds |
| `Colors.grey[50]` | `UIColors.backgroundLight` | Page backgrounds |
| `Colors.grey[600]` | `UIColors.onSurfaceMuted` | Muted text |

---

## Spacing System (4dp Grid)

### SizedBox Spacing

| Hardcoded | UISpacing | Responsive |
|-----------|-----------|------------|
| `SizedBox(height: 4)` | `SizedBox(height: UISpacing.xxs)` | `.h` suffix |
| `SizedBox(height: 8)` | `SizedBox(height: UISpacing.xs)` | `.h` suffix |
| `SizedBox(height: 12)` | `SizedBox(height: UISpacing.sm)` | `.h` suffix |
| `SizedBox(height: 16)` | `SizedBox(height: UISpacing.md)` | `.h` suffix |
| `SizedBox(height: 24)` | `SizedBox(height: UISpacing.lg)` | `.h` suffix |
| `SizedBox(height: 32)` | `SizedBox(height: UISpacing.xl)` | `.h` suffix |
| `SizedBox(width: 8)` | `SizedBox(width: UISpacing.xs)` | `.w` suffix |

### EdgeInsets Padding

| Hardcoded | UISpacing |
|-----------|-----------|
| `EdgeInsets.all(4)` | `EdgeInsets.all(UISpacing.xxs)` |
| `EdgeInsets.all(8)` | `EdgeInsets.all(UISpacing.xs)` |
| `EdgeInsets.all(16)` | `EdgeInsets.all(UISpacing.md)` |
| `EdgeInsets.symmetric(horizontal: 16)` | `EdgeInsets.symmetric(horizontal: UISpacing.md)` |
| `EdgeInsets.symmetric(vertical: 8)` | `EdgeInsets.symmetric(vertical: UISpacing.xs)` |

---

## Typography System

### Font Sizes

| Hardcoded | UIFontSizes | Purpose |
|-----------|-------------|---------|
| `fontSize: 10` | `UIFontSizes.overline` | Overline text |
| `fontSize: 12` | `UIFontSizes.bodySmall` | Small body text |
| `fontSize: 14` | `UIFontSizes.bodyMedium` | Standard body text |
| `fontSize: 16` | `UIFontSizes.bodyLarge` | Large body text |
| `fontSize: 18` | `UIFontSizes.titleMedium` | Medium titles |
| `fontSize: 20` | `UIFontSizes.titleLarge` | Large titles |
| `fontSize: 24` | `UIFontSizes.headline3` | Headlines |

### Responsive Font Sizes

Use `.rsp` suffix for responsive scaling:

```dart
// Correct
TextStyle(fontSize: UIFontSizes.bodyMedium)  // Already includes .rsp

// Incorrect
TextStyle(fontSize: 14)
TextStyle(fontSize: 14.sp)  // Manual scaling
```

---

## Border Radius System

| Hardcoded | UIBorderRadius |
|-----------|----------------|
| `BorderRadius.circular(4)` | `BorderRadius.circular(UIBorderRadius.xs)` |
| `BorderRadius.circular(8)` | `BorderRadius.circular(UIBorderRadius.sm)` |
| `BorderRadius.circular(12)` | `BorderRadius.circular(UIBorderRadius.md)` |
| `BorderRadius.circular(16)` | `BorderRadius.circular(UIBorderRadius.lg)` |
| `BorderRadius.circular(20)` | `BorderRadius.circular(UIBorderRadius.xl)` |
| `BorderRadius.circular(999)` | `BorderRadius.circular(UIBorderRadius.circular)` |

---

## Internationalization (i18n)

所有使用者可見文字必須取自 ARB 產生的 localization 類別，禁止硬編碼字串。存取方式依專案的 `l10n.yaml` 設定而定，常見兩種：`AppLocalizations.of(context).keyName`（`nullable-getter: false`）或 `context.l10n!.keyName`（專案自建 extension）。動手前先讀專案的 `l10n.yaml` 與既有呼叫點確認慣例，勿沿用他專案的寫法。

---

## Common Violations and Fixes

### Violation 1: Hardcoded Colors

```dart
// Violation
Container(color: Colors.blue)
Container(color: Color(0xFF2196F3))

// Fix
Container(color: UIColors.primary)
```

### Violation 2: Hardcoded Spacing

```dart
// Violation
SizedBox(height: 16)
Padding(padding: EdgeInsets.all(8))

// Fix
SizedBox(height: UISpacing.md)
Padding(padding: EdgeInsets.all(UISpacing.xs))
```

### Violation 3: Hardcoded Font Size

```dart
// Violation
TextStyle(fontSize: 14)

// Fix
TextStyle(fontSize: UIFontSizes.bodyMedium)
```

### Violation 4: Hardcoded Border Radius

```dart
// Violation
BorderRadius.circular(8)

// Fix
BorderRadius.circular(UIBorderRadius.sm)
```

### Violation 5: Hardcoded Text

使用者可見文字直接寫在 widget 內，未取自 ARB。`style_checker.py scan` 以 `[i18n]` 標記回報這類違規；修正方式是把字串移入 ARB 檔並改以 localization 類別存取（存取語法見上方 Internationalization 節）。

### Violation 6: ViewModel Hardcoded User Messages

**Scope**: `lib/presentation/**/viewmodel.dart`, `lib/presentation/**_viewmodel.dart`

**Detection Pattern**: String literals assigned to error/message state properties

```dart
// Violation - Hardcoded user messages in ViewModel
state = state.copyWith(errorMessage: 'Invalid file format');
state = state.copyWith(errorMessage: '網路連線失敗');
_errorMessage = 'Something went wrong';

// Fix - Use i18n or ErrorHandler
state = state.copyWith(errorMessage: context.l10n!.invalidFileFormat);
state = state.copyWith(errorMessage: ErrorHandler.getUserMessage(exception));
```

**Allowed Exceptions**:
- `e.toString()` for unknown system exceptions
- String interpolation with i18n: `context.l10n!.errorWithCode(code)`

**Related**（Flutter 專案適用）: ViewModel 層使用者訊息規範見專案根目錄 `FLUTTER.md`（僅 Flutter 專案存在；非 Flutter 專案略過 Violation 6）

---

## Project Calibration

偵測規則本身跨專案通用（硬編碼的顏色、間距、字級一律該進 design system），但**替代方案的名字是專案專屬的**。校準檔告訴掃描器本專案的詞彙：

`.claude/config/dart-style-guardian.json`

```json
{
  "tokens": {
    "color": "AppPalette",
    "spacing": "AppSpacing",
    "font_size": "AppTypography",
    "border_radius": "AppRadius"
  },
  "i18n": {
    "accessor": "AppLocalizations.of(context).keyName",
    "compliance_pattern": "AppLocalizations\\.of\\("
  },
  "exempt_markers": ["magic-exempt", "i18n-exempt"]
}
```

| 欄位 | 作用 |
|------|------|
| `tokens.*` | 修正建議指名的類別；同時作為「此行已合規」的判定依據 |
| `i18n.accessor` | i18n 建議中顯示的存取語法 |
| `i18n.compliance_pattern` | 判定該行已使用 localization 的正則 |
| `exempt_markers` | 行內註解含此標記即豁免，並計入報告的 exempt 計數 |

**缺此檔時**：掃描器仍偵測硬編碼，但建議改為描述性敘述（「改用專案 design system 的 color token」），並在 stderr 提示。這是刻意的——指名某套命名等於斷言它是對的，而讀者照著不存在的類別動手會寫出編譯不過的程式碼。

**豁免的可見性**：被標記豁免的行不列為違規，但計數會出現在報告（`Exempt (marked in source): N`）。靜默略過的行與掃描器看不見的行無法區分，讀者也就無從判斷標記是否真的生效。

**單一規則來源**：PostEdit hook（`.claude/hooks/dart-style-guardian-hook.py`）匯入 `style_checker` 的規則與校準，不另維護一份。兩套規則各自演化的結果是 hook 與 skill 給出互相矛盾的建議。

---

## Detection Script Usage

### Manual Scan

```bash
# Scan entire project
uv run .claude/skills/dart-style-guardian/scripts/style_checker.py scan lib/

# Scan specific directory
uv run .claude/skills/dart-style-guardian/scripts/style_checker.py scan lib/presentation/

# Generate report
uv run .claude/skills/dart-style-guardian/scripts/style_checker.py report
```

### Hook Integration

The style checker is integrated into PostEdit Hook:
- Automatically scans edited files in `lib/presentation/`
- Reports violations in hook output
- Suggests fixes based on this guide

---

## Related Documentation

### Project Files

同上節，以角色而非路徑指涉：design system token 定義、theme 組裝入口、`l10n.yaml` 與其指向的 ARB、設計規格文件。要知道本專案的實際位置，讀 `.claude/config/dart-style-guardian.json` 與 `l10n.yaml`，或直接搜尋 token 類別名的定義處。

### Reference Files (in this SKILL)

四份，各自該在什麼時候讀見本檔上方〈五類約束與按需讀取〉表——此處只列存在，不重複判準：
`references/color-system.md`、`references/spacing-system.md`、`references/typography-system.md`、`references/i18n-guidelines.md`。

### External Resources
- [Flat Design Explained - MasterClass](https://www.masterclass.com/articles/flat-design-explained)
- [Best Practices for Flat Design - Usersnap](https://usersnap.com/blog/flat-design/)
- [Material Design 3 Color System](https://m3.material.io/styles/color/overview)

---

## Quick Reference Card

### Import Statement

```dart
import 'package:book_overview_app/core/ui/ui_config.dart';
```

### Common Replacements

| Type | Hardcoded | Configuration |
|------|-----------|---------------|
| **Color** | `Colors.blue` | `UIColors.primary` |
| **Success** | `Colors.green` | `UIColors.positive` |
| **Warning** | `Colors.orange` | `UIColors.negative` |
| **Spacing** | `16` | `UISpacing.md` |
| **Font** | `14` | `UIFontSizes.bodyMedium` |
| **Radius** | `8` | `UIBorderRadius.sm` |
| **Text** | `'My Library'` | `context.l10n!.libraryTitle` |

### Responsive Suffixes

| Suffix | Purpose | Example |
|--------|---------|---------|
| `.w` | Width scaling | `16.w` |
| `.h` | Height scaling | `16.h` |
| `.rsp` | Font scaling | `14.rsp` |
| `.r` | Radius scaling | `8.r` |

---

版本紀錄在同目錄的 `CHANGELOG.md`。
