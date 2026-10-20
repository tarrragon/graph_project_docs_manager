/// Domain 視圖（SPEC-001 §1；SPEC-003 §3.1；SPEC-004 §3.6）。
///
/// 十一個狀態列依 [DomainViewState] 切換，五個「圖已建立」狀態
/// （正常 · 矩陣／已選格／正常 · 泳道／泳道 · 尚未選定 UC／泳道 ·
/// flow 未結構化）共用 [DomainReady]，實際子列由 [DomainReady.mode] +
/// App 層共用值 `selectedUcProvider`（`app/selected_uc.dart`）計算，見
/// [_readyBody]。矩陣取自 [DomainReady.matrix]、泳道取自
/// `domainSwimlaneProvider`，畫面只讀 state、不自算（`0.5.0-W1-114.21`）。
/// 頁首模式切換（`SegmentedControl`）由 [DomainHeaderTrailing]
/// 承載，經 `lib/app/shell.dart` 接線至 `SplitRow.header` 右格（僅
/// `AppDestination.domain` 一行條件式 trailing，其餘五個目的地不受影響）。
/// 降級型別表旗標（[DomainReady.isDegraded]）的觸發入口
/// `action-domain-degraded-view` 已接線（`0.1.0-W2-011`，見
/// [_SchemaUnconsumableView]）；常駐徽章 `badge-domain-degraded-schema`
/// 的寫入端已接線（`0.1.0-W2-014`）——觸發時同步寫入
/// `app/degraded_schema.dart` 的 `degradedSchemaProvider` /
/// `degradedSchemaVersionsProvider`，由 `components.AppShell` 常駐渲染。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/attention_level.dart';
import '../../app/domain_view_loader.dart';
import '../../app/router.dart';
import '../../app/selected_uc.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/external_opener.dart';
import '../../workspace/open_path_resolver.dart';
import '../../workspace/workspace_types.dart';
import '../../workspace/current_workspace_provider.dart';
import '../project_switcher/project_switcher_providers.dart';
import 'domain_view_providers.dart';
import 'domain_view_schema_version.dart';
import 'domain_view_state.dart';

const String _tag = 'DomainViewScreen';

/// Domain 視圖畫面。
class DomainViewScreen extends ConsumerWidget {
  const DomainViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(domainViewStateProvider);
    return switch (state) {
      DomainUnset() => const _UnsetView(),
      DomainLoading() => _LoadingView(state: state),
      DomainReady() => _readyBody(state),
      DomainEmpty() => _EmptyView(state: state),
      DomainNotFramework() => const _NotFrameworkView(),
      DomainSchemaUnconsumable() => _SchemaUnconsumableView(state: state),
      DomainSchemaIncompatible() => _SchemaIncompatibleView(state: state),
      DomainLoadFailed() => const _LoadFailedView(),
    };
  }
}

/// 載入失敗：`BlockedState.plain`（SPEC-001 v1.49 §1）。重新載入回載入中，
/// 同資料夾、同模式（降級旗標不動）。
class _LoadFailedView extends ConsumerWidget {
  const _LoadFailedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return BlockedState.plain(
      message: l10n.domainLoadFailedMessage,
      onSwitchProject: () =>
          ref.read(switcherOpenProvider.notifier).state = true,
      onReload: () =>
          unawaited(ref.read(domainViewLoaderProvider.notifier).reload()),
      testKey: const Key('state-domain-load-failed'),
    );
  }
}

/// 未選專案：`EmptyState.page`。
class _UnsetView extends ConsumerWidget {
  const _UnsetView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // SPEC-001 v1.24 §1：還原失敗降級時常駐顯示原因，取代權限說明。
    final workspace = ref.watch(currentWorkspaceStateProvider);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.chooseWorkspaceFolder,
      explanation: workspace is WorkspaceUnavailable
          ? l10n.workspaceUnavailable(workspace.reason)
          : l10n.folderAccessRationale,
      testKey: const Key('state-domain-unset'),
      actions: [
        AppButton(
          label: l10n.chooseWorkspaceFolder,
          onPressed: () => ref.read(domainViewStateProvider.notifier).state =
              const DomainLoading(),
          testKey: const Key('action-domain-choose-folder'),
        ),
      ],
    );
  }
}

