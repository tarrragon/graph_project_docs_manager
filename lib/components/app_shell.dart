/// AppShell（SPEC-004 §4.27 / §5.1）：根框架容器。
///
/// 標題列 / 側欄（`ProjectSwitcherEntry` + `NavItem` × 6）/ 主區
/// （`PageColumn` × 6，`IndexedStack`）三格；承載視窗邊緣內距與專案切換
/// 覆蓋層。本容器為純「傳值 + callback」元件（0.5.0-W1-213.3：元件層不依賴
/// app／screens）：當前可見頁、返回鍵、降級旗標與推定版本皆由建構參數傳入，
/// 由組裝根（`lib/assembly/shell.dart`）讀 provider 後組裝。
///
/// 契約來源：`docs/spec/ui/SPEC-004-component-library.md` §4.27、§5.1。
library;

import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'badge.dart';
import 'nav_item.dart';
import 'page_column.dart';
import 'project_switcher_entry.dart';
import 'switcher_overlay.dart';

/// 根框架容器（SPEC-004 §4.27）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [title] | 否 | `null` 時顯示元件預設 `appTitle` |
/// | [switcherEntry] | 是 | 側欄頂端專案切換入口（恰 1） |
/// | [navItems] | 是 | 六個導覽項，依導覽目的地宣告順序 |
/// | [pages] | 是 | 六個頁面，與 [navItems] 同序，於 `IndexedStack` 一次建構 |
/// | [selectedIndex] / [screenName] | 是 | 當前頁序號與其錨點用名稱 |
/// | [hasBackAction] / [onBack] | 否 | 返回鍵是否顯示與其動作 |
/// | [isDegraded] 等 | 否 | 降級旗標、兩個版本值、推定版本 |
/// | [overlay] | 否 | `non-null` 即 overlayOpen 態（SPEC-004 4.27 狀態矩陣） |
/// | [testKey] | 是 | 呼叫端定址 key，預設 [AppShell.shellKey] |
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    this.title,
    required this.switcherEntry,
    required this.navItems,
    required this.pages,
    this.selectedIndex = 0,
    this.screenName = 'domain',
    this.hasBackAction = false,
    this.onBack,
    this.isDegraded = false,
    this.degradedBuiltinVersion,
    this.degradedProjectVersion,
    this.inferredVersion,
    this.overlay,
    this.testKey = shellKey,
  }) : assert(
         navItems.length == 6,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'navItems 恰 6 項（SPEC-004 4.27 slot 契約）',
       ),
       assert(
         pages.length == 6,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'pages 恰 6 項（SPEC-004 4.27 slot 契約）',
       );

  /// 整合測試與元件測試用來確認「已抵達殼」的錨點（SPEC-004 4.27 slot
  /// 契約 `testKey`）。
  static const Key shellKey = Key('app-shell');

  /// 側欄頂端專案名按鈕的錨點（SPEC-004 4.8 slot 契約 `testKey`）。
  static const Key projectSwitcherEntryKey = Key('project-switcher-entry');

  /// 標題列文字，`null` 時取 `appTitle`（SPEC-004 4.27 slot 契約）。
  final String? title;

  /// 側欄頂端專案切換入口（恰 1）。
  final ProjectSwitcherEntry switcherEntry;

  /// 六個導覽項，依 `AppDestination.values` 順序（SPEC-004 4.27 slot 契約）。
  final List<NavItem> navItems;

  /// 六個頁面，與 [navItems] 同序（SPEC-004 4.27 slot 契約）。
  final List<PageColumn> pages;

  /// 當前可見頁序號（`IndexedStack.index`）。
  final int selectedIndex;

  /// 當前畫面名稱，用於 `action-<screen>-back`、`badge-<screen>-*` 錨點。
  final String screenName;

  /// 為真時主區返回列顯示返回鍵。
  final bool hasBackAction;

  /// 返回鍵動作；[hasBackAction] 為真時使用。
  final VoidCallback? onBack;

  /// 降級型別表旗標；為真時常駐渲染降級徽章。
  final bool isDegraded;

  /// 降級徽章文字所需的內建版本；`null` 退回空字串。
  final String? degradedBuiltinVersion;

  /// 降級徽章文字所需的專案版本；`null` 退回空字串。
  final String? degradedProjectVersion;

  /// 推定版本；非 `null` 時渲染推定版本徽章，與 [isDegraded] 互斥。
  final String? inferredVersion;

  /// `non-null` 即 overlayOpen 態（SPEC-004 §4.27 slot 契約）。
  final SwitcherOverlay? overlay;

  /// 呼叫端定址 key，預設 [shellKey]。
  final Key testKey;

  bool get _isOverlayOpen => overlay != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: LayoutSize.sidebarWidth,
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(0),
            child: FocusTraversalGroup(
              child: _Sidebar(switcherEntry: switcherEntry, navItems: navItems),
            ),
          ),
        ),
        // 側欄與主區分隔線（§4.0.3 邊框線寬；「側欄與主區之間」明列於
        // `Divider`（4.3）「何時不用」，故不借用該元件，直接以本容器內部
        // 邊框承載）。
        const DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox.shrink(),
        ),
        Expanded(
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: FocusTraversalGroup(
              child: _MainArea(
                selectedIndex: selectedIndex,
                screenName: screenName,
                hasBackAction: hasBackAction,
                pages: pages,
                onBack: onBack ?? () {},
                isDegraded: isDegraded,
                degradedBuiltinVersion: degradedBuiltinVersion,
                degradedProjectVersion: degradedProjectVersion,
                inferredVersion: inferredVersion,
              ),
            ),
          ),
        ),
      ],
    );

    // SPEC-003 §2.10 Tab 區段順序：側欄整段先於主區；區段內沿用閱讀順序。
    body = FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: body);

    if (_isOverlayOpen) {
      // overlayOpen：背景導覽項不可點、焦點限制於浮層（SPEC-004 4.27
      // 狀態矩陣 / 無障礙）。`ExcludeFocus` 把背景整棵子樹移出焦點樹，
      // `IgnorePointer` 阻擋指標事件；浮層本身在 Stack 中另一分支，不受
      // 影響。
      body = ExcludeFocus(child: IgnorePointer(child: body));
    }

    return Semantics(
      key: testKey,
      container: true,
      label: title ?? l10n.appTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleBar(title: title ?? l10n.appTitle),
          Expanded(
            child: Stack(
              children: [
                body,
                if (overlay != null)
                  Positioned(left: 0, top: 0, child: overlay!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 頂端標題列（SPEC-004 4.27 slot 契約 `title`；內容政策：單行截斷）。
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LayoutSize.titleBarHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceChip,
          border: Border(bottom: BorderSide(color: AppColors.borderStrong)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: AppText.singleLine(title, emphasis: true),
            ),
          ),
        ),
      ),
    );
  }
}

