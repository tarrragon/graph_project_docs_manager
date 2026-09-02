/// 可點的節點參照 chip（SPEC-004 §4.19）。
///
/// 節點詳情右欄的關聯節點 ID（等寬字，點擊替換主欄）與步驟表的 domain 欄
/// （一般字，點擊 jump 至 Domain 視圖）共用同一元件，只有目的地不同（依
/// skill「只是目的地不同者為 slot」合為一件）；字型以 [isMono] 參數區分。
///
/// `damaged` 狀態不是本元件的內部變體：損壞邊由呼叫端在外層包
/// `IssueMarker.damagedEdge`（尚未建立，SPEC-004 4.6），本元件的視覺與
/// `onTap` 皆由呼叫端決定，一律以同一份 chip 外觀渲染（SPEC-004 §4.19
/// 「狀態矩陣」default／damaged 同色，差異僅在外包裝與呼叫端傳入的
/// `onTap` 語意）。
library;

import 'package:flutter/material.dart' show InkWell, Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_text.dart';

/// 節點參照 chip（SPEC-004 §4.19）。
///
/// 單一變體：[id] slot 恆單行截斷；[isMono] 決定等寬或一般字型
/// （右欄關聯節點預設 `true`，步驟表 domain 欄呼叫端傳 `false`）。
class RelationItem extends StatefulWidget {
  const RelationItem({
    super.key,
    required this.id,
    this.isMono = true,
    required this.onTap,
    required this.testKey,
  });

  /// 節點 ID 或 domain 名（呼叫端資料值）。
  final String id;

  /// `true`（預設）等寬字；步驟表 domain 欄傳 `false`。
  final bool isMono;

  /// 點選回呼；呼叫端依所在情境決定行為（替換主欄／jump 至 Domain 視圖／
  /// 跳轉破洞報告）。
  final VoidCallback onTap;

  /// 呼叫端定址 key（`card-nodeDetail-relation-<nodeId>` /
  /// `action-ucFlow-goto-domain-<domainId>`，SPEC-004 4.19 slot 契約）。
  final Key testKey;

  @override
  State<RelationItem> createState() => _RelationItemState();
}

class _RelationItemState extends State<RelationItem> {
  static const Color _unfocusedBorder = Colors.transparent; // color-exempt

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'RelationItem');
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

    return Semantics(
      key: widget.testKey,
      button: true,
      label: l10n.relationItemA11yLabel(widget.id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _focusNode.hasFocus ? AppColors.accent : _unfocusedBorder,
          ),
          borderRadius: BorderRadius.circular(Radius.md.r),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: LayoutSize.hitTargetMin.h),
          child: InkWell(
            onTap: widget.onTap,
            focusNode: _focusNode,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(Radius.md.r),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(
                horizontal: Space.sm.w,
                vertical: Space.sm.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceChip,
                borderRadius: BorderRadius.circular(Radius.md.r),
              ),
              child: AppText(
                widget.id,
                variant: widget.isMono
                    ? AppTextVariant.mono
                    : AppTextVariant.body,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