/// 載入中：`LoadingState.skeleton`（版位 `matrix`）。
class _LoadingView extends ConsumerWidget {
  const _LoadingView({required this.state});

  final DomainLoading state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return LoadingState.skeleton(
      message: l10n.domainLoading,
      skeletonLayout: SkeletonLayout.matrix,
      isCancelling: state.isCancelling,
      // 取消由載入編排擁有：作廢進行中的輪次與結果，再寫回未選專案。
      onCancel: () =>
          ref.read(domainViewLoaderProvider.notifier).cancelLoading(),
      testKey: const Key('state-domain-loading'),
      cancelKey: const Key('action-domain-cancel-load'),
    );
  }
}

/// 空圖：`EmptyState.page`。
class _EmptyView extends ConsumerWidget {
  const _EmptyView({required this.state});

  final DomainEmpty state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final actions = <AppButton>[
      // primary 至多 1 個且須置於首位（SPEC-004 §4.34 slot 契約）。
      AppButton(
        label: l10n.gotoGapsReportAction,
        onPressed: () =>
            navigateTo(ref.read, AppDestination.gaps, NavIntent.jump),
        testKey: const Key('action-domain-goto-gaps'),
      ),
      if (state.docsDirExists)
        AppButton(
          label: l10n.openDocsFolderAction,
          variant: AppButtonVariant.secondary,
          onPressed: () => _openDocsFolder(context, ref),
          testKey: const Key('action-domain-open-docs'),
        ),
    ];
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.emptyGraphMessage,
      testKey: const Key('state-domain-empty'),
      actions: actions,
    );
  }

  Future<void> _openDocsFolder(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceStateProvider);
    if (workspace is! WorkspaceReady) {
      developer.log(
        '未開啟 docs 目錄：workspace 非 WorkspaceReady（${workspace.runtimeType}）', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return;
    }
    final path = '${workspace.path}/docs'; // i18n-exempt: 路徑組成
    final result = await ref.read(externalOpenerProvider).open(path);
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

/// 不是框架專案：`BlockedState.plain`。
class _NotFrameworkView extends ConsumerWidget {
  const _NotFrameworkView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return BlockedState.plain(
      message: l10n.notFrameworkProjectMessage,
      explanation: l10n.notFrameworkProjectExplanation,
      onSwitchProject: () =>
          ref.read(switcherOpenProvider.notifier).state = true,
      testKey: const Key('state-domain-not-framework'),
    );
  }
}

/// 無可消費的型別表：`BlockedState.plain`（版本值 slot）。
///
/// `.claude/VERSION` 值（[state.version]）不高於內建型別表資產版本
/// （[builtinSchemaVersionProvider]，讀自實際內嵌資產，見
/// `domain_view_schema_version.dart` 檔頭；0.1 資產化本身涵蓋版本閘門
/// 判斷所需欄位，完整型別表內嵌副本不在本票範圍——畫面全域仍為 fixture
/// 驅動，見檔頭與 [domainViewStateProvider]）時傳入 `onDegradedView`，
/// 渲染「以 App 內建型別表檢視」動作（`action-domain-degraded-view`，
/// `0.1.0-W1-035`／`0.1.0-W2-011`）；按下後轉為 [DomainReady]（矩陣模式）
/// 並設 `isDegraded` 為真。高於時不傳入，退出路徑只剩切換專案
/// （SPEC-001 §1）。資產仍在載入或載入失敗時安全預設為不提供降級出口
/// （呼應 [isHigherThanBuiltinSchemaVersion] 的「不確定時不自動降級」）。
class _SchemaUnconsumableView extends ConsumerWidget {
  const _SchemaUnconsumableView({required this.state});

