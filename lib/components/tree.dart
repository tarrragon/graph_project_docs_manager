/// 容器：`ListRow.tree` × N 垂直，依深度縮排（SPEC-004 4.39、5.13）。
///
/// 追溯樹（`scroll-traceability-tree`）用：呼叫端建好每列的
/// [ListRow.tree]（含自身 leading `ExpanderIcon` 與 onTap），本容器只負責
/// 依 [expanded] 決定子層是否渲染、依 [TreeNode.depth] 縮排、以及子層
/// 出現/消失的動畫（SPEC-004 4.39「互動反應」）。展開集合存於呼叫端
/// provider（SPEC-004 §2 傳值 + callback 慣例），本元件不持有狀態。
///
/// [onToggle] 為契約要求的 slot（SPEC-004 5.13 slot 契約），但實際觸發
/// 已由呼叫端建好的每列 `ListRow.tree.leading`（`ExpanderIcon.onToggle`）
/// 承載——與 [Section.onToggle] 未被內部呼叫同一慣例（節首自帶觸發器）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'list_row.dart';

/// 樹節點：一列 + 其子層（SPEC-004 5.13 子件契約）。
///
/// [id] 供 [Tree.expanded] 判斷該節點子層是否可見；[row] 由呼叫端建好
/// （含自身 leading／onTap），[depth] 決定縮排（第 n 層 x = n ×
/// [LayoutSize.treeIndent]），[children] 深度上限 4（SPEC-004 5.13）。
class TreeNode {
  const TreeNode({
    required this.id,
    required this.row,
    required this.depth,
    this.children = const [],
  });

  /// 節點識別碼，對應 [Tree.expanded] 集合中的成員。
  final String id;

  /// 本列內容，呼叫端已建好（`ListRow.tree`）。
  final ListRow row;

  /// 縮排層數（0 起算：PROP / SPEC / UC / Ticket）。
  final int depth;

  /// 子節點；空清單代表葉節點（不渲染展開子層）。
  final List<TreeNode> children;
}

/// 容器：追溯樹（SPEC-004 4.39）。
class Tree extends StatelessWidget {
  const Tree({
    super.key,
    required this.nodes,
    required this.expanded,
    required this.onToggle,
  });

  /// 樹狀節點清單，深度上限 4（SPEC-004 5.13 子件契約）。
  final List<TreeNode> nodes;

  /// 目前展開的節點 id 集合（存於呼叫端 provider）。
  final Set<String> expanded;

  /// 展開收合觸發（SPEC-004 5.13 slot 契約）；實際觸發見檔頭說明。
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [for (final node in nodes) _buildNode(context, node)],
    );
  }

  Widget _buildNode(BuildContext context, TreeNode node) {
    final l10n = AppLocalizations.of(context);
    final row = Padding(
      padding: EdgeInsets.only(left: LayoutSize.treeIndent.w * node.depth),
      child: Semantics(
        label: l10n.treeDepthA11yLabel(node.depth),
        child: node.row,
      ),
    );

    if (node.children.isEmpty) {
      return row;
    }

    final isExpanded = expanded.contains(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        AnimatedSize(
          duration: Motion.transition(context),
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in node.children)
                      _buildNode(context, child),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
