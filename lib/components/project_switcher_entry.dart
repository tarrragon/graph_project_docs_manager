/// 側欄頂端專案切換入口（SPEC-004 §4.8）。
///
/// 資料夾圖示 + 目前專案名（單行截斷）+ 展開箭頭；等於 SPEC-001 §7「收合」
/// 態。本元件純顯示加回呼——展開狀態（[isExpanded]）由呼叫端持有，浮層本身
/// 由 `SwitcherOverlay` 承載（SPEC-004 §2 傳值 + callback 慣例）。三個阻擋
/// 狀態下 `enabled` 恆為 `true`（SPEC-003 §2.7 浮層可用性斷言），故本元件
/// 無 disabled 狀態。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 側欄頂端專案切換入口。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [projectName] | 否 | `null` 時顯示元件預設 key（`projectSwitcherEntryLabel`） |
/// | [isExpanded] | 是 | 浮層展開態旗標，決定箭頭方向與 `Semantics.expanded` |
/// | [onTap] | 是 | 點選（含 Space / Enter）觸發的回呼，展開／收合浮層由呼叫端決定 |
/// | [testKey] | 是 | 呼叫端定址 key（`AppShell.projectSwitcherEntryKey`） |
class ProjectSwitcherEntry extends StatefulWidget {
  const ProjectSwitcherEntry({
    super.key,
    this.projectName,
    required this.isExpanded,
    required this.onTap,
    required this.testKey,
  });

  /// 目前專案名；`null` 時顯示元件預設 key（SPEC-004 4.8 slot 契約）。
  final String? projectName;

  /// 浮層展開態旗標；決定箭頭方向與朗讀播報。
  final bool isExpanded;

  /// 點選（含鍵盤 Space / Enter）觸發的回呼。
  final VoidCallback onTap;

  /// 呼叫端定址 key。
  final Key testKey;

  @override
  State<ProjectSwitcherEntry> createState() => _ProjectSwitcherEntryState();
}

class _ProjectSwitcherEntryState extends State<ProjectSwitcherEntry> {
  /// 未聚焦時的邊框色：透明，僅焦點時（[AppColors.accent]）可見。
  /// 非語意色彩，不進 token 表。
  static const Color _unfocusedBorder = Colors.transparent; // color-exempt

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ProjectSwitcherEntry');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayName = widget.projectName ?? l10n.projectSwitcherEntryLabel;
    // 朗讀標籤（SPEC-004 4.8 無障礙）：「projectSwitcherEntryLabel，
    // {projectName}」；無專案名時只唸預設 key（其本身已是顯示文字）。
    final semanticsLabel = widget.projectName == null
        ? l10n.projectSwitcherEntryLabel
        : '${l10n.projectSwitcherEntryLabel}, ${widget.projectName}';

    return Semantics(
      key: widget.testKey,
      button: true,
      label: semanticsLabel,
      expanded: widget.isExpanded,
      child: SizedBox(
        height: LayoutSize.hitTargetMin,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: _focusNode.hasFocus
                    ? Border.all(color: AppColors.accent)
                    : Border.all(color: _unfocusedBorder),
                borderRadius: BorderRadius.circular(Radius.md),
              ),
              child: InkWell(
                onTap: () {
                  _focusNode.requestFocus();
                  widget.onTap();
                },
                focusNode: _focusNode,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(Radius.md),
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: LayoutSize.iconLg,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      // 純裝飾：展開狀態由 Semantics.expanded 旗標承載
                      // （SPEC-004 4.8 無障礙、§4.0.2 表 2）。
                      ExcludeSemantics(
                        child: Icon(
                          widget.isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: LayoutSize.iconMd,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
