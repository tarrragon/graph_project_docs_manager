/// 追溯視圖（SPEC-001 §3；SPEC-003 §3.3）。
///
/// 三個狀態（正常／鏈路斷裂／無提案）皆由 [traceabilityStateProvider]
/// 決定，元件 import 只來自 `lib/components/components.dart`（本票
/// acceptance 第一項）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'trace_providers.dart';
import 'trace_state.dart';

/// `nav-page-traceability` 的內容（追溯視圖）。
class TraceabilityScreen extends ConsumerWidget {
  const TraceabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(traceabilityStateProvider);

    return PageColumn(
      semanticLabel: l10n.navTraceability,
      header: SplitRow.header(leading: PageTitle(title: l10n.navTraceability)),
      content: switch (state) {
        TraceabilityNormal(:final roots) => _TraceTree(
            key: const Key('state-traceability-normal'),
            roots: roots,
          ),
        TraceabilityBroken(:final roots) => _TraceTree(
            key: const Key('state-traceability-broken'),
            roots: roots,
          ),
        TraceabilityNoProposal() => EmptyState(
            variant: EmptyStateVariant.page,
            testKey: const Key('state-traceability-no-proposal'),
            message: l10n.emptyProposalMessage,
            actions: [
              AppButton(
                label: l10n.gotoGapsReportAction,
                testKey: const Key('action-traceability-goto-gaps'),
                onPressed: () =>
                    navigateTo(ref.read, AppDestination.gaps, NavIntent.jump),
              ),
            ],
          ),
      },
    );
  }
}

/// 正常／鏈路斷裂共用的樹狀內容：`Panel.scrollable`[`Tree`[`ListRow.tree` × N]]
/// （ticket how 段句型）。
class _TraceTree extends ConsumerWidget {
  const _TraceTree({super.key, required this.roots});

  final List<TraceNode> roots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(expandedTraceNodesProvider);

    void onToggle(String nodeId) {
      final notifier = ref.read(expandedTraceNodesProvider.notifier);
      final next = {...notifier.state};
      if (!next.remove(nodeId)) {
        next.add(nodeId);
      }
      notifier.state = next;
    }

    void onTapNode(String nodeId) {
      navigateTo(ref.read, AppDestination.nodeDetail, NavIntent.jump);
    }

    void onTapGap(String gapLayer) {
      navigateTo(ref.read, AppDestination.gaps, NavIntent.jump);
    }

    return Panel.scrollable(
      scrollKey: const Key('scroll-traceability-tree'),
      children: [
        Tree(
          nodes: [
            for (final root in roots)
              _buildTreeNode(
                root,
                depth: 0,
                expanded: expanded,
                onToggle: onToggle,
                onTapNode: onTapNode,
                onTapGap: onTapGap,
              ),
          ],
          expanded: expanded,
          onToggle: onToggle,
        ),
      ],
    );
  }
}

/// 將 [TraceNode] 遞迴轉為 [TreeNode]：leading `ExpanderIcon`、trailing
/// `Badge.status` 或 `IssueMarker.gap`（缺口節點，SPEC-004 §4.40「變體」
/// `tree` 列）。
TreeNode _buildTreeNode(
  TraceNode node, {
  required int depth,
  required Set<String> expanded,
  required void Function(String nodeId) onToggle,
  required void Function(String nodeId) onTapNode,
  required void Function(String gapLayer) onTapGap,
}) {
  final isLeaf = node.children.isEmpty;
  final row = ListRow.tree(
    leading: ExpanderIcon(
      isExpanded: expanded.contains(node.id),
      isLeaf: isLeaf,
      onToggle: isLeaf ? null : () => onToggle(node.id),
      testKey: Key('expander-traceability-${node.id}'),
    ),
    primary: AppText(
      node.label,
      variant: AppTextVariant.body,
      emphasis: depth == 0,
    ),
    trailing: node.hasGap
        ? IssueMarker.gap(
            onTap: () => onTapGap(node.gapLayer!),
            testKey: Key('badge-traceability-broken-${node.gapLayer}'),
          )
        : Badge.status(label: node.status),
    onTap: () => onTapNode(node.id),
    testKey: Key('card-traceability-${node.id}'),
  );

  return TreeNode(
    id: node.id,
    row: row,
    depth: depth,
    children: [
      for (final child in node.children)
        _buildTreeNode(
          child,
          depth: depth + 1,
          expanded: expanded,
          onToggle: onToggle,
          onTapNode: onTapNode,
          onTapGap: onTapGap,
        ),
    ],
  );
}
