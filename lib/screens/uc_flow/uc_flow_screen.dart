/// UC Flow 視圖（SPEC-001 §2；SPEC-003 §3.2；SPEC-004 §3.6）。
///
/// 五個狀態列依 [UcFlowState] 切換，內容由 [ucFlowStateProvider] 供給
/// （假資料驅動，見 [UcFlowFixtures]，本票決策：只交狀態渲染與退出
/// 路徑，不接真實資料）。
///
/// **`0.1.0-W2-010` 補齊**：`尚未選定 UC`／`flow 未結構化`／`正常`三態
/// 依 SPEC-004 §3.6 §2 對應行組成——前置票 `0.1.0-W3-634`（`ListRow.option`）
/// 與 `0.1.0-W3-635`（`TableRow.eventFlow`、`AppDataTable.appendix`）落地
/// 後，元件庫缺件已補齊。〈UC 選擇入口〉（三態共用）由 [_UcSelectorPanel]
/// 承載。
///
/// **`0.1.0-W2-013` 補齊**：`flow 未結構化`態依 SPEC-004 §3.6 §2 對應行
/// 補齊 `ListRow.meta`（型別標籤 + 原始檔路徑）與 `AppText.title`
/// （UC 標題），並接上「開啟原始檔」「檢視關聯」兩個動作
/// （[_UnstructuredView]）；所需 UC 基本資訊擴充於 [UcFlowFixtures]
/// （新增 `filePath`）。步驟表「點步驟→節點詳情」亦接上真實跳轉
/// （[_stepRow]，沿用 `trace_screen.dart` `onTapNode` 既有簡化：跳轉不
/// 額外設定 `nodeDetailStateProvider`，節點詳情固定顯示其預設值，0.1
/// 假資料階段步驟未帶對應節點 id，見本票 Solution）。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/attention_level.dart';
import '../../app/router.dart';
import '../../app/selected_uc.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'uc_flow_fixtures.dart';
import 'uc_flow_providers.dart';
import 'uc_flow_state.dart';

const String _tag = 'UcFlowScreen';

/// 開啟原始檔的行程執行接縫（暫時，同 `domain_view_screen.dart`
/// `domainOpenSourceProcessRunnerProvider` 慣例）。
@visibleForTesting
final ucFlowOpenSourceProcessRunnerProvider =
    Provider<Future<ProcessResult> Function(String, List<String>)>(
      (ref) => Process.run,
    );

/// UC Flow 視圖畫面。
class UcFlowScreen extends ConsumerWidget {
  const UcFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ucFlowStateProvider);
    return switch (state) {
      UcFlowProjectUnready() => const _ProjectUnreadyView(),
      UcFlowEmpty() => const _EmptyView(),
      UcFlowUcUnset() => const _UcUnsetView(),
      UcFlowUnstructured(ucId: final ucId) => _UnstructuredView(ucId: ucId),
      UcFlowNormal(ucId: final ucId) => _NormalView(ucId: ucId),
    };
  }
}

/// 專案未就緒：`EmptyState.page`（SPEC-001 §5 之後共用定義）。
class _ProjectUnreadyView extends ConsumerWidget {
  const _ProjectUnreadyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.projectUnreadyMessage,
      testKey: const Key('state-ucFlow-project-unready'),
      actions: [
        AppButton(
          label: l10n.gotoDomainAction,
          onPressed: () =>
              navigateTo(ref.read, AppDestination.domain, NavIntent.jump),
          testKey: const Key('action-ucFlow-goto-domain'),
        ),
      ],
    );
  }
}

/// 無 UC：`EmptyState.page`。
class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.noUcNodesMessage,
      testKey: const Key('state-ucFlow-empty'),
      actions: [
        AppButton(
          label: l10n.gotoGapsReportAction,
          onPressed: () =>
              navigateTo(ref.read, AppDestination.gaps, NavIntent.jump),
          testKey: const Key('action-ucFlow-goto-gaps'),
        ),
      ],
    );
  }
}

/// 尚未選定 UC：`TwoColumnLayout`[`Panel`[`EmptyState.section`], 〈UC 選擇
/// 入口〉]（SPEC-004 §3.6 §2）。
class _UcUnsetView extends ConsumerWidget {
  const _UcUnsetView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TwoColumnLayout(
      key: const Key('state-ucFlow-uc-unset'),
      main: Panel(
        children: [
          EmptyState(
            variant: EmptyStateVariant.section,
            message: l10n.ucUnsetPrompt,
            testKey: const Key('panel-ucFlow-uc-unset-prompt'),
          ),
        ],
      ),
      detail: const _UcSelectorPanel(),
    );
  }
}