/// 側欄：專案切換入口 + 六個導覽項，垂直堆疊（SPEC-004 §5.1 子件契約）。
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.switcherEntry, required this.navItems});

  final ProjectSwitcherEntry switcherEntry;
  final List<NavItem> navItems;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceSidebar),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Space.md,
          horizontal: Space.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switcherEntry,
            const SizedBox(height: Space.sm),
            for (final item in navItems) ...[
              item,
              if (item != navItems.last) const SizedBox(height: Space.xxs),
            ],
          ],
        ),
      ),
    );
  }
}

/// 主區：返回列（`returnTo` 非 `null`、`isDegraded` 或推定版本旗標為真時
/// 常駐）+ 六頁 `IndexedStack`（SPEC-004 4.27 互動反應「返回鍵」；
/// state-change 列降級／推定版本徽章「與返回列同一列常駐」）。
///
/// 既有 `PageColumn` 已建構完成，本容器不改寫其內部——以獨立返回列疊於
/// 內容之上呈現同一份對外行為（`action-<screen>-back` 錨點與行為不變），
/// 沿用 `lib/app/shell.dart` 既有的 `_ReturnToHeader` 佈局慣例。降級徽章
/// （`badge-<screen>-degraded-schema`）比照同一實作方式疊於本列左側，
/// 兩者互不覆蓋——`isDegraded` 為真且 `returnTo` 亦非 `null` 時，本列同時
/// 顯示徽章（左）與返回鍵（右）（SPEC-004 §4.27〈實作註記〉）。推定版本
/// 徽章（`badge-<screen>-inferred-version`）同一實作方式疊於本列左側，
/// 與降級徽章互斥（SPEC-001 v1.19〈推定版本〉註記：兩旗標不會同時出現，
/// `0.2.0-W1-042`）。
class _MainArea extends StatelessWidget {
  const _MainArea({
    required this.selectedIndex,
    required this.screenName,
    required this.hasBackAction,
    required this.pages,
    required this.onBack,
    required this.isDegraded,
    required this.degradedBuiltinVersion,
    required this.degradedProjectVersion,
    required this.inferredVersion,
  });

  final int selectedIndex;
  final String screenName;
  final bool hasBackAction;
  final List<PageColumn> pages;
  final VoidCallback onBack;

  /// 降級型別表旗標。為真時本列常駐渲染
  /// `badge-<screen>-degraded-schema`，即使無返回動作。
  final bool isDegraded;

  /// 徽章文字所需的兩個版本值；`null` 時徽章版本文字退回空字串，不阻擋
  /// 渲染（防禦性處理，非預期路徑）。
  final String? degradedBuiltinVersion;
  final String? degradedProjectVersion;

  /// 推定版本。非 `null` 時本列常駐渲染 `badge-<screen>-inferred-version`；
  /// 與 [isDegraded] 互斥（SPEC-001 v1.19〈推定版本〉註記）。
  final String? inferredVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasInferredVersion = inferredVersion != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasBackAction || isDegraded || hasInferredVersion)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isDegraded)
                  Badge.tag(
                    key: Key('badge-$screenName-degraded-schema'),
                    label: l10n.degradedSchemaBadgeLabel(
                      degradedBuiltinVersion ?? '',
                      degradedProjectVersion ?? '',
                    ),
                  )
                else if (hasInferredVersion)
                  Badge.tag(
                    key: Key('badge-$screenName-inferred-version'),
                    label: l10n.inferredVersionBadgeLabel(
                      inferredVersion ?? '',
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (hasBackAction)
                  AppButton(
                    label: l10n.backAction,
                    onPressed: onBack,
                    testKey: Key('action-$screenName-back'),
                    variant: AppButtonVariant.secondary,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(index: selectedIndex, children: pages),
        ),
      ],
    );
  }
}
