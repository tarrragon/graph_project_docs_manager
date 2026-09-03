/// AppShell（SPEC-004 §4.27 / §5.1）：根框架容器。
///
/// 標題列 / 側欄（`ProjectSwitcherEntry` + `NavItem` × 6）/ 主區
/// （`PageColumn` × 6，`IndexedStack`）三格；承載視窗邊緣內距與專案切換
/// 覆蓋層。與其他純「傳值 + callback」元件不同，本容器依 §2 定案為
/// `ConsumerWidget`，直接讀取 `lib/app/router.dart` 的
/// `selectedDestinationProvider` / `returnToProvider`（唯讀引用，非本票
/// 修改範圍）決定當前可見頁與返回鍵狀態。
///
/// 契約來源：`docs/spec/ui/SPEC-004-component-library.md` §4.27、§5.1。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
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
/// | [navItems] | 是 | 六個導覽項，依 `AppDestination.values` 順序 |
/// | [pages] | 是 | 六個頁面，與 [navItems] 同序，於 `IndexedStack` 一次建構 |
/// | [overlay] | 否 | `non-null` 即 overlayOpen 態（SPEC-004 4.27 狀態矩陣） |
/// | [testKey] | 是 | 呼叫端定址 key，預設 [AppShell.shellKey] |
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    this.title,
    required this.switcherEntry,
    required this.navItems,
    required this.pages,
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

  /// `non-null` 即 overlayOpen 態（SPEC-004 §4.27 slot 契約）。
  final SwitcherOverlay? overlay;

  /// 呼叫端定址 key，預設 [shellKey]。
  final Key testKey;

  bool get _isOverlayOpen => overlay != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destination = ref.watch(selectedDestinationProvider);
    final returnTo = ref.watch(returnToProvider);

    Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: LayoutSize.sidebarWidth,
          child: _Sidebar(switcherEntry: switcherEntry, navItems: navItems),
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
          child: _MainArea(
            destination: destination,
            returnTo: returnTo,
            pages: pages,
            onBack: () => consumeReturnTo(ref.read),
          ),
        ),
      ],
    );

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
              child: AppText(
                title,
                variant: AppTextVariant.body,
                emphasis: true,
                maxLines: 1,
              ),
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

/// 主區：返回列（`returnTo` 非 `null` 時）+ 六頁 `IndexedStack`
/// （SPEC-004 4.27 互動反應「返回鍵」）。
///
/// 既有 `PageColumn` 已建構完成，本容器不改寫其內部——以獨立返回列疊於
/// 內容之上呈現同一份對外行為（`action-<screen>-back` 錨點與行為不變），
/// 沿用 `lib/app/shell.dart` 既有的 `_ReturnToHeader` 佈局慣例。
class _MainArea extends StatelessWidget {
  const _MainArea({
    required this.destination,
    required this.returnTo,
    required this.pages,
    required this.onBack,
  });

  final AppDestination destination;
  final AppDestination? returnTo;
  final List<PageColumn> pages;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (returnTo != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: AppButton(
                label: l10n.backAction,
                onPressed: onBack,
                testKey: Key('action-${destination.name}-back'),
                variant: AppButtonVariant.secondary,
              ),
            ),
          ),
        Expanded(
          child: IndexedStack(index: destination.index, children: pages),
        ),
      ],
    );
  }
}
