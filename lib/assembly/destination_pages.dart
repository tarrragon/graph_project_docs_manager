/// 導覽項目到畫面 widget 的組裝（組裝根，位於 screens 之上）。
///
/// 自 `app/router.dart` 移出：router 只保留導覽狀態，避免與畫面檔循環 import。
library;

import 'package:flutter/widgets.dart';

import '../app/router.dart';
import '../screens/domain_view/domain_view_screen.dart';
import '../screens/trace/trace_screen.dart';
import '../screens/gap_report/gap_report_screen.dart';
import '../screens/node_detail/node_detail_screen.dart';
import '../screens/ticket_list/ticket_list_screen.dart';
import '../screens/uc_flow/uc_flow_screen.dart';

/// 依 [destination] 產生對應的畫面內容（窮舉，六項皆有畫面）。
Widget buildDestinationPage(BuildContext context, AppDestination destination) {
  final key = destination.pageKey;
  return switch (destination) {
    AppDestination.domain => DomainViewScreen(key: key),
    AppDestination.traceability => TraceabilityScreen(key: key),
    AppDestination.gaps => GapReportScreen(key: key),
    AppDestination.tickets => TicketListScreen(key: key),
    AppDestination.nodeDetail => NodeDetailScreen(key: key),
    AppDestination.ucFlow => UcFlowScreen(key: key),
  };
}
