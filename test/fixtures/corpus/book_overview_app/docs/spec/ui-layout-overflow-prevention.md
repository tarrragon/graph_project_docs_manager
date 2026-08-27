# UI 佈局溢出防護規範 (UI Layout Overflow Prevention)

> **定位**：本規範補足 `docs/ui_design_specification.md`（設計主軸）與 `docs/multi-language-layout-testing.md`（測試規範）之間的空白——「Widget 撰寫階段的 overflow 防護模式」。
>
> **適用範圍**：所有 `lib/presentation/widgets/` 與 `lib/presentation/pages/` 下使用 Flex 佈局（Row/Column/Flex）的 Widget。
>
> **實證錨點**：`lib/presentation/widgets/search/advanced_search_widget.dart:106` — Row 含未受 Flexible 包裹的 `SegmentedButton`，於 800x600 測試環境下溢出 714px，導致 22/23 widget test 紅燈（W1-010 / W1-011 / W1-011.2）。

---

## 1. 核心原則

| 原則 | 說明 |
|------|------|
| P1: Flex 內寬度不可預期元件必須受約束 | Row/Column 中任何「自然寬度可能超出可用空間」的子元件（SegmentedButton、ButtonBar、長 Text、Image、Chip 群組、多語字串）必須被 `Expanded` / `Flexible` / `Wrap` / `SingleChildScrollView` 包裹 |
| P2: 多語系字串視為不可預期寬度 | 中文短 / 日文中 / 德文長差異 2-3 倍，凡含 `AppLocalizations.of(context).*` 的 Text 預設套用 `Flexible` + `overflow: TextOverflow.ellipsis` |
| P3: 測試螢幕為防護基準線 | 預設 `WidgetTestHelper.createFullTestApp()` 提供 800x600；若元件在此尺寸溢出即視為 P0 缺陷，不得繞過測試 |
| P4: 禁止硬編碼尺寸 | 所有 size/spacing/borderRadius 必須引用 `lib/core/ui/ui_config.dart` 中 `UISpacing.*` / `UIBorderRadius.*` / `UIComponentSizes.*` / `UIFontSizes.*` 常數 |

---

## 2. 六大 Overflow 反模式與修正範例

### 反模式 1：Row 含未受約束的固定寬度元件（實證錨點）

**症狀**：`RenderFlex overflowed by N pixels on the right.`

**反模式範例**（取自 `advanced_search_widget.dart:106-147` 修復前）：

```dart
Row(
  children: [
    Icon(Icons.search, size: UISpacing.lg, color: UIColors.primary),
    SizedBox(width: UISpacing.sm),
    Expanded(
      child: Text(
        AppLocalizations.of(context).advancedSearch,
        style: TextStyle(fontSize: UIFontSizes.headline4),
      ),
    ),
    // 反模式：SegmentedButton 自然寬度 > 900px，未受 Flexible 包裹
    SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: false, label: Text(AppLocalizations.of(context).basicSearch)),
        ButtonSegment(value: true, label: Text(AppLocalizations.of(context).advancedSearch)),
      ],
      selected: {_isAdvancedMode},
      onSelectionChanged: (s) => setState(() => _isAdvancedMode = s.first),
    ),
  ],
)
```

**根因**：在 238.5px Container 中，Row 嘗試容納 Icon(24) + Text(Expanded) + SegmentedButton(>900px 自然寬度) → 溢出 714px。

**修正範例 A（推薦：寬螢幕並列、窄螢幕換行）**：

```dart
Wrap(
  spacing: UISpacing.sm,
  runSpacing: UISpacing.verticalSm,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search, size: UISpacing.lg, color: UIColors.primary),
        SizedBox(width: UISpacing.sm),
        Flexible(
          child: Text(
            AppLocalizations.of(context).advancedSearch,
            style: TextStyle(fontSize: UIFontSizes.headline4),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: false, label: Text(AppLocalizations.of(context).basicSearch)),
        ButtonSegment(value: true, label: Text(AppLocalizations.of(context).advancedSearch)),
      ],
      selected: {_isAdvancedMode},
      onSelectionChanged: (s) => setState(() => _isAdvancedMode = s.first),
    ),
  ],
)
```

