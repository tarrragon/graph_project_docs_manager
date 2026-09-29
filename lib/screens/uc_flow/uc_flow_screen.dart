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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/attention_level.dart';
import '../../app/project_unready_view.dart';
import '../../app/router.dart';
import '../../app/selected_uc.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/external_opener.dart';
import '../../workspace/open_path_resolver.dart';
import '../project_switcher/project_switcher_providers.dart';
import 'uc_flow_fixtures.dart';
import 'uc_flow_providers.dart';
import 'uc_flow_state.dart';

/// UC Flow 視圖畫面。
class UcFlowScreen extends ConsumerWidget {
  const UcFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ucFlowStateProvider);
    return switch (state) {
      UcFlowProjectUnready(:final reason) => ProjectUnreadyView(
        reason: reason,
        stateKey: const Key('state-ucFlow-project-unready'),
        actionKey: const Key('action-ucFlow-goto-domain'),
      ),
      UcFlowEmpty() => const _EmptyView(),
      UcFlowUcUnset() => const _UcUnsetView(),
      UcFlowUnstructured(ucId: final ucId) => _UnstructuredView(ucId: ucId),
      UcFlowNormal(ucId: final ucId) => _NormalView(ucId: ucId),
    };
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
      message: l10n.emptyUcMessage,
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
  /// 慣例：經 `ExternalOpener` 開啟，三值對應 SPEC-003 §3.2）。
  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    UcFlowFixtureUc uc,
  ) async {
    final l10n = AppLocalizations.of(context);
    final path = resolveOpenPath(
      ref.read(currentWorkspaceStateProvider),
      uc.filePath,
    );
    final result = path == null
        ? ExternalOpenResult.notFound
        : await ref.read(externalOpenerProvider).open(path);
    if (!context.mounted) return;
    final message = switch (result) {
      ExternalOpenResult.opened => l10n.openedExternallyMessage,
      ExternalOpenResult.notFound => l10n.sourceFileNotFoundSnackbarMessage,
      ExternalOpenResult.failed => l10n.externalOpenFailedMessage,
    };
    AppSnackBar.show(
      context,
      message: message,
      level: AttentionLevel.discardable,
      origin: AppSnackBarOrigin.userInitiated,
    );
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
          header: AppText(
            l10n.ucSelectorTitle,
            variant: AppTextVariant.caption,
          ),
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
