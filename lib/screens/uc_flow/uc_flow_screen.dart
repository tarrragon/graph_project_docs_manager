/// UC Flow 視圖（SPEC-001 §2；SPEC-003 §3.2；SPEC-004 §3.6）。
///
/// 五個狀態列依 [UcFlowState] 切換，內容由 [ucFlowStateProvider] 供給
/// （假資料驅動，見 [UcFlowFixtures]，本票決策：只交狀態渲染與退出
/// 路徑，不接真實資料）。
///
/// **元件庫缺件（本票 NeedsContext，回報 PM 開票，不就地自製）**：
/// 〈UC 選擇入口〉（SPEC-004 §3.6，`尚未選定 UC`／`flow 未結構化`／
/// `正常` 三態共用）依賴 `ListRow.option` 變體；事件流小表（`正常` 態）
/// 依賴 `TableRow.eventFlow` 變體與 `AppDataTable.appendix` slot。三者
/// 皆為 SPEC-004 §3.6 已核定但 `lib/components/list_row.dart`／
/// `app_table_row.dart`／`app_data_table.dart` 尚未實作的缺件，見
/// SPEC-004 變更歷史 1.35。因此 [UcFlowUcUnset]／[UcFlowUnstructured]／
/// [UcFlowNormal] 三態無法依 §3.6 句型完整組成——本票僅渲染可組成的
/// 兩態（[UcFlowProjectUnready]／[UcFlowEmpty]），其餘三態渲染 [_BlockedView]
/// （沿用 `app/router.dart` `_DestinationPlaceholderPage` 既有的「未完成」
/// 慣例：只保留狀態 testKey，不冒充已完成的元件組合）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'uc_flow_providers.dart';
import 'uc_flow_state.dart';

/// UC Flow 視圖畫面。
class UcFlowScreen extends ConsumerWidget {
  const UcFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ucFlowStateProvider);
    return switch (state) {
      UcFlowProjectUnready() => const _ProjectUnreadyView(),
      UcFlowEmpty() => const _EmptyView(),
      UcFlowUcUnset() => const _BlockedView(
        testKey: Key('state-ucFlow-uc-unset'),
      ),
      UcFlowUnstructured() => const _BlockedView(
        testKey: Key('state-ucFlow-unstructured'),
      ),
      UcFlowNormal() => const _BlockedView(
        testKey: Key('state-ucFlow-normal'),
      ),
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

/// 因元件庫缺件而暫不渲染的狀態（見檔頭說明）：只保留狀態 testKey，
/// 不組合任何 SPEC-004 §3.6 元件——避免以現有元件湊出視覺上相似但
/// 不符契約的替代品（`不就地自製`）。
class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.testKey});

  final Key testKey;

  @override
  Widget build(BuildContext context) => SizedBox.shrink(key: testKey);
}