**修正範例 B（精簡：窄螢幕降階為 IconButton）**：

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final useCompactMode = constraints.maxWidth < 400;
    return Row(
      children: [
        Icon(Icons.search, size: UISpacing.lg, color: UIColors.primary),
        SizedBox(width: UISpacing.sm),
        Expanded(
          child: Text(
            AppLocalizations.of(context).advancedSearch,
            style: TextStyle(fontSize: UIFontSizes.headline4),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (useCompactMode)
          IconButton(
            icon: Icon(_isAdvancedMode ? Icons.tune : Icons.search),
            onPressed: () => setState(() => _isAdvancedMode = !_isAdvancedMode),
          )
        else
          SegmentedButton<bool>(/* ... */),
      ],
    );
  },
)
```

---

### 反模式 2：Row 含多個未受約束的長 Text

**反模式**：

```dart
Row(
  children: [
    Text(AppLocalizations.of(context).bookTitle),    // 中文 4 字 / 德文 30 字
    SizedBox(width: UISpacing.md),
    Text(AppLocalizations.of(context).bookAuthor),   // 中文 3 字 / 德文 25 字
  ],
)
```

**修正**：

```dart
Row(
  children: [
    Expanded(
      flex: 2,
      child: Text(
        AppLocalizations.of(context).bookTitle,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
    SizedBox(width: UISpacing.md),
    Expanded(
      flex: 1,
      child: Text(
        AppLocalizations.of(context).bookAuthor,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  ],
)
```

---

### 反模式 3：Column 內含無高度約束的 ListView / GridView

**症狀**：`Vertical viewport was given unbounded height.` 或父 Column overflow。

**反模式**：

```dart
Column(
  children: [
    AppHeader(title: 'Books'),
    ListView.builder(itemCount: books.length, itemBuilder: ...),  // 反模式
  ],
)
```

**修正 A**（佔據剩餘空間）：

```dart
Column(
  children: [
    AppHeader(title: 'Books'),
    Expanded(
      child: ListView.builder(itemCount: books.length, itemBuilder: ...),
    ),
  ],
)
```

**修正 B**（已知少量項目，不需滾動）：

```dart
Column(
  children: [
    AppHeader(title: 'Books'),
    ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: books.length,
      itemBuilder: ...,
    ),
  ],
)
```

---

### 反模式 4：Icon + Text 組合未考慮多語擴張

**反模式**：

```dart
Row(
  children: [
    Icon(Icons.book, size: UIComponentSizes.iconMedium),
    SizedBox(width: UISpacing.xs),
    Text('Add to library'),  // 反模式：硬編碼 + 未受 Flexible 包裹
  ],
)
```

**修正**：

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.book, size: UIComponentSizes.iconMedium),
    SizedBox(width: UISpacing.xs),
    Flexible(
      child: Text(
        AppLocalizations.of(context).addToLibrary,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  ],
)
```

---

### 反模式 5：Chip / Tag 群組以 Row 並列

**反模式**：

```dart
Row(
  children: tags.map((tag) => Chip(label: Text(tag))).toList(),
)
```

**修正**（Wrap 自動換行）：

```dart
Wrap(
  spacing: UISpacing.sm,
  runSpacing: UISpacing.verticalSm,
  children: tags.map((tag) => Chip(
    label: Text(
      tag,
      overflow: TextOverflow.ellipsis,
    ),
  )).toList(),
)
```

---

### 反模式 6：Dialog / BottomSheet 內 Column 未捲動

**反模式**：

```dart
AppDialog(
  child: Column(
    children: [/* 大量內容 */],
  ),
)
```

**修正**：

```dart
AppDialog(
  child: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [/* 大量內容 */],
    ),
  ),
)
```

---

## 3. 決策樹：選用哪個 Flex 防護元件？

```
是否為 Flex (Row/Column) 子元件？
├── 否 → 不適用本規範
└── 是 → 子元件自然寬度/高度是否可能超出可用空間？
    ├── 否（固定 Icon / 固定 SizedBox / 已知小元件） → 直接放置
    └── 是 → 主軸方向是否允許滾動？
        ├── 是（長列表 / 內容區） → Expanded + ListView/SingleChildScrollView
        └── 否（標題列 / 工具列 / Dialog header）
            ├── 元件可換行？ → Wrap
            ├── 元件可裁切？ → Flexible + TextOverflow.ellipsis (maxLines)
            └── 元件須降階？ → LayoutBuilder + 響應式切換（IconButton 取代 SegmentedButton）
```

| 元件 | 適用場景 |
|------|---------|
| `Expanded` | 子元件應佔滿剩餘空間（單一主要內容） |
| `Flexible` | 子元件需要彈性收縮但不強制佔滿（多元件並列） |
| `Wrap` | 子元件需要自動換行（Chip 群組、工具列、響應式並列） |
| `SingleChildScrollView` | 內容超出單一維度但允許滾動（Dialog / Form） |
| `LayoutBuilder` | 需要依可用空間切換不同 UI（寬螢幕 SegmentedButton / 窄螢幕 IconButton） |

---

## 4. Widget Test 撰寫檢查清單

於 `test/widget/**/*_test.dart` 撰寫測試時逐項確認：

### 4.1 環境初始化

- [ ] 使用 `WidgetTestHelper.createFullTestApp(widget)` 包裹被測 Widget（提供 ScreenUtil 800x600、AppLocalizations、Scaffold）
- [ ] 需 Provider override 時，使用 `WidgetTestHelper.createScreenUtilTestWrapper(child: ProviderScope(overrides: [...], child: MaterialApp(home: widget)))`
- [ ] 不直接 `tester.pumpWidget(MyWidget())`（缺 ScreenUtil 會導致 `.w` / `.h` / `.r` 拋例外）

### 4.2 Overflow 偵測

- [ ] 多語系敏感元件加入 `MultiLanguageWidgetTestHelper.verifyNoLayoutOverflow(tester, locales: ['zh_TW', 'en_US', 'ja_JP', 'de_DE'])`
- [ ] 含 SegmentedButton / ButtonBar / 長 Text 的元件，至少測試 800x600 預設尺寸
- [ ] 若元件在窄螢幕應降階，加入 LayoutBuilder 測試（`tester.binding.setSurfaceSize(Size(360, 640))`）

### 4.3 元件斷言

- [ ] 對話框斷言用 `find.byType(Dialog)`，不用 `AlertDialog`（專案實作差異）
- [ ] 按鈕斷言用 `find.byType(AppButton)`，不用 `TextButton`
- [ ] 文字斷言避免硬編碼中文，改用 `find.text(AppLocalizations.of(tester.element(find.byType(Scaffold))).advancedSearch)` 或測試 key

### 4.4 佈局溢出修復

- [ ] 測試報 `RenderFlex overflowed`：先檢查反模式 1-6 是否命中
- [ ] 修復後重跑 `flutter test test/widget/<target>_test.dart` 確認 0 overflow
- [ ] 若內容本應滾動，包 `SingleChildScrollView` 而非縮小字體規避

---

## 5. 既有元件參考清單

優先示範既有元件搭配，禁止重新造輪子：

| 既有元件 | 路徑 | 內建防護 |
|---------|------|--------|
| `AppButton` | `lib/core/ui/components/app_button.dart` | 已處理 onPressed null 狀態與多語標籤 |
| `AppCard` | `lib/core/ui/components/app_card.dart` | 已內建 maxWidth 約束 |
| `AppDialog` | `lib/core/ui/components/app_dialog.dart` | 已內建 SingleChildScrollView |
| `AppHeader` | `lib/core/ui/components/app_header.dart` | 已內建 Title Flexible 包裹 |
| `AppPageScaffold` | `lib/core/ui/components/app_page_scaffold.dart` | 已內建 SafeArea + responsive padding |
| `AppTextField` | `lib/core/ui/components/app_text_field.dart` | 已內建 multiline overflow |
| `AppBadge` | `lib/core/ui/components/app_badge.dart` | 已內建 Flex 友善尺寸 |

---

## 6. 配置常數引用對照表

| 場景 | 必用常數 | 禁止 |
|------|---------|------|
| 水平間距 | `UISpacing.xs/sm/md/lg/xl` | 硬編碼 `SizedBox(width: 8)` |
| 垂直間距 | `UISpacing.verticalXs/Sm/Md/Lg/Xl` | 硬編碼 `SizedBox(height: 16)` |
| 圓角 | `UIBorderRadius.xs/sm/md/lg/xl/circular` | 硬編碼 `BorderRadius.circular(8)` |
| 字體 | `UIFontSizes.headline1-4 / body* / button / caption` | 硬編碼 `fontSize: 14` |
| 顏色 | `UIColors.primary* / positive / negative / surface*` | 硬編碼 `Color(0xFF...)` |
| 圖示尺寸 | `UIComponentSizes.iconXSmall/Small/Medium/Large/icon20` | 硬編碼 `size: 24` |
| 按鈕高度 | `UIComponentSizes.buttonSmall/Medium/Large` | 硬編碼 `height: 48` |
| 陰影 | `UIShadows.card / button / dialog / raised / inset` | 自訂 BoxShadow |
| 動畫時長 | `UIAnimations.fast/medium/slow` | 硬編碼 `Duration(milliseconds: 300)` |

---

## 7. 與既有規範分工

| 文件 | 主軸 | 與本規範關係 |
|------|------|------------|
| `docs/ui_design_specification.md` | 平面化設計 + 三色系統 + 響應式 | 本規範補足「Flex 防護」章節 |
| `docs/advanced-search-ui-component-specs.md` | AdvancedSearchWidget 元件規範 | 本規範以其第 106 行作為實證錨點 |
| `docs/multi-language-layout-testing.md` | 多語系測試規範 | 本規範引用其 `verifyNoLayoutOverflow` API |
| `docs/i18n-guidelines.md` | i18n 文字策略 | 本規範引用其 `AppLocalizations` 使用模式 |
| `CLAUDE.md` §7.5 | Widget 測試規範 | 本規範第 4 節對應其 `WidgetTestHelper` 使用 |

---

**Source**: 0.31.1-W1-010（22 test failures）、0.31.1-W1-011（group ticket）、0.31.1-W1-011.1（本規範）
**Last Updated**: 2026-05-28
**Version**: 1.0.0 — 初始建立，六大 overflow 反模式 + Widget Test 檢查清單 + 既有元件/常數對照
