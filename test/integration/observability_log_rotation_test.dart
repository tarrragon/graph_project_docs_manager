import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/observability/log_file_port.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/observability/log_writer.dart';

enum _It1Event { rotated }

const int _threshold = 4 * 1024;
const int _padding = 1000;

void _write(LogWriter w, int n) => w.log(
  'graph',
  _It1Event.rotated,
  LogFields({
    'seq': LogValue.integer(n),
    // 填充使單筆約 1 KiB；以 enum 無法膨脹，改用多個欄位。
    for (var i = 0; i < _padding ~/ 20; i++) 'f$i': LogValue.integer(n),
  }),
);

void main() {
  late Directory dir;
  late LogWriter writer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('obs_it1_');
    writer = LogWriter(
      port: IoLogFilePort(dir.path),
      devLog: (m, {required name, required level, error, stackTrace}) {},
      rotateBytes: _threshold,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('IT-1-1 超過門檻後輪替，現行檔每行可解碼', () async {
    for (var i = 0; i < 12; i++) {
      _write(writer, i);
    }
    await writer.flush();
    expect(names(), containsAll(['app.jsonl', 'app.1.jsonl']));
    for (final l in File('${dir.path}/app.jsonl').readAsLinesSync()) {
      expect(jsonDecode(l), isA<Map<String, dynamic>>());
    }
  });

  test('IT-1-2 輪替超過 5 次：恰為現行檔加 4 個歷史檔，最早記錄消失', () async {
    for (var i = 0; i < 60; i++) {
      _write(writer, i);
      await writer.flush();
    }
    expect(names(), [
      'app.1.jsonl',
      'app.2.jsonl',
      'app.3.jsonl',
      'app.4.jsonl',
      'app.jsonl',
    ]);
    final all = names()
        .map((n) => File('${dir.path}/$n').readAsStringSync())
        .join();
    expect(all, isNot(contains('"seq":0,')));
    expect(
      File('${dir.path}/app.jsonl').readAsStringSync(),
      contains('"seq":59,'),
    );
  });
}
