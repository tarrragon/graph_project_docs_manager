/// 節點詳情（SPEC-001 §6；SPEC-003 §3.6；SPEC-004 §3.6）。
///
/// 五個狀態列依 [NodeDetailState] 切換，節點資料預設由共用掃描輪次的建圖
/// 結果投影（`0.5.0-W1-114.25`，見 `node_detail_providers.dart`）；
/// [NodeDetailFixtures] 只供測試注入。返回鍵（`action-nodeDetail-back`）
/// 由 `AppShell` 之下的頁面框架統一渲染，本畫面不重複渲染（SPEC-003
/// §2.4）。「開啟原始檔」依 SPEC-004 §3.7 第 17 項核定置於
/// `SplitRow.header` 右側 `ButtonRow`，見 [NodeDetailHeaderTrailing]
/// （`lib/app/shell.dart` 接線）。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/attention_level.dart';
import '../../app/project_unready_view.dart';
import '../../app/router.dart';
import '../../app/workspace_selection.dart' show projectGenerationProvider;
import '../../components/components.dart';
import '../../corpus/frontmatter_classifier.dart';
import '../../corpus/parse_outcome.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/external_opener.dart';
import '../../workspace/open_path_resolver.dart';
import '../../workspace/current_workspace_provider.dart';
import '../../workspace/stale_open_result.dart';
import 'node_detail_fixtures.dart';
import 'node_detail_providers.dart';
import 'node_detail_state.dart';

const String _tag = 'NodeDetailScreen';

/// 節點詳情畫面。
class NodeDetailScreen extends ConsumerWidget {
  const NodeDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nodeDetailStateProvider);
    return switch (state) {
      NodeDetailProjectUnready(:final reason) => ProjectUnreadyView(
        reason: reason,
        stateKey: const Key('state-nodeDetail-project-unready'),
        actionKey: const Key('action-nodeDetail-goto-domain'),
      ),
      NodeDetailUnset() => const _UnsetView(),
      NodeDetailReady(:final nodeId) => _ReadyView(nodeId: nodeId),
      NodeDetailMissing(:final nodeId, :final lastKnownPath) => _MissingView(
        nodeId: nodeId,
        lastKnownPath: lastKnownPath,
      ),
    };
  }
}

/// 未選節點：`EmptyState.page`（SPEC-001 §6 v1.3 新增，經導覽列直接進入
/// 且無選定節點）。
class _UnsetView extends ConsumerWidget {
  const _UnsetView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.noNodeSelectedMessage,
      testKey: const Key('state-nodeDetail-unset'),
      actions: [
        AppButton(
          label: l10n.gotoTraceabilityAction,
          onPressed: () =>
              navigateTo(ref.read, AppDestination.traceability, NavIntent.jump),
          testKey: const Key('action-nodeDetail-goto-traceability'),
        ),
      ],
    );
  }
}

/// 正常／部分損壞共用：`TwoColumnLayout`[主欄「meta + 標題 + 徽章 + 分隔線
/// + 內文」、右欄「關聯分節」]（SPEC-004 §3.6 §6「正常」列）。
class _ReadyView extends ConsumerWidget {
  const _ReadyView({required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeDetailNodesProvider)[nodeId];
    if (node == null) return const _UnsetView();
    // 部分損壞分支（state-nodeDetail-partial）在 0.x 不可達而退場，
    // 恢復條件見 0.5.0-W1-540.1.1。
    final main = Panel.scrollable(
      scrollKey: const Key('scroll-nodeDetail-content'),
      children: [
        ListRow.meta(
          leading: Badge.type(label: node.type),
          primary: AppText.singleLine(
            node.filePath,
            variant: AppTextVariant.mono,
          ),
        ),
        AppText.singleLine(node.title, variant: AppTextVariant.title),
        BadgeRow(children: [Badge.status(label: node.status)]),
        const Divider(),
        DocumentBody(
          markdown: ref.watch(nodeDetailBodyProvider(nodeId)),
          testKey: const Key('panel-nodeDetail-document-body'),
        ),
      ],
    );

    final detail = Panel.scrollable(
      scrollKey: const Key('scroll-nodeDetail-relations'),
      children: [
        for (final category in node.relations)
          Section(
            variant: SectionVariant.static,
            header: AppText.singleLine(
              category.label,
              variant: AppTextVariant.caption,
            ),
            items: [
              for (final relatedId in category.nodeIds)
                RelationItem(
                  id: relatedId,
                  isProposed: category.isProposed,
                  onTap: () =>
                      ref.read(nodeDetailStateProvider.notifier).state =
                          NodeDetailReady(nodeId: relatedId),
                  testKey: Key('card-nodeDetail-relation-$relatedId'),
                ),
            ],
            testKey: Key('panel-nodeDetail-relations-${category.label}'),
          ),
      ],
    );

    return TwoColumnLayout(
      key: const Key('state-nodeDetail-normal'),
      main: main,
      detail: detail,
    );
  }
}