  final DomainSchemaUnconsumable state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final builtinVersionAsync = ref.watch(builtinSchemaVersionProvider);
    String? builtinVersion;
    final canDegrade = builtinVersionAsync.maybeWhen(
      data: (version) {
        builtinVersion = version;
        return !isHigherThanBuiltinSchemaVersion(state.version, version);
      },
      orElse: () => false,
    );
    return BlockedState.plain(
      message: l10n.schemaUnconsumableMessage(state.version),
      explanation: canDegrade
          ? l10n.schemaUnconsumableDegradedExplanation(builtinVersion ?? '')
          : null,
      version: state.version,
      onSwitchProject: () =>
          ref.read(switcherOpenProvider.notifier).state = true,
      onDegradedView: canDegrade
          ? () {
              // 降級旗標、徽章版本文字（`badge-domain-degraded-schema`，
              // SPEC-001 §1／SPEC-004 §4.27）、輪次失效與重掃由
              // lib/app 的降級動作承擔（0.5.0-W1-114.14）。
              unawaited(
                ref
                    .read(domainViewLoaderProvider.notifier)
                    .enterDegradedView(
                      builtinVersion: builtinVersion ?? '',
                      projectVersion: state.version,
                    ),
              );
            }
          : null,
      testKey: const Key('state-domain-schema-unconsumable'),
    );
  }
}

/// schema 不相容：`BlockedState.withDetail`。
class _SchemaIncompatibleView extends ConsumerWidget {
  const _SchemaIncompatibleView({required this.state});

  final DomainSchemaIncompatible state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projectVersion = state.projectVersion;
    return BlockedState.withDetail(
      message: projectVersion == null
          ? l10n.schemaVersionUnreadableMessage
          : l10n.schemaIncompatibleMessage(state.appVersion, projectVersion),
      appVersion: state.appVersion,
      projectVersion: projectVersion,
      onSwitchProject: () =>
          ref.read(switcherOpenProvider.notifier).state = true,
      isDetailExpanded: state.isDetailExpanded,
      onToggleDetail: () => ref.read(domainViewStateProvider.notifier).state =
          DomainSchemaIncompatible(
            appVersion: state.appVersion,
            projectVersion: state.projectVersion,
            isDetailExpanded: !state.isDetailExpanded,
          ),
      testKey: const Key('state-domain-schema-incompatible'),
    );
  }
}

/// 正常 · 矩陣／已選格／正常 · 泳道／泳道 · 尚未選定 UC／泳道 ·
/// flow 未結構化五列的共用渲染入口：純依 [DomainReady.mode] 分派子件，
/// 不在頁面層另組合排版容器（模式切換由 [DomainHeaderTrailing] 於
/// `SplitRow.header` 右格承載，見檔頭說明）。
Widget _readyBody(DomainReady state) => state.mode == DomainMode.matrix
    ? _MatrixBody(state: state)
    : _SwimlaneBody(state: state);

/// `SplitRow.header` 右格內容（`lib/app/shell.dart` 接線，見檔頭說明）：
/// 僅 [DomainReady]（矩陣／泳道模式共用的五列）渲染 `SegmentedControl`，
/// 其餘六列（未選專案／載入中／空圖／三個阻擋狀態）不渲染頁首模式切換
/// （SPEC-004 §3.6 §1 表下段落）。
class DomainHeaderTrailing extends ConsumerWidget {
  const DomainHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(domainViewStateProvider);
    if (state is! DomainReady) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return SegmentedControl(
      segments: [
        SegmentItem(
          label: l10n.modeMatrixLabel,
          semanticLabel: l10n.domainSwitchToMatrixAction,
          testKey: const Key('mode-domain-matrix'),
        ),
        SegmentItem(
          label: l10n.modeSwimlaneLabel,
          semanticLabel: l10n.domainSwitchToSwimlaneAction,
          testKey: const Key('mode-domain-swimlane'),
        ),
      ],
      selectedIndex: state.mode == DomainMode.matrix ? 0 : 1,
      onChanged: (index) =>
          ref.read(domainViewStateProvider.notifier).state = state.copyWith(
            mode: index == 0 ? DomainMode.matrix : DomainMode.swimlane,
          ),
    );
  }
}

