// SPEC-005 §三 G-1／G-2：預設 adapter 自帶日誌。
// 走公開的 WorkspaceRepository，不注入 port，使真實預設 adapter 被執行；
// 只斷言 event（WorkspaceLogEvent 契約），不斷言 message。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';

class _Events {
  final List<WorkspaceLogEvent> events = [];
  void call(
    String message, {
    required WorkspaceLogEvent event,
    int? level,
    Object? error,
  }) => events.add(event);
}

void main() {
  group('G-1 probe adapter 日誌', () {
    test('exists 為 false 時記 adapterProbeExistsResult', () async {
      final log = _Events();
      final repo = WorkspaceRepository(logSink: log.call);
      await repo.probeRecentProject('/no/such/dir/for/test');
      expect(log.events, contains(WorkspaceLogEvent.adapterProbeExistsResult));
    });

    test('readFirstEntry 可讀時記 adapterProbeReadFirstEntryResult', () async {
      final dir = await Directory.systemTemp.createTemp('adapter_log_');
      addTearDown(() => dir.delete(recursive: true));
      File('${dir.path}/a.txt').writeAsStringSync('x');
      final log = _Events();
      final repo = WorkspaceRepository(logSink: log.call);
      await repo.probeRecentProject(dir.path);
      expect(
        log.events,
        contains(WorkspaceLogEvent.adapterProbeReadFirstEntryResult),
      );
    });
  });

  group('G-2 Preferences adapter 日誌', () {
    test('open／read／write 各記一筆 adapter 事件', () async {
      SharedPreferences.setMockInitialValues({});
      final log = _Events();
      final repo = WorkspaceRepository(logSink: log.call);
      await repo.addRecentProject('/ws');
      await repo.restore();
      expect(
        log.events,
        containsAll([
          WorkspaceLogEvent.adapterPreferencesOpenResult,
          WorkspaceLogEvent.adapterPreferencesReadResult,
          WorkspaceLogEvent.adapterPreferencesWriteResult,
        ]),
      );
    });
  });
}