/// `SplitRow.header` 右格內容（`lib/app/shell.dart` 接線，同
/// `DomainHeaderTrailing`／`TicketsHeaderTrailing`／`GapReportHeaderTrailing`
/// 慣例）：僅「正常／部分損壞」列渲染開啟原始檔鈕（SPEC-004 §3.7 第 17
/// 項；返回鍵由 `AppShell` 之下的頁面框架單一渲染，不在此重複）。
class NodeDetailHeaderTrailing extends ConsumerWidget {
  const NodeDetailHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nodeDetailStateProvider);
    if (state is! NodeDetailReady) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final node = ref.watch(nodeDetailNodesProvider)[state.nodeId];
    if (node == null) return const SizedBox.shrink();
    return ButtonRow(
      alignment: ButtonRowAlignment.end,
      children: [
        AppButton(
          label: l10n.openSourceFileAction,
          variant: AppButtonVariant.secondary,
          onPressed: () => _openSource(context, ref, node),
          testKey: const Key('action-nodeDetail-open-source'),
        ),
      ],
    );
  }

  /// 開啟原始檔（SPEC-003 §3.6）：經 `ExternalOpener` 開啟；`notFound`
  /// 不出現 SnackBar，狀態轉換即回饋（同畫面轉為
  /// `state-nodeDetail-missing`，此為對外部變更的第一手偵測點）。
  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    NodeDetailFixture node,
  ) async {
    final l10n = AppLocalizations.of(context);
    final path = resolveOpenPath(
      ref.read(currentWorkspaceStateProvider),
      node.filePath,
    );
    final generation = ref.read(projectGenerationProvider);
    final result = path == null
        ? ExternalOpenResult.notFound
        : await ref.read(externalOpenerProvider).open(path);
    if (ref.read(projectGenerationProvider) != generation) {
      logStaleOpenResult(tag: _tag, i18nKey: openResultKey(result));
      return;
    }
    if (result == ExternalOpenResult.notFound) {
      ref.read(nodeDetailStateProvider.notifier).state = NodeDetailMissing(
        nodeId: node.id,
        lastKnownPath: node.filePath,
      );
      return;
    }
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: result == ExternalOpenResult.opened
          ? l10n.openedExternallyMessage
          : l10n.externalOpenFailedMessage,
      level: AttentionLevel.discardable,
      origin: AppSnackBarOrigin.userInitiated,
    );
  }
}

/// 原始檔已消失：`MissingSourceState`（SPEC-004 §3.6 §6「原始檔已消失」
/// 列）。
class _MissingView extends ConsumerWidget {
  const _MissingView({required this.nodeId, required this.lastKnownPath});

  final String nodeId;
  final String lastKnownPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MissingSourceState(
      path: lastKnownPath,
      onRefresh: () => _refresh(context, ref),
      testKey: const Key('state-nodeDetail-missing'),
    );
  }

  /// 重新整理三分支（SPEC-003 §3.6）：讀取單一檔案並以
  /// [classifyFrontmatter] 分類，不重跑整輪掃描。
  /// - 檔案仍不存在：維持本狀態，SnackBar `sourceFileStillMissingMessage`。
  /// - 存在且解析完整（[Available]）：轉為 [NodeDetailReady]。
  /// - 存在但解析失敗（其餘五種 [ParseOutcome]，含讀取失敗）：維持本狀態，
  ///   SnackBar `sourceFileUnparsableMessage`。
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // i18n-exempt: debug log
    developer.log('refresh start: $lastKnownPath', name: _tag);
    final outcome = _readOutcome();
    // i18n-exempt: debug log
    developer.log(
      'refresh result: ${outcome?.kind.name ?? 'missing'}',
      name: _tag,
    );
    if (outcome is Available) {
      ref.read(nodeDetailStateProvider.notifier).state = NodeDetailReady(
        nodeId: nodeId,
      );
      return;
    }
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: outcome == null
          ? l10n.sourceFileStillMissingMessage
          : l10n.sourceFileUnparsableMessage,
      level: AttentionLevel.discardable,
      origin: AppSnackBarOrigin.userInitiated,
    );
  }

  /// 檔案不存在回傳 null；存在則讀取位元組分類，讀取失敗視為解析失敗。
  ParseOutcome? _readOutcome() {
    final file = File(lastKnownPath);
    if (!file.existsSync()) return null;
    try {
      return classifyFrontmatter(file.readAsBytesSync());
    } on FileSystemException catch (error) {
      // i18n-exempt: debug log
      developer.log('refresh read failed: $error', name: _tag, level: 900);
      return ParseOutcome.unreadable(UnreadableReason.permission);
    }
  }
}
