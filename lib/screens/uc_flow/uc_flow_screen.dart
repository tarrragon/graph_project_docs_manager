/// UC Flow 視圖（SPEC-001 §2；SPEC-003 §3.2；SPEC-004 §3.6）。
///
/// 五個狀態列依 [UcFlowState] 切換，內容由 [ucFlowStateProvider] 供給
/// （`0.5.0-W1-114.18` 起由真實輪次與 `flowOf` 驅動，見
/// `ucFlowUcListProvider`；假資料僅供測試注入）。
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
/// （[_UnstructuredView]）；所需 UC 基本資訊擴充於 `UcFlowUcItem`
/// （新增 `filePath`）。步驟表「點步驟→節點詳情」亦接上真實跳轉
/// （[_stepRow]，沿用 `trace_screen.dart` `onTapNode` 既有簡化：跳轉不
/// 額外設定 `nodeDetailStateProvider`，節點詳情固定顯示其預設值；步驟
/// 跳轉時帶目標節點由 `0.6.0-W1-077` 承接）。
library;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/attention_level.dart';
import '../../app/project_unready_view.dart';
import '../../app/router.dart';
import '../../app/workspace_selection.dart' show projectGenerationProvider;
import '../../app/selected_uc.dart';
import '../../app/uc_flow_focus.dart';
import '../../components/components.dart';
import '../../diagnostics/event_gap.dart' show presentationReservedWord;
import '../../l10n/app_localizations.dart';
import '../../tokens/tokens.dart';
import '../../workspace/external_opener.dart';
import '../../workspace/open_path_resolver.dart';
import '../../workspace/current_workspace_provider.dart';
import '../../workspace/stale_open_result.dart';
import 'uc_flow_providers.dart';
import 'uc_flow_state.dart';

const String _tag = 'UcFlowScreen';

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
      UcFlowUnstructured(:final ucId, :final isParseFailed) =>
        _UnstructuredView(ucId: ucId, isParseFailed: isParseFailed),
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
        fill: EmptyState(
          variant: EmptyStateVariant.section,
          message: l10n.ucUnsetPrompt,
          testKey: const Key('panel-ucFlow-uc-unset-prompt'),
        ),
      ),
      detail: const _UcSelectorPanel(),
    );
  }
}

/// flow 未結構化：`TwoColumnLayout`[`Panel`[`ListRow.meta`, `AppText.title`,
/// `EmptyState.section`（`ButtonRow` 動作：開啟原始檔、檢視關聯）], 〈UC
/// 選擇入口〉]（SPEC-004 §3.6 §2）。
class _UnstructuredView extends ConsumerWidget {
  const _UnstructuredView({required this.ucId, required this.isParseFailed});

  final String ucId;
  final bool isParseFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uc = _findUc(ref.watch(ucFlowUcListProvider), ucId);
    return TwoColumnLayout(
      key: const Key('state-ucFlow-unstructured'),
      main: Panel(
        leading: [
          ListRow.meta(
            key: const Key('panel-ucFlow-unstructured-meta'),
            leading: Badge.type(label: 'UC'), // i18n-exempt: 節點型別代碼
            primary: AppText.singleLine(
              uc.filePath,
              variant: AppTextVariant.mono,
            ),
          ),
          AppText.singleLine(uc.title, variant: AppTextVariant.title),
        ],
        fill: EmptyState(
          variant: EmptyStateVariant.section,
          message: isParseFailed
              ? l10n.flowParseFailedMessage
              : l10n.flowUnstructuredMessage,
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
      ),
      detail: const _UcSelectorPanel(),
    );
  }

