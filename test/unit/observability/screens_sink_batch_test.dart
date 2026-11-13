// 1.0.0-W3-553.2.3.4.3：screens 的日誌改經 LogSink。
// 斷言事件碼、等級、error_source 與負載，不斷言文案（SPEC-010 FR-02、FR-04）。
// 每組皆含正向對照（不該記的輸入不產生事件）。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_log_event.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_projection.dart';
import 'package:graph_project_docs_manager/screens/gap_report/watch_round_notification_adapter.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_log_event.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart'
    show readRefreshOutcome;
import 'package:graph_project_docs_manager/services/scan_notifier.dart';

class _Rec<E extends Enum> {
  final entries =
      <({E event, LogLevel level, ErrorSource? source, Object? error})>[];

  void call(
    E event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) => entries.add((event: event, level: level, source: source, error: error));
}

class _FakeNotifier implements ScanNotifier {
  _FakeNotifier(this.delivery);
  final ScanNotificationDelivery delivery;

  @override
  Future<void> withdraw() async {}

  @override
  Future<ScanNotificationDelivery> show(ScanCompleteNotification n) async =>
      delivery;

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      NotificationAuthorization.granted;

  @override
  Future<NotificationAuthorization> requestAuthorization() async =>
      NotificationAuthorization.granted;

  @override
  Stream<void> get activated => const Stream<void>.empty();
}

void main() {
  group('gap_report 投影：查無節點為 warning／internal', () {
    test('查無節點：記 nodeNotFound 後 assert；有節點空輸入不記', () {
      final rec = _Rec<GapReportLogEvent>();
      expect(
        () => projectGapReport(
          parseFailures: const [
            FlowBlockMalformedGap(path: 'docs/usecases/UC-01.md', reason: 'x'),
          ],
          graphDefects: const [],
          nodes: const [],
          nonDomainPathsKey: 'k',
          logSink: rec.call,
        ),
        throwsAssertionError,
      );
      expect(rec.entries.single.event, GapReportLogEvent.nodeNotFound);
      expect(rec.entries.single.level, LogLevel.warning);
      expect(rec.entries.single.source, ErrorSource.internal);

      final quiet = _Rec<GapReportLogEvent>();
      projectGapReport(
        parseFailures: const [],
        graphDefects: const [],
        nodes: const [],
        nonDomainPathsKey: 'k',
        logSink: quiet.call,
      );
      expect(quiet.entries, isEmpty);
    });
  });

  group('node_detail 重新整理讀檔失敗：warning／platform_io', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('sink_batch_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('讀取拋 FileSystemException：記 refreshReadFailed；成功讀取不記', () {
      final file = File('${dir.path}/a.md')
        ..writeAsStringSync('---\nid: X\n---\n');
      final rec = _Rec<NodeDetailLogEvent>();
      readRefreshOutcome(
        file.path,
        readBytes: (_) =>
            throw FileSystemException('read', file.path, OSError('', 13)),
        logSink: rec.call,
      );
      expect(rec.entries.single.event, NodeDetailLogEvent.refreshReadFailed);
      expect(rec.entries.single.level, LogLevel.warning);
      expect(rec.entries.single.source, ErrorSource.platformIo);
      expect(rec.entries.single.error, isA<FileSystemException>());

      final quiet = _Rec<NodeDetailLogEvent>();
      readRefreshOutcome(
        file.path,
        readBytes: (f) => Uint8List.fromList(f.readAsBytesSync()),
        logSink: quiet.call,
      );
      expect(quiet.entries, isEmpty);
    });
  });

  group('監看輪次通知發送失敗：warning／platform_io', () {
    test('failed：記 watchNotificationDeliveryFailed；delivered 不記', () async {
      final rec = _Rec<GapReportLogEvent>();
      await ScanNotifierWatchPort(
        _FakeNotifier(ScanNotificationDelivery.failed),
        logSink: rec.call,
      ).sendWatchNotification(2);
      expect(
        rec.entries.single.event,
        GapReportLogEvent.watchNotificationDeliveryFailed,
      );
      expect(rec.entries.single.level, LogLevel.warning);
      expect(rec.entries.single.source, ErrorSource.platformIo);

      final quiet = _Rec<GapReportLogEvent>();
      await ScanNotifierWatchPort(
        _FakeNotifier(ScanNotificationDelivery.delivered),
        logSink: quiet.call,
      ).sendWatchNotification(2);
      expect(quiet.entries, isEmpty);
    });
  });
}
