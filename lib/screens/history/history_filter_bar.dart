/// 變更記錄篩選列（SPEC-001 §10、SPEC-003 §3.9）：期間三段與包含 ticket 建檔。
///
/// 切換篩選只改兩個篩選 provider，由畫面重新呼叫查詢；不呼叫 notifier，
/// 因此不會啟動掃描。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/history_providers.dart';
import '../../components/components.dart';
import '../../history/query/history_query.dart';
import '../../l10n/app_localizations.dart';

/// 期間選項與其測試錨點後綴，順序即分段順序。
const List<(PeriodChoice, String)> _periodOptions = [
  (PeriodChoice.defaultPeriod, 'default'),
  (PeriodChoice.last30Days, 'recent30'),
  (PeriodChoice.allHistory, 'all'),
];

/// 篩選列。
class HistoryFilterBar extends ConsumerWidget {
  const HistoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final choice = ref.watch(historyPeriodChoiceProvider);
    return Toolbar.history(
      testKey: const Key('toolbar-history-filter'),
      period: SegmentedControl(
        segments: [
          for (final (option, anchor) in _periodOptions)
            _segment(l10n, option, anchor),
        ],
        selectedIndex: _periodOptions.indexWhere((o) => o.$1 == choice),
        onChanged: (i) => ref.read(historyPeriodChoiceProvider.notifier).state =
            _periodOptions[i].$1,
      ),
      toggle: AppCheckbox(
        label: l10n.historyIncludeTicketCreatedLabel,
        value: ref.watch(historyIncludeTicketCreationProvider),
        onChanged: (v) =>
            ref.read(historyIncludeTicketCreationProvider.notifier).state = v,
        testKey: const Key('action-history-include-ticket-created'),
      ),
    );
  }

  SegmentItem _segment(
    AppLocalizations l10n,
    PeriodChoice option,
    String anchor,
  ) {
    final label = switch (option) {
      PeriodChoice.defaultPeriod => l10n.historyPeriodDefaultLabel,
      PeriodChoice.last30Days => l10n.historyPeriodRecent30Label,
      PeriodChoice.allHistory => l10n.historyPeriodAllLabel,
    };
    return SegmentItem(
      label: label,
      semanticLabel: l10n.historyPeriodSelectA11yHint(label),
      testKey: Key('option-history-period-$anchor'),
    );
  }
}