/// flow 未結構化：`TwoColumnLayout`[`Panel`[`ListRow.meta`, `AppText.title`,
/// `EmptyState.section`（`ButtonRow` 動作：開啟原始檔、檢視關聯）], 〈UC
/// 選擇入口〉]（SPEC-004 §3.6 §2）。
class _UnstructuredView extends ConsumerWidget {
  const _UnstructuredView({required this.ucId});

  final String ucId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uc = UcFlowFixtures.ucList.firstWhere((uc) => uc.id == ucId);
    return TwoColumnLayout(
      key: const Key('state-ucFlow-unstructured'),
      main: Panel(
        children: [
          ListRow.meta(
            key: const Key('panel-ucFlow-unstructured-meta'),
            leading: Badge.type(label: 'UC'), // i18n-exempt: 節點型別代碼
            primary: AppText(uc.filePath, variant: AppTextVariant.mono),
          ),
          AppText(uc.title, variant: AppTextVariant.title),
          EmptyState(
            variant: EmptyStateVariant.section,
            message: l10n.flowUnstructuredMessage,
            testKey: const Key('panel-ucFlow-unstructured-message'),
            actions: [
              AppButton(
                label: l10n.openSourceFileAction,
                variant: AppButtonVariant.secondary,
                onPressed: () => _openSource(context, ref, uc),
                testKey: const Key('action-ucFlow-open-source'),
              ),
              AppButton(
                label: l10n.viewRelationsAction,
                variant: AppButtonVariant.secondary,
                onPressed: () => navigateTo(
                  ref.read,
                  AppDestination.nodeDetail,
                  NavIntent.jump,
                ),
                testKey: const Key('action-ucFlow-view-relations'),
              ),
            ],
          ),
        ],
      ),
      detail: const _UcSelectorPanel(),
    );
  }

  /// 開啟選定 UC 的原始檔（同 `domain_view_screen.dart` `_openSource`
  /// 慣例：0.1 假資料路徑不對應磁碟上任何檔案，恆走「找不到檔案」分支，
  /// 存在性檢查與行程呼叫仍走真實 `dart:io`）。
  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    UcFlowFixtureUc uc,
  ) async {
    final l10n = AppLocalizations.of(context);
    final exists = File(uc.filePath).existsSync();
    if (!exists) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: l10n.sourceFileNotFoundSnackbarMessage,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
      return;
    }
    developer.log('外部開啟：${uc.filePath}', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      final result = await ref.read(ucFlowOpenSourceProcessRunnerProvider)(
        'open',
        [uc.filePath],
      );
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

/// 正常：`TwoColumnLayout`[`Panel`[`DataTable.plain`（步驟表 + `appendix`
/// 事件流小表）], 〈UC 選擇入口〉]（SPEC-004 §3.6 §2）。
class _NormalView extends ConsumerWidget {
  const _NormalView({required this.ucId});

  final String ucId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uc = UcFlowFixtures.ucList.firstWhere((uc) => uc.id == ucId);
    final steps = uc.steps;
    final eventRows = _buildEventFlowRows(l10n, steps);

    final header = AppTableRow.header(
      columns: AppTableRow.stepColumns,
      cells: [
        const SizedBox.shrink(),
        TableColumnHeader.plain(label: l10n.columnStep),
        TableColumnHeader.plain(label: l10n.columnDomain),
        TableColumnHeader.plain(label: l10n.columnEvents),
      ],
    );

    final rows = [
      for (var i = 0; i < steps.length; i++)
        _stepRow(ref, ucId: ucId, index: i, step: steps[i]),
    ];

    final eventFlowTable = eventRows.isEmpty
        ? null
        : AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.eventFlowColumns,
            header: AppTableRow.header(
              columns: AppTableRow.eventFlowColumns,
              cells: [
                TableColumnHeader.plain(label: l10n.columnEvent),
                TableColumnHeader.plain(label: l10n.columnEmitter),
                TableColumnHeader.plain(label: l10n.columnConsumer),
                const SizedBox.shrink(),
              ],
            ),
            rows: [
              for (final row in eventRows)
                AppTableRow.eventFlow(
                  event: AppText(row.event, variant: AppTextVariant.mono),
                  emittedBy: AppText(row.emittedBy),
                  consumedBy: AppText(row.consumedBy),
                ),
            ],
            key: const Key('panel-ucFlow-event-flow'),
          );

    return TwoColumnLayout(
      key: const Key('state-ucFlow-normal'),
      main: Panel(
        children: [
          Expanded(
            child: AppDataTable(
              variant: AppDataTableVariant.plain,
              columns: AppTableRow.stepColumns,
              header: header,
              rows: rows,
              scrollKey: const Key('scroll-ucFlow-steps'),
              appendix: eventFlowTable,
            ),
          ),
        ],
      ),
      detail: const _UcSelectorPanel(),
    );
  }

  AppTableRow _stepRow(
    WidgetRef ref, {
    required String ucId,
    required int index,
    required UcFlowFixtureStep step,
  }) {
    return AppTableRow.step(
      number: StepNumber(number: index + 1),
      stepName: AppText(step.label),
      domain: RelationItem(
        id: step.domain,
        isMono: false,
        onTap: () =>
            navigateTo(ref.read, AppDestination.domain, NavIntent.jump),
        testKey: Key('action-ucFlow-goto-domain-$ucId-$index'),
      ),
      events: BadgeRow(
        children: [
          for (final event in step.emits) Badge.event(label: event),
          for (final event in step.consumes) Badge.event(label: event),
        ],
      ),
      // 點步驟→節點詳情（沿用 `trace_screen.dart` `onTapNode` 既有簡化，
      // 見檔頭說明）。
      onTap: () =>
          navigateTo(ref.read, AppDestination.nodeDetail, NavIntent.jump),
      testKey: Key('card-ucFlow-step-$ucId-${index + 1}'),
    );
  }
}