  /// 開啟選定 UC 的原始檔（同 `domain_view_screen.dart` `_openSource`
  /// 慣例：經 `ExternalOpener` 開啟，三值對應 SPEC-003 §3.2）。
  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    UcFlowUcItem uc,
  ) async {
    final l10n = AppLocalizations.of(context);
    final path = resolveOpenPath(
      ref.read(currentWorkspaceStateProvider),
      uc.filePath,
    );
    final generation = ref.read(projectGenerationProvider);
    final result = path == null
        ? ExternalOpenResult.notFound
        : await ref.read(externalOpenerProvider).open(path);
    if (ref.read(projectGenerationProvider) != generation) {
      logStaleOpenResult(tag: _tag, i18nKey: openResultKey(result));
      return;
    }
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
class _NormalView extends ConsumerStatefulWidget {
  const _NormalView({required this.ucId});

  final String ucId;

  @override
  ConsumerState<_NormalView> createState() => _NormalViewState();
}

/// 跳轉定位逐段下捲的次數上限（防止目標不存在時無限迴圈）。
const int _maxLocateScrolls = 200;

/// 事件流小表列 key（跳轉定位與測試錨點）。
Key _eventRowKey(String event) => Key('row-ucFlow-event-$event');

class _NormalViewState extends ConsumerState<_NormalView> {
  String get ucId => widget.ucId;

  /// 跳轉定位（SPEC-001 §5）：目標屬本 UC 時，於本幀之後捲動到步驟列或
  /// 事件列，並高亮該列（SPEC-004 4.35 `step` / `eventFlow` located）。
  UcFlowFocus? _focusFor(WidgetRef ref) {
    final focus = ref.watch(ucFlowFocusProvider);
    return focus != null && focus.ucId == ucId ? focus : null;
  }

  /// 已為其排過定位的焦點（同一個焦點只定位一次，高亮重建不重捲）。
  UcFlowFocus? _locatedFocus;

  void _scheduleLocate(UcFlowUcItem uc, UcFlowFocus? focus) {
    final target = _locateKey(uc, focus);
    if (target == null || identical(focus, _locatedFocus)) return;
    _locatedFocus = focus;
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(target));
  }

  /// 列為懶建構：目標未建出時依視窗高度逐段下捲，直到目標建出後捲到可見。
  Future<void> _locate(Key target) async {
    final scrollable = _findScrollable();
    for (var i = 0; i < _maxLocateScrolls && mounted; i++) {
      final found = _findElementByKey(context as Element, target);
      if (found != null) {
        await Scrollable.ensureVisible(found, duration: Duration.zero);
        return;
      }
      final position = scrollable?.position;
      if (position == null || position.pixels >= position.maxScrollExtent) {
        return;
      }
      position.jumpTo(
        (position.pixels + position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  ScrollableState? _findScrollable() {
    final list = _findElementByKey(
      context as Element,
      const Key('scroll-ucFlow-steps'),
    );
    if (list == null) return null;
    ScrollableState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        found = element.state as ScrollableState;
        return;
      }
      element.visitChildren(visit);
    }

    list.visitChildren(visit);
    return found;
  }

  Key? _locateKey(UcFlowUcItem uc, UcFlowFocus? focus) {
    if (focus == null) return null;
    final eventId = focus.eventId;
    if (eventId != null) return _eventRowKey(eventId);
    final stepId = focus.stepId;
    if (stepId == null) return null;
    final index = uc.steps.indexWhere((s) => s.id == stepId);
    return index < 0 ? null : Key('card-ucFlow-step-$ucId-${index + 1}');
  }

  /// 步驟列是否為跳轉目標（flow 類帶 step id；無 id 的步驟不高亮）。
  bool _isStepLocated(UcFlowStepItem step, UcFlowFocus? focus) =>
      focus?.stepId != null && step.id == focus!.stepId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uc = _findUc(ref.watch(ucFlowUcListProvider), ucId);
    final focus = _focusFor(ref);
    _scheduleLocate(uc, focus);
    final steps = uc.steps;
    final eventRows = _buildEventFlowRows(l10n, steps, uc.eventSides);
    final locatedEvent = focus?.eventId;
    final gaps = ref.watch(ucFlowEventGapsProvider);

    final header = AppTableRow.header(
      columns: AppTableRow.stepColumns,
      cells: [
        const TableColumnHeader.blank(),
        TableColumnHeader.plain(label: l10n.columnStep),
        TableColumnHeader.plain(label: l10n.columnDomain),
        TableColumnHeader.plain(label: l10n.columnEvents),
      ],
    );

    final rows = [
      for (var i = 0; i < steps.length; i++)
        _stepRow(
          ref,
          ucId: ucId,
          index: i,
          step: steps[i],
          isLocated: _isStepLocated(steps[i], focus),
        ),
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
                const TableColumnHeader.blank(),
              ],
            ),
            rows: [
              for (final row in eventRows)
                AppTableRow.eventFlow(
                  key: _eventRowKey(row.event),
                  isLocated: row.event == locatedEvent,
                  event: AppText.singleLine(
                    row.event,
                    variant: AppTextVariant.mono,
                  ),
                  emittedBy: AppText.singleLine(row.emittedBy),
                  consumedBy: AppText.singleLine(row.consumedBy),
                  marker: gaps.isOrphan(row.event)
                      ? AppIcon(
                          key: Key('badge-ucFlow-event-orphan-${row.event}'),
                          icon: Icons.warning_amber_rounded,
                          size: IconSize.sm,
                          color: AppColors.error,
                          semanticLabel: l10n.orphanEventMarkerLabel,
                        )
                      : null,
                ),
            ],
            key: const Key('panel-ucFlow-event-flow'),
          );

    return Listener(
      // 任一指標按下即結束事件列高亮（SPEC-004 4.35 located 退出）。
      onPointerDown: (_) {
        if (ref.read(ucFlowFocusProvider) != null) {
          ref.read(ucFlowFocusProvider.notifier).state = null;
        }
      },
      child: TwoColumnLayout(
        key: const Key('state-ucFlow-normal'),
        main: Panel(
          fill: AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.stepColumns,
            header: header,
            rows: rows,
            scrollKey: const Key('scroll-ucFlow-steps'),
            appendix: eventFlowTable,
          ),
        ),
        detail: const _UcSelectorPanel(),
      ),
    );
  }

  AppTableRow _stepRow(
    WidgetRef ref, {
    required String ucId,
    required int index,
    required UcFlowStepItem step,
    required bool isLocated,
  }) {
    return AppTableRow.step(
      isLocated: isLocated,
      number: StepNumber(number: index + 1),
      stepName: AppText.singleLine(step.label),
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
          header: AppText.singleLine(
            l10n.ucSelectorTitle,
            variant: AppTextVariant.caption,
          ),
          items: [
            for (final uc in ucList)
              ListRow.option(
                primary: AppText.singleLine('${uc.id} ${uc.title}'),
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

/// 依 id 取 UC 項；選定 id 不在清單時（清單於選定後變動）以空殼項承接，
/// 不拋例外。
UcFlowUcItem _findUc(List<UcFlowUcItem> ucList, String ucId) =>
    ucList.where((uc) => uc.id == ucId).firstOrNull ??
    UcFlowUcItem(id: ucId, title: '', filePath: '');

/// 自 [root] 往下找第一個 widget key 等於 [target] 的 element。
Element? _findElementByKey(Element root, Key target) {
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget.key == target) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
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
  List<UcFlowStepItem> steps,
  Map<String, UcFlowEventSides> eventSides,
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
        emittedBy: _joinStepDomain(
          l10n,
          steps,
          event,
          emits: true,
          oppositeDomains: eventSides[event]?.producers ?? const [],
        ),
        consumedBy: _joinStepDomain(
          l10n,
          steps,
          event,
          emits: false,
          oppositeDomains: eventSides[event]?.consumers ?? const [],
        ),
      ),
  ];
}

/// [event] 於 [steps] 中發出（[emits] 為 `true`）或消費（`false`）的
/// 「步驟序號 · domain」清單，多個以「、」串接；缺側依 SPEC-001 §2〈事件
/// 流小表〉回退「本 UC 外」，附 [oppositeDomains]（EVT 節點宣告的對側
/// domain，`presentation` 顯示為「畫面」）；清單為空（含找不到 EVT 節點）
/// 時不帶括號。由 `test/unit/screens/uc_flow_test.dart` 的缺側測試覆蓋。
String _joinStepDomain(
  AppLocalizations l10n,
  List<UcFlowStepItem> steps,
  String event, {
  required bool emits,
  required List<String> oppositeDomains,
}) {
  final parts = <String>[];
  for (var i = 0; i < steps.length; i++) {
    final list = emits ? steps[i].emits : steps[i].consumes;
    if (list.contains(event)) {
      parts.add(l10n.eventFlowStepDomain('${i + 1}', steps[i].domain));
    }
  }
  if (parts.isEmpty) {
    return _outsideUcText(l10n, oppositeDomains);
  }
  return parts.join(_domainSeparator);
}

const _domainSeparator = '、'; // i18n-exempt: 中文頓號為 SPEC-001 §2 串接分隔符定義值

/// 「本 UC 外」格文字：對側清單為空時不帶括號（SPEC-001 v1.62 §2）。
String _outsideUcText(AppLocalizations l10n, List<String> domains) {
  if (domains.isEmpty) return l10n.eventOutsideUcBare;
  final shown = [
    for (final d in domains)
      d == presentationReservedWord ? l10n.swimlaneScreenLaneName : d,
  ];
  return l10n.eventOutsideUc(shown.join(_domainSeparator));
}