/// 正常 · 矩陣（含已選格疊加）。
class _MatrixBody extends ConsumerWidget {
  const _MatrixBody({required this.state});

  final DomainReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final matrix = state.matrix;
    final rows = matrix?.rows ?? const <DomainRow>[];

    void onSelectDomain(String domainId) {
      final current = state.selectedCell;
      final keepCell = current != null && current.$1 == domainId;
      ref.read(domainViewStateProvider.notifier).state = state.copyWith(
        selectedDomainId: () => domainId,
        selectedCell: () => keepCell ? current : null,
      );
    }

    void onClearSelection() {
      ref.read(domainViewStateProvider.notifier).state = state.copyWith(
        selectedCell: () => null,
      );
    }

    void onSelectCell(String domainId, String ucId) {
      ref.read(selectedUcProvider.notifier).state = ucId;
      ref.read(domainViewStateProvider.notifier).state = state.copyWith(
        selectedDomainId: () => domainId,
        selectedCell: () => (domainId, ucId),
      );
    }

    final matrixRows = [
      for (final row in rows)
        MatrixRow(
          domainId: row.domainId,
          domainName: row.domainName,
          subtotal: row.subtotal,
          cells: [
            for (final cell in row.cells)
              MatrixCell(
                relation: _toRelation(cell.relation),
                isSelected: state.selectedCell == (cell.domainId, cell.ucId),
                isRowSelected: state.selectedDomainId == row.domainId,
                semanticLabel: l10n.matrixCellA11yLabel(
                  row.domainName,
                  cell.ucId,
                  _relationLabel(l10n, cell.relation),
                ),
                onTap: () => onSelectCell(cell.domainId, cell.ucId),
                testKey: Key('cell-domain-${cell.domainId}-${cell.ucId}'),
              ),
          ],
        ),
    ];

    final columnHeaders = [
      for (final uc in matrix?.columns ?? const <DomainUc>[])
        TableColumnHeader.twoLine(label: uc.id, secondLine: uc.title),
    ];

    final main = Panel(
      fill: MatrixGrid(
        columnHeaders: columnHeaders,
        rows: matrixRows,
        selectedDomainId: state.selectedDomainId,
        selectedCell: state.selectedCell,
        onSelectDomain: onSelectDomain,
        onClearSelection: onClearSelection,
        scrollKey: const Key('scroll-domain-matrix'),
      ),
      trailing: [_legendBadgeRow(l10n)],
    );

    final selectedCell = state.selectedCell;
    final selected = selectedCell == null
        ? null
        : _findCell(rows, selectedCell.$1, selectedCell.$2);
    final detail = selected == null
        ? Panel.scrollable(
            key: const ValueKey('panel-domain-cell-detail-empty-container'),
            scrollKey: const Key('scroll-domain-cell-detail'),
            children: [
              EmptyState(
                variant: EmptyStateVariant.section,
                message: l10n.cellDetailPrompt,
                testKey: const Key('panel-domain-cell-detail-empty'),
              ),
            ],
          )
        : _CellDetailPanel(
            key: ValueKey(
              'panel-domain-cell-detail-${selected.$2.domainId}-'
              '${selected.$2.ucId}',
            ),
            row: selected.$1,
            cell: selected.$2,
          );

    return TwoColumnLayout(
      key: const Key('state-domain-matrix'),
      main: main,
      detail: detail,
    );
  }
}

/// 已選格右欄詳情卡內容（SPEC-003 §3.1〈格詳情卡的內容契約〉）。
class _CellDetailPanel extends ConsumerWidget {
  const _CellDetailPanel({super.key, required this.row, required this.cell});

  final DomainRow row;
  final DomainCell cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ucId = cell.ucId;
    final ready = ref.read(domainViewStateProvider) as DomainReady;

