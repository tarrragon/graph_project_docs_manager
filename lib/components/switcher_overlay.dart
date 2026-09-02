/// 專案切換覆蓋層容器（SPEC-004 4.42、5.16）。
///
/// 標題 + [RecentProjectItem] × N（垂直捲動）+ [Divider] + 選擇其他
/// [AppButton]；零項時只渲染標題 + 按鈕（[Divider] 不渲染）。錨定與
/// 進出場的顯示／隱藏由呼叫端決定（本容器不持有「收合」狀態，SPEC-004
/// 4.42「收合態不是本容器的狀態」）——本元件被掛載即代表展開，卸載即代表
/// 收合；本元件僅負責掛載時的淡入 + 向下展開動畫（`Motion.overlay`）。
///
/// Esc 與點外部皆呼叫 [onDismiss]；掛載時把鍵盤焦點移入浮層（首個可聚焦
/// 子件），卸載時把焦點交還掛載前的焦點持有者（多為
/// `ProjectSwitcherEntry`，SPEC-004 4.42 無障礙「焦點順序」）。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'divider.dart';
import 'recent_project_item.dart';

/// 專案切換覆蓋層容器。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [title] | 否 | 元件預設 `switcherTitle`（參數可覆蓋） |
/// | [items] | 是（可為空清單） | 0 項時只渲染標題與 [chooseOther] |
/// | [chooseOther] | 是 | 恰 1 個 `AppButton.text`，label 由呼叫端依項目數傳入 |
/// | [onDismiss] | 是 | Esc / 點外部觸發 |
/// | [maxHeight] | 否 | 入口下緣至視窗下緣扣除 `Space.xl` 的可用高；未傳則不限高（測試便利） |
/// | [testKey] | 是 | `state-switcher-expanded` / `state-switcher-no-recent` |
/// | [scrollKey] | 是 | `scroll-switcher-recent`；items 為空清單時不掛載捲動容器，此 key 不生效 |
class SwitcherOverlay extends StatefulWidget {
  const SwitcherOverlay({
    super.key,
    required this.items,
    required this.chooseOther,
    required this.onDismiss,
    required this.testKey,
    required this.scrollKey,
    this.title,
    this.maxHeight,
  });

  /// 標題文字；`null` 時顯示元件預設 `switcherTitle`。
  final String? title;

  /// 專案項清單，0..無上限。
  final List<RecentProjectItem> items;

  /// 選擇其他資料夾按鈕（`AppButton.text`）。
  final AppButton chooseOther;

  /// Esc 或點外部觸發的收合回呼。
  final VoidCallback onDismiss;

  /// 可用最大高；超出時 [items] 區改捲動。`null` 表不限高。
  final double? maxHeight;

  /// 呼叫端定址 key（`state-switcher-expanded` / `state-switcher-no-recent`）。
  final Key testKey;

  /// 專案項捲動區定址 key（`scroll-switcher-recent`）。
  final Key scrollKey;

  @override
  State<SwitcherOverlay> createState() => _SwitcherOverlayState();
}

class _SwitcherOverlayState extends State<SwitcherOverlay> {
  late final FocusScopeNode _scopeNode;
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(debugLabel: 'SwitcherOverlay');
    _previousFocus = FocusManager.instance.primaryFocus;
    // `FocusScope.autofocus` 只在掛載前尚無任何焦點持有者時生效；掛載前
    // 通常已有持有者（多為 `ProjectSwitcherEntry`），故明確在首幀後搶焦，
    // 確保鍵盤事件（Esc）進入本浮層而非停留在入口（SPEC-004 4.42 無障礙）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scopeNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    // 焦點交還掛載前的持有者（SPEC-004 4.42「焦點回到入口」）；
    // 卸載當下不需 mounted 檢查，requestFocus 作用在該節點物件本身。
    _previousFocus?.requestFocus();
    super.dispose();
  }

  void _onEscape() => widget.onDismiss();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title ?? l10n.switcherTitle;
    final hasItems = widget.items.isNotEmpty;

    return TapRegion(
      onTapOutside: (_) => widget.onDismiss(),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _onEscape},
        child: FocusScope(
          node: _scopeNode,
          autofocus: true,
          child: Semantics(
            container: true,
            scopesRoute: true,
            explicitChildNodes: true,
            label: title,
            child: _SwitcherOverlayEntrance(
              child: Container(
                key: widget.testKey,
                width: LayoutSize.overlayWidth,
                constraints: widget.maxHeight == null
                    ? null
                    : BoxConstraints(maxHeight: widget.maxHeight!),
                padding: EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  border: Border.all(color: AppColors.borderStrong),
                  borderRadius: BorderRadius.circular(Radius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Space.xs,
                        vertical: Space.xs,
                      ),
                      child: Semantics(
                        header: true,
                        child: AppText(title, variant: AppTextVariant.caption),
                      ),
                    ),
                    if (hasItems) ...[
                      SizedBox(height: Space.xxs),
                      Flexible(child: _buildItems()),
                      SizedBox(height: Space.xxs),
                      const Divider(),
                      SizedBox(height: Space.xxs),
                    ] else
                      SizedBox(height: Space.xxs),
                    widget.chooseOther,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItems() {
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in widget.items) ...[
          item,
          if (item != widget.items.last) SizedBox(height: Space.xxs),
        ],
      ],
    );
    return SingleChildScrollView(key: widget.scrollKey, child: list);
  }
}

/// 掛載時的淡入 + 向下展開動畫（`Motion.overlay`）。
///
/// 用 [TweenAnimationBuilder] 而非外部 `isExpanded` 旗標驅動：本容器不存在
/// 收合狀態（SPEC-004 4.42），掛載本身即是「展開」事件，動畫在首次 build
/// 後自動播放一次。
class _SwitcherOverlayEntrance extends StatelessWidget {
  const _SwitcherOverlayEntrance({required this.child});

  final Widget child;

  static const double _slideDistance = 8;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.overlay(context),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -_slideDistance),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
