/// 節點詳情（SPEC-001 §6；SPEC-003 §3.6；SPEC-004 §3.6）。
///
/// 五個狀態列依 [NodeDetailState] 切換，內容由 [NodeDetailFixtures] 供給
/// （本票決策：假資料驅動，不串真實資料）。返回鍵（`action-nodeDetail-back`）
/// 由 `AppShell` 之下的頁面框架統一渲染，本畫面不重複渲染（SPEC-003
/// §2.4）。
///
/// 缺件：「開啟原始檔」依 SPEC-004 §3.7 第 17 項核定應置於
/// `SplitRow.header` 右側 `ButtonRow`，但元件庫尚無「每頁頁首右側可依
/// 畫面自訂內容」的 per-screen trailing 掛點（`lib/app/shell.dart` 的
/// `SplitRow.header` 對六個畫面共用同一份 `leading: PageTitle`）；暫比照
/// `gap_report_screen.dart`（`0.1.0-W2-004`）的既有做法，將該按鈕改置於
/// 主欄內容頂部，待 `0.1.0-W2-008` 落地共用掛點後再遷移，見本票
/// NeedsContext。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/attention_level.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'node_detail_fixtures.dart';
import 'node_detail_providers.dart';
import 'node_detail_state.dart';

const String _tag = 'NodeDetailScreen';

/// 外部開啟的行程執行接縫（暫時，同 `gap_report_screen.dart`
/// `gapItemProcessRunnerProvider`／`domain_view_screen.dart`
/// `domainOpenSourceProcessRunnerProvider` 慣例）。
@visibleForTesting
final nodeDetailProcessRunnerProvider =
    Provider<Future<ProcessResult> Function(String, List<String>)>(
      (ref) => Process.run,
    );

/// 節點詳情畫面。
class NodeDetailScreen extends ConsumerWidget {
  const NodeDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nodeDetailStateProvider);
    return switch (state) {
      NodeDetailProjectUnready() => const _ProjectUnreadyView(),
      NodeDetailUnset() => const _UnsetView(),
      NodeDetailReady(:final nodeId) => _ReadyView(nodeId: nodeId),
      NodeDetailMissing(:final nodeId, :final lastKnownPath) => _MissingView(
        nodeId: nodeId,
        lastKnownPath: lastKnownPath,
      ),
    };
  }
}

/// 專案未就緒：`EmptyState.page`（SPEC-001 §6 共用定義；優先於「未選
/// 節點」判定，SPEC-003 §3.6）。
class _ProjectUnreadyView extends ConsumerWidget {
  const _ProjectUnreadyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.projectUnreadyMessage,
      testKey: const Key('state-nodeDetail-project-unready'),
      actions: [
        AppButton(
          label: l10n.gotoDomainAction,
          onPressed: () =>
              navigateTo(ref.read, AppDestination.domain, NavIntent.jump),
          testKey: const Key('action-nodeDetail-goto-domain'),
        ),
      ],
    );
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
          onPressed: () => navigateTo(
            ref.read,
            AppDestination.traceability,
            NavIntent.jump,
          ),
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
    final l10n = AppLocalizations.of(context);
    final node = NodeDetailFixtures.nodes[nodeId]!;
    final isPartial = node.damagedFields.isNotEmpty;
    final isTypeDamaged = node.damagedFields.contains('type');

    final main = Panel.scrollable(
      scrollKey: const Key('scroll-nodeDetail-content'),
      children: [
        // 開啟原始檔按鈕：暫代 per-screen 頁首掛點，見檔頭說明。
        ButtonRow(
          alignment: ButtonRowAlignment.end,
          children: [
            AppButton(
              label: l10n.openSourceFileAction,
              variant: AppButtonVariant.secondary,
              onPressed: () => _openSource(context, ref, node),
              testKey: const Key('action-nodeDetail-open-source'),
            ),
          ],
        ),
        ListRow.meta(
          leading: isTypeDamaged
              ? IssueMarker.damagedDetail(
                  explanation: l10n.fieldCorruptedMessage,
                  onTap: () =>
                      navigateTo(ref.read, AppDestination.gaps, NavIntent.jump),
                  testKey: const Key('action-nodeDetail-goto-gaps'),
                )
              : Badge.type(label: node.type),
          primary: AppText(node.filePath, variant: AppTextVariant.mono),
        ),
        AppText(node.title, variant: AppTextVariant.title),
        BadgeRow(children: [Badge.status(label: node.status)]),
        const Divider(),
        DocumentBody(
          markdown: node.markdown,
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
            header: AppText(category.label, variant: AppTextVariant.caption),
            items: [
              for (final relatedId in category.nodeIds)
                RelationItem(
                  id: relatedId,
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
      key: Key(
        isPartial ? 'state-nodeDetail-partial' : 'state-nodeDetail-normal',
      ),
      main: main,
      detail: detail,
    );
  }

  /// 開啟原始檔（SPEC-003 §3.6）：0.1 假資料路徑不對應磁碟上任何檔案，
  /// 恆走 `notFound` 分支——結果不出現 SnackBar，狀態轉換即回饋（同畫面
  /// 轉為 `state-nodeDetail-missing`，此為對外部變更的第一手偵測點）。
  /// 檔案存在時的兩種結局（`opened`／`failed`）由 [nodeDetailProcessRunnerProvider]
  /// 可覆寫，供測試指使 `Process.run` 結果，同 `gap_report_screen.dart`
  /// `_runOpen` 慣例。
  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    NodeDetailFixture node,
  ) async {
    final l10n = AppLocalizations.of(context);
    final exists = File(node.filePath).existsSync();
    if (!exists) {
      ref.read(nodeDetailStateProvider.notifier).state = NodeDetailMissing(
        nodeId: node.id,
        lastKnownPath: node.filePath,
      );
      return;
    }
    developer.log('外部開啟：${node.filePath}', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      final result = await ref.read(nodeDetailProcessRunnerProvider)('open', [
        node.filePath,
      ]);
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: result.exitCode == 0
            ? l10n.openedExternallyMessage
            : l10n.externalOpenFailedMessage,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
    } catch (error) {
      developer.log(
        '外部開啟失敗：$error', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: l10n.externalOpenFailedMessage,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
    }
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

  /// 重新整理三分支（SPEC-003 §3.6）：0.1 fixture 檔案存在時恆判定為
  /// 完整解析（無真實 re-parse 邏輯，斷點偵測待真實資料整合，CLAUDE.md
  /// §6「跨邊界驗證是正交屬性」現況盤點）；檔案仍不存在則維持本狀態並
  /// 提示 `sourceFileStillMissingMessage`。
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final exists = File(lastKnownPath).existsSync();
    if (!exists) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: l10n.sourceFileStillMissingMessage,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
      return;
    }
    ref.read(nodeDetailStateProvider.notifier).state = NodeDetailReady(
      nodeId: nodeId,
    );
  }
}