    return Panel.scrollable(
      key: const Key('panel-domain-cell-detail'),
      scrollKey: const Key('scroll-domain-cell-detail'),
      children: [
        SplitRow.header(
          compactHeader: true,
          leading: AppText(
            '${row.domainName} × $ucId', // i18n-exempt: 資料值組字，非 UI 文案
            variant: AppTextVariant.subtitle,
          ),
          trailing: AppButton(
            label: l10n.cellDetailCloseAction,
            variant: AppButtonVariant.text,
            onPressed: () => ref.read(domainViewStateProvider.notifier).state =
                ready.copyWith(selectedCell: () => null),
            testKey: const Key('action-domain-cell-clear'),
          ),
        ),
        AppText(
          _relationLabel(l10n, cell.relation),
          variant: AppTextVariant.caption,
        ),
        if (cell.relation == DomainRelation.none)
          AppText(l10n.cellDetailNotInvolved, variant: AppTextVariant.body)
        else if (cell.explanation != null)
          AppText(cell.explanation!, variant: AppTextVariant.body),
        for (var i = 0; i < cell.steps.length; i++)
          ListRow.numbered(
            leading: StepNumber(number: i + 1),
            primary: AppText(cell.steps[i], variant: AppTextVariant.body),
          ),
        if (cell.events.isNotEmpty)
          BadgeRow(
            children: [
              for (final event in cell.events)
                Badge.event(
                  label:
                      '${event.$2 ? 'emits' : 'consumes'} ${event.$1}', // i18n-exempt: 事件標籤前綴為契約用詞，非本地化文案
                ),
            ],
          ),
        // 依賴路徑僅間接依賴格渲染（SPEC-004 §3.6；SPEC-001 §1）。
        if (cell.relation == DomainRelation.indirect)
          for (final path in cell.dependencyPaths)
            AppText(path, variant: AppTextVariant.body),
        ButtonRow(
          alignment: ButtonRowAlignment.end,
          children: [
            AppButton(
              label: l10n.cellDetailViewInSwimlaneAction,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                ref.read(selectedUcProvider.notifier).state = ucId;
                final focus = _jumpFocus(ref, cell);
                ref.read(domainViewStateProvider.notifier).state = ready
                    .copyWith(
                      mode: DomainMode.swimlane,
                      selectedDomainId: () => focus.domainId,
                      swimlaneFocus: () => focus,
                    );
              },
              testKey: const Key('action-domain-cell-goto-swimlane'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 需求：[SPEC-001 §1 「在泳道中檢視」跳轉目標] 間接依賴格取依賴路徑第一行的
/// 來源 X，以 X 呼叫 Layout 查詢並採用其回傳節點；直接貫穿格（或查無節點、
/// 查無對應列）定位到該格 domain 所在列。
SwimlaneFocus _jumpFocus(WidgetRef ref, DomainCell cell) {
  final direct = SwimlaneFocus(domainId: cell.domainId);
  final source = cell.indirectSource;
  if (cell.relation != DomainRelation.indirect || source == null) {
    return direct;
  }
  final node = ref.read(firstNodeInLaneQueryProvider)(cell.ucId, source);
  final matrix = (ref.read(domainViewStateProvider) as DomainReady).matrix;
  final row = matrix?.rows.where((r) => r.domainName == source).firstOrNull;
  if (node == null || row == null) return direct;
  return SwimlaneFocus(domainId: row.domainId, column: node.column);
}

/// 正常 · 泳道／泳道 · 尚未選定 UC／泳道 · flow 未結構化三列的計算入口
/// （選定 UC 來自 App 層共用值 `selectedUcProvider`）。
class _SwimlaneBody extends ConsumerWidget {
  const _SwimlaneBody({required this.state});

  final DomainReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedUcId = ref.watch(selectedUcProvider);

    void onSelectDomain(String domainId) {
      ref.read(domainViewStateProvider.notifier).state = state.copyWith(
        selectedDomainId: () => domainId,
      );
    }

    final matrix = state.matrix;
    final swimlane = ref.watch(domainSwimlaneProvider);

    // 未選定 UC，或選定 UC 尚無投影（輪次未完成）：列結構同正常 · 泳道、
    // 不含步驟節點（SPEC-001 §1「泳道 · 尚未選定 UC」）。
    if (selectedUcId == null || swimlane == null) {
      final lanes = _emptyLanes(matrix);
      return Panel(
        leading: [
          EmptyState(
            variant: EmptyStateVariant.section,
            message: l10n.swimlaneUcUnsetPrompt,
            testKey: const Key('state-domain-swimlane-uc-unset'),
          ),
        ],
        fill: SwimlaneGrid(
          lanes: lanes,
          laneHighlight: _highlightName(matrix, lanes, state.selectedDomainId),
          onSelectDomain: onSelectDomain,
          scrollKey: const Key('scroll-domain-swimlane'),
          dragKey: const Key('drag-domain-swimlane'),
        ),
      );
    }

    final ucTitle = _ucTitleOf(matrix, selectedUcId);
    final panelTitle = ucTitle.isEmpty
        ? selectedUcId
        : l10n.swimlanePanelTitle(selectedUcId, ucTitle);

    if (swimlane is! DomainSwimlane) {
      return Panel(
        leading: [AppText(panelTitle, variant: AppTextVariant.subtitle)],
        fill: EmptyState(
          variant: EmptyStateVariant.section,
          message:
              (swimlane is DomainSwimlaneUnstructured &&
                  swimlane.isFlowParseFailed)
              ? l10n.flowParseFailedMessage
              : l10n.flowUnstructuredMessage,
          testKey: const Key('state-domain-swimlane-unstructured'),
          actions: [
            AppButton(
              label: l10n.openSourceFileAction,
              variant: AppButtonVariant.secondary,
              onPressed: () => _openSource(context, ref, selectedUcId),
              testKey: const Key('action-domain-open-source'),
            ),
          ],
        ),
      );
    }

    final lanes = [
      for (final lane in swimlane.lanes)
        _toSwimlaneLane(lane, state.selectedDomainId),
    ];
    return Panel(
      key: const Key('state-domain-swimlane'),
      leading: [
        AppText(panelTitle, variant: AppTextVariant.subtitle),
        if (swimlane.hasFlowParseFailure)
          AppText(
            l10n.swimlaneFlowParseFailedHint,
            variant: AppTextVariant.caption,
          ),
      ],
      fill: SwimlaneGrid(
        lanes: lanes,
        edges: [for (final edge in swimlane.edges) _toSwimlaneEdge(edge)],
        laneHighlight: _highlightName(matrix, lanes, state.selectedDomainId),
        onSelectDomain: onSelectDomain,
        scrollKey: const Key('scroll-domain-swimlane'),
        dragKey: const Key('drag-domain-swimlane'),
      ),
      trailing: [
        BadgeRow(
          variant: BadgeRowVariant.legend,
          children: [
            Badge.legend(symbol: '■', label: l10n.laneNodeActive),
            Badge.legend(symbol: '□', label: l10n.laneNodeInactive),
          ],
        ),
      ],
    );
  }

  /// 開啟選定 UC 的原始檔（SPEC-003 §3.1「泳道開啟原始檔」；契約同
  /// `gap_report_screen.dart._openExternally`，此處簡化為單一結局分支：
  /// 假資料無真實檔案路徑，0.1 恆走 `notFound`／`failed` 分支——路徑存在
  /// 性檢查與行程呼叫仍走真實 `dart:io`，只是 fixture 路徑本身不對應
  /// 磁碟上的檔案，故此路徑的「opened」分支在 0.1 假資料下不可達，
  /// 待真實資料整合後才會走到。
  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    String ucId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final path = resolveOpenPath(
      ref.read(currentWorkspaceStateProvider),
      'docs/usecases/$ucId.md', // i18n-exempt: fixture 路徑字面,
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

/// 依 domain id 與 UC id 取矩陣中的列與格；任一不在矩陣內時為 `null`。
(DomainRow, DomainCell)? _findCell(
  List<DomainRow> rows,
  String domainId,
  String ucId,
) {
  for (final row in rows) {
    if (row.domainId != domainId) continue;
    for (final cell in row.cells) {
      if (cell.ucId == ucId) return (row, cell);
    }
  }
  return null;
}

/// UC 標題取自矩陣欄首；欄不在矩陣內時為空字串（面板只顯示 UC id，
/// SPEC-001 §1〈顯示字面的退路〉）。
String _ucTitleOf(DomainMatrix? matrix, String ucId) {
  for (final uc in matrix?.columns ?? const <DomainUc>[]) {
    if (uc.id == ucId) return uc.title;
  }
  return '';
}

/// 未選定 UC 的列結構：頂端「畫面」列 + 矩陣各 domain 列，皆無節點。
List<SwimlaneLane> _emptyLanes(DomainMatrix? matrix) => [
  const SwimlaneLane(name: '', kind: SwimlaneLaneKind.screen, nodes: []),
  for (final row in matrix?.rows ?? const <DomainRow>[])
    SwimlaneLane(name: row.domainName, nodes: const [], domainId: row.domainId),
];

/// 選中 domain 的列首字面：先查矩陣列，再查泳道列；查無為 `null`。
String? _highlightName(
  DomainMatrix? matrix,
  List<SwimlaneLane> lanes,
  String? domainId,
) {
  if (domainId == null) return null;
  for (final row in matrix?.rows ?? const <DomainRow>[]) {
    if (row.domainId == domainId) return row.domainName;
  }
  for (final lane in lanes) {
    if (lane.domainId == domainId) return lane.name;
  }
  return null;
}

/// 投影列轉元件列：domain 列列首為 `domainName` 原值；畫面列與未定位列
/// 不帶名稱與 domainId，列首由元件走 i18n。
SwimlaneLane _toSwimlaneLane(DomainLane lane, String? selectedDomainId) =>
    SwimlaneLane(
      name: lane.domainName ?? '',
      kind: switch (lane.kind) {
        DomainLaneKind.screen => SwimlaneLaneKind.screen,
        DomainLaneKind.domain => SwimlaneLaneKind.domain,
        DomainLaneKind.unplaced => SwimlaneLaneKind.unplaced,
      },
      domainId: lane.domainId,
      nodes: [
        for (final node in lane.nodes)
          (
            SwimlaneNode(
              label: node.stepLabel,
              isActive:
                  selectedDomainId != null &&
                  node.stepTraverses.contains(selectedDomainId),
            ),
            node.column,
          ),
      ],
    );

SwimlaneEdge _toSwimlaneEdge(DomainLaneEdge edge) => SwimlaneEdge(
  fromColumn: edge.fromColumn,
  toColumn: edge.toColumn,
  shape: switch (edge.shape) {
    DomainLaneEdgeShape.straight => SwimlaneEdgeShape.straight,
    DomainLaneEdgeShape.arc => SwimlaneEdgeShape.arc,
  },
);

Relation _toRelation(DomainRelation relation) => switch (relation) {
  DomainRelation.direct => Relation.direct,
  DomainRelation.indirect => Relation.indirect,
  DomainRelation.none => Relation.none,
};

String _relationLabel(AppLocalizations l10n, DomainRelation relation) =>
    switch (relation) {
      DomainRelation.direct => l10n.legendDirect,
      DomainRelation.indirect => l10n.legendIndirect,
      DomainRelation.none => l10n.legendNone,
    };

BadgeRow _legendBadgeRow(AppLocalizations l10n) => BadgeRow(
  variant: BadgeRowVariant.legend,
  children: [
    Badge.legend(symbol: '●', label: l10n.legendDirect),
    Badge.legend(symbol: '○', label: l10n.legendIndirect),
    Badge.legend(symbol: '·', label: l10n.legendNone),
  ],
);