/// 〈UC 選擇入口〉（SPEC-004 §3.6，三態共用）：`Panel.scrollable`[
/// `Section.static`[`AppText.caption`, `ListRow.option` × N]]。
class _UcSelectorPanel extends ConsumerWidget {
  const _UcSelectorPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ucList = ref.watch(ucFlowUcListProvider);
    final selectedUcId = ref.watch(selectedUcProvider);

    return Panel.scrollable(
      scrollKey: const Key('scroll-ucFlow-uc-list'),
      children: [
        Section(
          variant: SectionVariant.static,
          testKey: const Key('panel-ucFlow-uc-selector'),
          header: AppText(l10n.ucSelectorTitle, variant: AppTextVariant.caption),
          items: [
            for (final uc in ucList)
              ListRow.option(
                primary: AppText('${uc.id} ${uc.title}'),
                isSelected: uc.id == selectedUcId,
                onTap: () =>
                    ref.read(selectedUcProvider.notifier).state = uc.id,
                testKey: Key('action-ucFlow-select-uc-${uc.id}'),
              ),
          ],
        ),
      ],
    );
  }
}

/// 事件流小表單列的組裝結果（事件 ID + 發出／消費文字，見
/// [_buildEventFlowRows]）。
class _EventFlowRowData {
  const _EventFlowRowData({
    required this.event,
    required this.emittedBy,
    required this.consumedBy,
  });

  final String event;
  final String emittedBy;
  final String consumedBy;
}

/// 依步驟清單的 `emits`／`consumes` 彙整事件流小表列（SPEC-001 §2〈事件
/// 流小表〉：一個事件一列，列序依首次出現的步驟序號；本 UC 無事件時回傳
/// 空清單，呼叫端據此不渲染 `appendix`）。
List<_EventFlowRowData> _buildEventFlowRows(
  AppLocalizations l10n,
  List<UcFlowFixtureStep> steps,
) {
  final seen = <String>[];
  for (final step in steps) {
    for (final event in [...step.emits, ...step.consumes]) {
      if (!seen.contains(event)) {
        seen.add(event);
      }
    }
  }
  return [
    for (final event in seen)
      _EventFlowRowData(
        event: event,
        emittedBy: _joinStepDomain(l10n, steps, event, emits: true),
        consumedBy: _joinStepDomain(l10n, steps, event, emits: false),
      ),
  ];
}

/// [event] 於 [steps] 中發出（[emits] 為 `true`）或消費（`false`）的
/// 「步驟序號 · domain」清單，多個以「、」串接；缺側依 SPEC-001 §2〈事件
/// 流小表〉回退「本 UC 外」（本畫面尚未接線 EVT 節點 frontmatter，見檔頭
/// 「本票擴充」說明，0.1 fixture 恆同 UC 內發出消費皆有，此分支現無測試
/// 覆蓋）。
String _joinStepDomain(
  AppLocalizations l10n,
  List<UcFlowFixtureStep> steps,
  String event, {
  required bool emits,
}) {
  final parts = <String>[];
  for (var i = 0; i < steps.length; i++) {
    final list = emits ? steps[i].emits : steps[i].consumes;
    if (list.contains(event)) {
      parts.add(l10n.eventFlowStepDomain('${i + 1}', steps[i].domain));
    }
  }
  if (parts.isEmpty) {
    return l10n.eventOutsideUc('');
  }
  return parts.join('、'); // i18n-exempt: 中文頓號為 SPEC-001 §2 串接分隔符定義值
}
