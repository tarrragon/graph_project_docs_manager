import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

/// 0.6.0-W1-193.3：把 traceAction 的 timeline 轉成摘要寫入 `build/`。
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final key in const ['ticket_list_scroll', 'ticket_list_sort']) {
      final timeline = data[key];
      if (timeline == null) continue;
      final summary = TimelineSummary.summarize(
        Timeline.fromJson(timeline as Map<String, dynamic>),
      );
      await summary.writeTimelineToFile(
        key,
        destinationDirectory: 'build',
        pretty: true,
        includeSummary: true,
      );
    }
  },
);
