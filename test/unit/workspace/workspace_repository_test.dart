// Port 回饋契約（clean-architecture-implementation-methodology.md）針對
// WorkspaceRepository 三個 driven port 呼叫點（file_selector／
// SharedPreferences／dart:io 資料夾探測）的單元測試。依 0.1.0-W3-121
// Solution Phase 2 §2.1-2.4 的 GWT 群組與裝置紀律撰寫。
//
// 裝置分兩組獨立類別（Phase 2 §2.2 紀律 1，禁止合併為可配置萬用 fake）：
// - 記錄器（*Recorder）：只累積 (方法名, 參數)，回中性值，斷言只針對記錄
//   內容與日誌，不對記錄器的回傳做結局斷言。
// - 行為替身（_Fake*）：另一組類別，只用於受理／結果測試，可配置結局。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// 永不回應的探測替身：模擬卡住的磁碟（SPEC-005 §2.5）。
class _HangingDirectoryProbe implements WorkspaceDirectoryProbePort {
  @override
  Future<bool> exists(String path) => Completer<bool>().future;

  @override
  Future<void> readFirstEntry(String path) => Completer<void>().future;
}

void _probeRecentProjectTests() {
  group('probeRecentProject（SPEC-005 §2.5）', () {
    test('資料夾存在可讀：RecentProjectAvailable', () async {
      final repo = WorkspaceRepository(directoryProbe: _FakeDirectoryProbe());
      expect(
        await repo.probeRecentProject('/ws'),
        isA<RecentProjectAvailable>(),
      );
    });

    test('資料夾不存在：RecentProjectUnavailable，reason 與 openPath 同值', () async {
      final repo = WorkspaceRepository(
        directoryProbe: _FakeDirectoryProbe(existsResult: false),
        preferencesPort: _FakePreferencesPort(),
      );
      final probed = await repo.probeRecentProject('/ws');
      final opened = await repo.openPath('/ws');
      final reason =
          ((opened as ChooseFolderSelected).state as WorkspaceUnavailable)
              .reason;
      expect(probed, isA<RecentProjectUnavailable>());
      expect((probed as RecentProjectUnavailable).reason, reason);
    });

    test('資料夾不可讀：RecentProjectUnavailable，不拋例外', () async {
      final repo = WorkspaceRepository(
        directoryProbe: _FakeDirectoryProbe(
          readFirstEntryError: const FileSystemException('denied'),
        ),
      );
      final probed = await repo.probeRecentProject('/ws');
      expect(probed, isA<RecentProjectUnavailable>());
      expect((probed as RecentProjectUnavailable).reason, isNotEmpty);
    });

    testWidgets('探測超過 2 秒未回：RecentProjectProbeTimedOut 並記 level 900', (
      tester,
    ) async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        directoryProbe: _HangingDirectoryProbe(),
        logSink: log.call,
      );
      RecentProjectAvailability? result;
      unawaited(repo.probeRecentProject('/ws').then((v) => result = v));

      await tester.pump(const Duration(milliseconds: 1900));
      expect(result, isNull);
      expect(
        log.containsEvent(WorkspaceLogEvent.probeRecentProjectTimedOut),
        isFalse,
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(result, isA<RecentProjectProbeTimedOut>());
      final entry = log.entries.singleWhere(
        (e) => e.event == WorkspaceLogEvent.probeRecentProjectTimedOut,
      );
      expect(entry.level, 900);
    });
  });
}

void main() {
  _probeRecentProjectTests();
  group('G1｜呼叫發出時刻（INV-PORT-OBSERVE-001 覆蓋）', () {
    test('G1-1 開啟選取面板前發出呼叫事件', () async {
      final picker = _PickerRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: picker.call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      expect(picker.calls.length, 1);
      expect(
        log.containsEvent(WorkspaceLogEvent.chooseFolderPanelOpening),
        isTrue,
      );
    });

    test('G1-2 使用者取消時「呼叫發出」事件仍存在（提早返回路徑）', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: null).call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      expect(
        log.containsEvent(WorkspaceLogEvent.chooseFolderPanelOpening),
        isTrue,
      );
      expect(
        log.containsEvent(WorkspaceLogEvent.chooseFolderCancelled),
        isTrue,
      );
    });

    test('G1-3 面板拋例外時「呼叫發出」事件仍存在（提早返回路徑）', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(error: Exception('面板開不起來')).call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      final issuedIndex = log.indexOfEvent(
        WorkspaceLogEvent.chooseFolderPanelOpening,
      );
      final failureIndex = log.indexOfEvent(
        WorkspaceLogEvent.chooseFolderPanelUnavailable,
      );
      expect(issuedIndex, greaterThanOrEqualTo(0));
      expect(failureIndex, greaterThan(issuedIndex));
    });

    test('G1-4 持久化前發出呼叫事件（含目標 key 與 path）', () async {
      final preferences = _PreferencesRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: preferences,
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      await repo.chooseFolder();

      expect(preferences.calls.any((c) => c.method == 'open'), isTrue);
      expect(log.containsEvent(WorkspaceLogEvent.persistIssuing), isTrue);
      expect(
        log.entries
            .where((e) => e.event == WorkspaceLogEvent.persistIssuing)
            .every(
              (e) =>
                  e.payload[WorkspaceLogKeys.key] == 'workspacePath' &&
                  !e.payload.values.any((v) => '$v'.contains('/tmp/ws')),
            ),
        isTrue,
      );
    });

    test('G1-5 restore() 進入即發出呼叫事件', () async {
      final preferences = _PreferencesRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: preferences,
        logSink: log.call,
      );

      await repo.restore();

      expect(log.containsEvent(WorkspaceLogEvent.restoreIssuing), isTrue);
      expect(
        log.entries
            .where((e) => e.event == WorkspaceLogEvent.restoreIssuing)
            .every((e) => e.payload[WorkspaceLogKeys.key] == 'workspacePath'),
        isTrue,
      );
      expect(preferences.calls.any((c) => c.method == 'open'), isTrue);
    });

    test(
      'G1-6 _inspect 的 Directory.exists 有呼叫發出事件（acceptance 第 5 條）',
      () async {
        final probe = _DirectoryProbeRecorder();
        final log = _LogRecorder();
        final repo = WorkspaceRepository(
          preferencesPort: _FakePreferencesPort(readValue: '/tmp/ws'),
          directoryProbe: probe,
          logSink: log.call,
        );

        await repo.restore();

        expect(probe.calls.any((c) => c.method == 'exists'), isTrue);
        expect(
          log.containsEvent(WorkspaceLogEvent.inspectExistsIssuing),
          isTrue,
        );
      },
    );

    test(
      'G1-7 _inspect 的 dir.list().first 有呼叫發出事件（acceptance 第 5 條）',
      () async {
        final probe = _DirectoryProbeRecorder();
        final log = _LogRecorder();
        final repo = WorkspaceRepository(
          preferencesPort: _FakePreferencesPort(readValue: '/tmp/ws'),
          directoryProbe: probe,
          logSink: log.call,
        );

        await repo.restore();

        expect(probe.calls.any((c) => c.method == 'readFirstEntry'), isTrue);
        expect(log.containsEvent(WorkspaceLogEvent.inspectReadIssuing), isTrue);
      },
    );

    test('G1-8 restore() 儲存層拋例外時「呼叫發出」事件仍存在（提早返回路徑）', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('讀取失敗')),
        logSink: log.call,
      );

      await repo.restore();

      expect(log.containsEvent(WorkspaceLogEvent.restoreIssuing), isTrue);
    });
  });

  group('G2｜chooseFolder 結局與四個 variant', () {
    test('G2-1 選取成功且成功記住', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: _FakePreferencesPort(writeResult: true),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderSelected>());
      final selected = result as ChooseFolderSelected;
      expect(selected.state, isA<WorkspaceReady>());
      expect((selected.state as WorkspaceReady).path, '/tmp/ws');

      final indices = [
        log.indexOfEvent(WorkspaceLogEvent.chooseFolderPanelOpening),
        log.indexOfEvent(WorkspaceLogEvent.chooseFolderPathSelected),
        log.indexOfEvent(WorkspaceLogEvent.persistIssuing),
        log.indexOfEvent(WorkspaceLogEvent.persistPreferencesReady),
        log.indexOfEvent(WorkspaceLogEvent.persistCompleted),
      ];
      expect(indices, everyElement(greaterThanOrEqualTo(0)));
      for (var i = 1; i < indices.length; i++) {
        expect(indices[i], greaterThan(indices[i - 1]));
      }
    });

    test('G2-2 寫入回 false → ChooseFolderNotRemembered', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: _FakePreferencesPort(writeResult: false),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderNotRemembered>());
      final notRemembered = result as ChooseFolderNotRemembered;
      expect(notRemembered.reason, isNotEmpty);
      expect(notRemembered.state, isA<WorkspaceReady>());
      // G5：日誌與回傳分別斷言，不互相抵扣。
      expect(
        log.containsEvent(WorkspaceLogEvent.persistWriteReturnedFalse),
        isTrue,
      );
    });

    test('G2-3 寫入拋例外 → ChooseFolderNotRemembered', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: _FakePreferencesPort(
          writeError: Exception('寫入失敗：磁碟已滿'),
        ),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderNotRemembered>());
      final notRemembered = result as ChooseFolderNotRemembered;
      expect(notRemembered.reason, contains('寫入失敗'));
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    test('G2-4 NotRemembered 攜帶而非取代 state（跨案例等價斷言）', () async {
      final selectedRepo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: _FakePreferencesPort(writeResult: true),
        directoryProbe: _FakeDirectoryProbe(),
      );
      final notRememberedRepo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: _FakePreferencesPort(writeResult: false),
        directoryProbe: _FakeDirectoryProbe(),
      );

      final selected =
          (await selectedRepo.chooseFolder()) as ChooseFolderSelected;
      final notRemembered =
          (await notRememberedRepo.chooseFolder()) as ChooseFolderNotRemembered;

      expect(selected.state.runtimeType, notRemembered.state.runtimeType);
      expect(
        (selected.state as WorkspaceReady).path,
        (notRemembered.state as WorkspaceReady).path,
      );
    });

    test('G2-5 使用者取消 → ChooseFolderCancelled 且不觸碰 SharedPreferences', () async {
      final preferences = _PreferencesRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: null).call,
        preferencesPort: preferences,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderCancelled>());
      expect(preferences.calls, isEmpty);
    });

    test('G2-6 面板不可用 → ChooseFolderUnavailable', () async {
      final preferences = _PreferencesRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(
          error: Exception('MissingPluginException'),
        ).call,
        preferencesPort: preferences,
        logSink: log.call,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderUnavailable>());
      expect((result as ChooseFolderUnavailable).reason, isNotEmpty);
      expect(preferences.calls, isEmpty);
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });
  });

  group('G2b｜openPath 與 chooseFolder 共用 _persistAndInspect（0.2.1-W1-054）', () {
    test(
      'G2b-1 成功：寫入已存路徑，探測可用 → ChooseFolderSelected(WorkspaceReady)',
      () async {
        final values = <String, String?>{};
        final repo = WorkspaceRepository(
          preferencesPort: _FakeKeyedPreferencesPort(values: values),
          directoryProbe: _FakeDirectoryProbe(),
        );

        final result = await repo.openPath('/tmp/recent-project');

        expect(result, isA<ChooseFolderSelected>());
        final selected = result as ChooseFolderSelected;
        expect(selected.state, isA<WorkspaceReady>());
        expect((selected.state as WorkspaceReady).path, '/tmp/recent-project');
        // 已存路徑確實被寫入（下次 restore() 可讀回，非僅回傳值正確）。
        expect(values['workspace.path'], '/tmp/recent-project');
      },
    );

    test('G2b-2 探測失敗 → WorkspaceUnavailable，不寫入已存路徑', () async {
      final values = <String, String?>{};
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(values: values),
        directoryProbe: _FakeDirectoryProbe(existsResult: false),
      );

      final result = await repo.openPath('/tmp/missing-project');

      expect(result, isA<ChooseFolderSelected>());
      final selected = result as ChooseFolderSelected;
      expect(selected.state, isA<WorkspaceUnavailable>());
      expect(values, isEmpty);
    });

    test('G2b-3 不呼叫 pickDirectoryPath（路徑來源不經系統選擇器）', () async {
      final picker = _PickerRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: picker.call,
        preferencesPort: _FakeKeyedPreferencesPort(values: {}),
        directoryProbe: _FakeDirectoryProbe(),
      );

      await repo.openPath('/tmp/recent-project');

      expect(picker.calls, isEmpty);
    });
  });

  group('G2c｜不可用不寫入、版號 key 失敗處理（0.5.0-W1-169.1.1）', () {
    Future<ChooseFolderResult> run(
      bool viaOpenPath,
      WorkspacePreferencesPort prefs,
      WorkspaceDirectoryProbePort probe,
      _LogRecorder log,
    ) {
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: prefs,
        directoryProbe: probe,
        logSink: log.call,
      );
      return viaOpenPath ? repo.openPath('/tmp/ws') : repo.chooseFolder();
    }

    final unavailableProbes = <String, WorkspaceDirectoryProbePort>{
      'exists false': _FakeDirectoryProbe(existsResult: false),
      'readFirstEntry 拋 FileSystemException': _FakeDirectoryProbe(
        readFirstEntryError: const FileSystemException('denied'),
      ),
    };

    for (final viaOpenPath in [false, true]) {
      final name = viaOpenPath ? 'openPath' : 'chooseFolder';
      for (final entry in unavailableProbes.entries) {
        test(
          'G2c-1 $name／${entry.key}：不呼叫 writeString，回 Selected(Unavailable)',
          () async {
            final prefs = _PreferencesRecorder();
            final result = await run(
              viaOpenPath,
              prefs,
              entry.value,
              _LogRecorder(),
            );

            expect(
              prefs.calls.where((c) => c.method == 'writeString'),
              isEmpty,
            );
            expect(result, isA<ChooseFolderSelected>());
            expect(
              (result as ChooseFolderSelected).state,
              isA<WorkspaceUnavailable>(),
            );
          },
        );
      }

      test('G2c-2 $name 對照：可用時 writeString 會被呼叫', () async {
        final prefs = _PreferencesRecorder();
        await run(viaOpenPath, prefs, _FakeDirectoryProbe(), _LogRecorder());

        final writes = prefs.calls.where((c) => c.method == 'writeString');
        expect(writes.map((c) => c.args.first), [
          'workspace.path',
          'workspace.schemaVersion',
        ]);
      });
    }

    test(
      'G2c-3 版號 key 回 false：Selected、level 900、不記 persistCompleted',
      () async {
        final log = _LogRecorder();
        final result = await run(
          true,
          _VersionKeyPort(writeResult: false),
          _FakeDirectoryProbe(),
          log,
        );

        expect(result, isA<ChooseFolderSelected>());
        expect(log.entries.any((e) => e.level == 900), isTrue);
        expect(log.containsEvent(WorkspaceLogEvent.persistCompleted), isFalse);
      },
    );

    test('G2c-4 版號 key 拋例外：Selected、level 900、不記 persistCompleted', () async {
      final log = _LogRecorder();
      final result = await run(
        true,
        _VersionKeyPort(error: Exception('版號寫入失敗')),
        _FakeDirectoryProbe(),
        log,
      );

      expect(result, isA<ChooseFolderSelected>());
      expect(log.entries.any((e) => e.level == 900), isTrue);
      expect(log.containsEvent(WorkspaceLogEvent.persistCompleted), isFalse);
    });

    test('G2c-5 失敗的偏好替身＋不存在的探測替身：不回 NotRemembered', () async {
      for (final prefs in <WorkspacePreferencesPort>[
        _FakePreferencesPort(writeResult: false),
        _FakePreferencesPort(writeError: Exception('磁碟已滿')),
      ]) {
        final result = await run(
          false,
          prefs,
          _FakeDirectoryProbe(existsResult: false),
          _LogRecorder(),
        );
        expect(result, isA<ChooseFolderSelected>());
        expect(
          (result as ChooseFolderSelected).state,
          isA<WorkspaceUnavailable>(),
        );
      }
    });
  });

  group('G3｜restore 結局三分支', () {
    test('G3-1 從未設定過', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: null),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnset>());
      final indices = [
        log.indexOfEvent(WorkspaceLogEvent.restoreIssuing),
        log.indexOfEvent(WorkspaceLogEvent.restorePreferencesReady),
        log.indexOfEvent(WorkspaceLogEvent.restoreNoStoredPath),
      ];
      expect(indices, everyElement(greaterThanOrEqualTo(0)));
      for (var i = 1; i < indices.length; i++) {
        expect(indices[i], greaterThan(indices[i - 1]));
      }
    });

    test('G3-2 儲存層不可用', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('儲存層失效')),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      expect((result as WorkspaceUnavailable).lastKnownPath, isNull);
      expect(result.reason, isNotEmpty);
      expect(result.runtimeType, isNot(const WorkspaceUnset().runtimeType));
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    // 3b-E 回歸鎖：restore() 例外路徑的 reason 曾直接插值原始例外字串
    // （'$e'），使未選專案畫面（_UnsetView）顯示例外型別名給使用者看。日誌拿例外
    // 細節、reason 拿固定文案，兩者不互相抵扣，此測試鎖住這條界線。
    test('G3-2b restore() 例外路徑的 reason 不含例外型別名（不外露原始例外字串）', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(
          openError: Exception('儲存層失效：磁碟已拔除'),
        ),
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      final reason = (result as WorkspaceUnavailable).reason;
      expect(reason, isNot(contains('Exception')));
      expect(reason, isNot(contains('Error')));
      expect(reason, isNot(contains('儲存層失效：磁碟已拔除')));
    });

    test('G3-3 路徑存在且可讀', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/ws'),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceReady>());
      expect((result as WorkspaceReady).path, '/tmp/ws');
      expect(log.containsEvent(WorkspaceLogEvent.restoreCompleted), isTrue);
    });

    test('G3-4 路徑已消失（既有行為，不變更）', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/gone'),
        directoryProbe: _FakeDirectoryProbe(existsResult: false),
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      expect((result as WorkspaceUnavailable).lastKnownPath, '/tmp/gone');
    });
  });

  group('G4｜受理時刻', () {
    test('G4-1 SharedPreferences 受理事件存在且順序正確', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: null),
        logSink: log.call,
      );

      await repo.restore();

      final issuedIndex = log.indexOfEvent(WorkspaceLogEvent.restoreIssuing);
      final acceptedIndex = log.indexOfEvent(
        WorkspaceLogEvent.restorePreferencesReady,
      );
      final resultIndex = log.indexOfEvent(
        WorkspaceLogEvent.restoreNoStoredPath,
      );
      expect(acceptedIndex, greaterThan(issuedIndex));
      expect(resultIndex, greaterThan(acceptedIndex));
    });

    test('G4-2 open() 失敗時無受理事件（負向）', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('失敗')),
        logSink: log.call,
      );

      await repo.restore();

      expect(
        log.containsEvent(WorkspaceLogEvent.restorePreferencesReady),
        isFalse,
      );
    });

    test('G4-3 file_selector 無受理事件（負向，鎖定裁決 C 的不適用判定）', () async {
      final picker = _PickerRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: picker.call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      // 記錄器只回中性 null，chooseFolder 走取消路徑，不觸碰 preferences；
      // picker 相關的日誌只有「呼叫發出」與「使用者取消」兩類，無受理事件。
      expect(
        log.containsEvent(WorkspaceLogEvent.persistPreferencesReady),
        isFalse,
      );
    });
  });

  group('G5｜schema 版本化與遷移（0.2.0-W1-021）', () {
    test('G5-1 v0 舊資料（有 path 無版號 key）→ 遷移後仍還原出同一個 path', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(
          values: {'workspace.path': '/tmp/legacy'},
        ),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceReady>());
      expect((result as WorkspaceReady).path, '/tmp/legacy');
      expect(log.containsEvent(WorkspaceLogEvent.restoreMigrated), isTrue);
    });

    test('G5-2 目前版號（path + 版號皆存在且相符）→ 直接還原，不觸發遷移日誌', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(
          values: {
            'workspace.path': '/tmp/current',
            'workspace.schemaVersion': '1',
          },
        ),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceReady>());
      expect((result as WorkspaceReady).path, '/tmp/current');
      expect(log.containsEvent(WorkspaceLogEvent.restoreMigrated), isFalse);
    });

    test('G5-3 無 path 無版號（真正首次啟動）→ WorkspaceUnset，不判定為遷移', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(values: const {}),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnset>());
      expect(log.containsEvent(WorkspaceLogEvent.restoreMigrated), isFalse);
    });

    test('G5-4 版號比目前版本更新（未來格式）→ 遷移失敗，降級為 WorkspaceUnset，不阻擋 App', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(
          values: {
            'workspace.path': '/tmp/future',
            'workspace.schemaVersion': '2',
          },
        ),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnset>());
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    test('G5-5 chooseFolder 成功時版號 key 與 path key 同一次操作寫入', () async {
      final preferences = _PreferencesRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: preferences,
        directoryProbe: _FakeDirectoryProbe(),
      );

      await repo.chooseFolder();

      final writeCalls = preferences.calls
          .where((c) => c.method == 'writeString')
          .toList();
      expect(writeCalls.length, 2);
      expect(writeCalls[0].args, ['workspace.path', '/tmp/ws']);
      expect(writeCalls[1].args, ['workspace.schemaVersion', '1']);
    });
  });

  group('G6｜_inspect 探測結局', () {
    test('G6-1 資料夾不存在 → WorkspaceUnavailable(lastKnownPath: path)', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/missing'),
        directoryProbe: _FakeDirectoryProbe(existsResult: false),
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      expect((result as WorkspaceUnavailable).lastKnownPath, '/tmp/missing');
    });

    test('G6-2 readFirstEntry 拋 FileSystemException → WorkspaceUnavailable '
        '+ level 900 日誌', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/broken'),
        directoryProbe: _FakeDirectoryProbe(
          readFirstEntryError: const FileSystemException('讀取失敗', '/tmp/broken'),
        ),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    // Phase 4b 回歸鎖：_inspect() 的 FileSystemException 分支曾把
    // e.osError?.message（OS 語系文字）塞進 reason；改為固定文案常數後，
    // 用一個帶有明顯可辨識訊息的 OSError 驗證該訊息不會外露到 reason。
    // 比照 G3-2b 的裝置，鎖住 WorkspaceUnavailable.reason 契約的第二條
    // 產生路徑（restore() 例外路徑已由 G3-2b 鎖定）。
    test('G6-2b _inspect 的 FileSystemException 分支 reason 不含 OSError '
        '原始訊息（不外露 OS 語系文字）', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/broken'),
        directoryProbe: _FakeDirectoryProbe(
          readFirstEntryError: const FileSystemException(
            '讀取失敗',
            '/tmp/broken',
            OSError('Operation not permitted', 1),
          ),
        ),
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      final reason = (result as WorkspaceUnavailable).reason;
      expect(reason, isNot(contains('Operation not permitted')));
      expect(reason, isNotEmpty);
    });

    test(
      'G6-3 readFirstEntry 拋 StateError（空資料夾）→ WorkspaceReady（不是失敗）',
      () async {
        final log = _LogRecorder();
        final repo = WorkspaceRepository(
          preferencesPort: _FakePreferencesPort(readValue: '/tmp/empty'),
          directoryProbe: _FakeDirectoryProbe(
            readFirstEntryError: StateError('No element'),
          ),
          logSink: log.call,
        );

        final result = await repo.restore();

        expect(result, isA<WorkspaceReady>());
        expect(log.entries.any((e) => e.level == 900), isFalse);
      },
    );

    test('G6-4 探測成功 → WorkspaceReady', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/ok'),
        directoryProbe: _FakeDirectoryProbe(),
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceReady>());
      expect((result as WorkspaceReady).path, '/tmp/ok');
    });
  });

  group('G7｜loadRecentProjects／addRecentProject（SPEC-005 §2.4）', () {
    test('G7-1 key 不存在 → 空清單', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(values: {}),
      );

      final result = await repo.loadRecentProjects();

      expect(result, isEmpty);
    });

    test('G7-2 成功讀取，依 lastOpenedAt 降冪排序（不信任儲存順序）', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(
          values: {
            'workspace.recentProjects': '''
[
  {"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z"},
  {"path": "/tmp/b", "lastOpenedAt": "2026-09-24T01:25:50.000Z"}
]
''',
          },
        ),
      );

      final result = await repo.loadRecentProjects();

      expect(result.map((p) => p.path).toList(), ['/tmp/b', '/tmp/a']);
    });

    test('G7-3 JSON 解析失敗（非陣列）→ 空清單 + level 900 日誌', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(
          values: {'workspace.recentProjects': '{"not": "an array"}'},
        ),
        logSink: log.call,
      );

      final result = await repo.loadRecentProjects();

      expect(result, isEmpty);
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    test('G7-4 元素缺欄位（型別不符）→ 整份視為損壞，回空清單', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(
          values: {'workspace.recentProjects': '[{"path": "/tmp/a"}]'},
        ),
      );

      final result = await repo.loadRecentProjects();

      expect(result, isEmpty);
    });

    test('G7-5 開啟儲存管道例外 → 空清單', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('讀取失敗')),
      );

      final result = await repo.loadRecentProjects();

      expect(result, isEmpty);
    });

    test('G7-6 addRecentProject 首次寫入（原清單為空）', () async {
      final values = <String, String?>{};
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(values: values),
      );

      final success = await repo.addRecentProject('/tmp/new');

      expect(success, isTrue);
      final reloaded = await repo.loadRecentProjects();
      expect(reloaded.map((p) => p.path).toList(), ['/tmp/new']);
    });

    test('G7-7 addRecentProject 同 path 去重並移至頂端', () async {
      final values = <String, String?>{
        'workspace.recentProjects': '''
[
  {"path": "/tmp/a", "lastOpenedAt": "2026-09-24T01:00:00.000Z"},
  {"path": "/tmp/b", "lastOpenedAt": "2026-09-20T01:00:00.000Z"}
]
''',
      };
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(values: values),
      );

      final success = await repo.addRecentProject('/tmp/b');

      expect(success, isTrue);
      final reloaded = await repo.loadRecentProjects();
      expect(reloaded.length, 2);
      expect(reloaded.first.path, '/tmp/b');
    });

    test('G7-8 addRecentProject 讀到損壞內容以空清單為基底寫入 + level 900 日誌', () async {
      final log = _LogRecorder();
      final values = <String, String?>{
        'workspace.recentProjects': '{"not": "an array"}',
      };
      final repo = WorkspaceRepository(
        preferencesPort: _FakeKeyedPreferencesPort(values: values),
        logSink: log.call,
      );

      final success = await repo.addRecentProject('/tmp/new');

      expect(success, isTrue);
      final reloaded = await repo.loadRecentProjects();
      expect(reloaded.map((p) => p.path).toList(), ['/tmp/new']);
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    test('G7-9 addRecentProject 開啟儲存管道例外 → false', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('開不起來')),
      );

      final success = await repo.addRecentProject('/tmp/new');

      expect(success, isFalse);
    });

    test('G7-10 addRecentProject 寫入回報 false → false', () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(writeResult: false),
      );

      final success = await repo.addRecentProject('/tmp/new');

      expect(success, isFalse);
    });
  });

  group('G8｜計數快照（SPEC-005 §2.4〈計數快照〉）', () {
    const key = 'workspace.recentProjects';
    const countsJson =
        '"counts": {"nodeCount": 237, "ticketCount": 2419, "issueCount": 3}';
    const counts1 = RecentProjectCounts(
      nodeCount: 1,
      ticketCount: 1,
      issueCount: 1,
    );

    WorkspaceRepository repoWith(
      Map<String, String?> values, [
      _LogRecorder? log,
    ]) => WorkspaceRepository(
      preferencesPort: _FakeKeyedPreferencesPort(values: values),
      logSink: log?.call,
    );

    test('G8-1 含 counts 的元素讀得 RecentProjectCounts', () async {
      final repo = repoWith({
        key:
            '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z", '
            '$countsJson}]',
      });

      final result = await repo.loadRecentProjects();

      final counts = result.single.counts;
      expect(counts, isNotNull);
      expect(counts!.nodeCount, 237);
      expect(counts.ticketCount, 2419);
      expect(counts.issueCount, 3);
    });

    test('G8-2 無 counts 的元素 counts 為 null（舊資料遷移）', () async {
      final repo = repoWith({
        key: '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}]',
      });

      final result = await repo.loadRecentProjects();

      expect(result.single.counts, isNull);
    });

    for (final bad in const {
      '缺欄': '"counts": {"nodeCount": 1, "ticketCount": 2}',
      '非整數': '"counts": {"nodeCount": "1", "ticketCount": 2, "issueCount": 0}',
      '負數': '"counts": {"nodeCount": -1, "ticketCount": 2, "issueCount": 0}',
      '非物件': '"counts": 5',
    }.entries) {
      test('G8-3 counts ${bad.key} → 該項 null、其餘項照常、level 900', () async {
        final log = _LogRecorder();
        final repo = repoWith({
          key:
              '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z", '
              '${bad.value}}, '
              '{"path": "/tmp/b", "lastOpenedAt": "2026-09-19T08:00:00.000Z", '
              '$countsJson}]',
        }, log);

        final result = await repo.loadRecentProjects();

        expect(result.map((p) => p.path).toList(), ['/tmp/a', '/tmp/b']);
        expect(result[0].counts, isNull);
        expect(result[1].counts, isNotNull);
        expect(log.entries.any((e) => e.level == 900), isTrue);
      });
    }

    test('G8-3b 純解析：counts 格式不符 → counts 為 null 且回報 index', () {
      final parsed = parseRecentProjectsPure(
        '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z", '
        '"counts": 5}, '
        '{"path": "/tmp/b", "lastOpenedAt": "2026-09-19T08:00:00.000Z"}]',
      );

      expect(parsed, isNotNull);
      expect(parsed!.projects.map((p) => p.path).toList(), [
        '/tmp/a',
        '/tmp/b',
      ]);
      expect(parsed.projects[0].counts, isNull);
      expect(parsed.invalidCountsIndexes, [0]);
    });

    test('G8-3c 純解析：整份損壞回 null', () {
      expect(parseRecentProjectsPure('{"not": "a list"}'), isNull);
    });

    test('G8-4 addRecentProject 重新開啟同 path 保留舊 counts', () async {
      final repo = repoWith({
        key:
            '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z", '
            '$countsJson}]',
      });

      await repo.addRecentProject('/tmp/a');

      final reloaded = await repo.loadRecentProjects();
      expect(reloaded.single.counts?.nodeCount, 237);
    });

    test('G8-5 saveRecentProjectCounts 只改同 path 項的 counts', () async {
      final repo = repoWith({
        key:
            '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}, '
            '{"path": "/tmp/b", "lastOpenedAt": "2026-09-24T01:25:50.000Z"}]',
      });

      final ok = await repo.saveRecentProjectCounts(
        '/tmp/a',
        const RecentProjectCounts(nodeCount: 5, ticketCount: 6, issueCount: 7),
      );

      expect(ok, isTrue);
      final reloaded = await repo.loadRecentProjects();
      expect(reloaded.map((p) => p.path).toList(), ['/tmp/b', '/tmp/a']);
      expect(reloaded[1].counts?.issueCount, 7);
      expect(reloaded[1].lastOpenedAt, DateTime.utc(2026, 9, 20, 8));
      expect(reloaded[0].counts, isNull);
    });

    test('G8-6 無同 path 項 → false 且不寫入', () async {
      const raw =
          '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}]';
      final values = <String, String?>{key: raw};
      final repo = repoWith(values);

      final ok = await repo.saveRecentProjectCounts('/tmp/none', counts1);

      expect(ok, isFalse);
      expect(values[key], raw);
    });

    test('G8-7 讀到損壞清單 → false、不寫入、level 900', () async {
      final log = _LogRecorder();
      final values = <String, String?>{key: '{"not": "an array"}'};
      final repo = repoWith(values, log);

      final ok = await repo.saveRecentProjectCounts('/tmp/a', counts1);

      expect(ok, isFalse);
      expect(values[key], '{"not": "an array"}');
      expect(log.entries.any((e) => e.level == 900), isTrue);
    });

    test('G8-8 開啟管道例外與寫入回 false／拋例外皆回 false', () async {
      const raw =
          '[{"path": "/tmp/a", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}]';
      final openThrows = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('x')),
      );
      final writeFalse = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(
          readValue: raw,
          writeResult: false,
        ),
      );
      final writeThrows = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(
          readValue: raw,
          writeError: Exception('x'),
        ),
      );

      expect(
        await openThrows.saveRecentProjectCounts('/tmp/a', counts1),
        isFalse,
      );
      expect(
        await writeFalse.saveRecentProjectCounts('/tmp/a', counts1),
        isFalse,
      );
      expect(
        await writeThrows.saveRecentProjectCounts('/tmp/a', counts1),
        isFalse,
      );
    });
  });
}

// ============================================================
// 記錄器（Recorder）：只累積 (方法名, 參數)，回中性值。
// 斷言只針對記錄內容與日誌，禁止對記錄器的回傳做結局斷言。
// ============================================================

/// 一次被記錄的呼叫：方法名 + 參數。
class _Call {
  const _Call(this.method, [this.args = const []]);
  final String method;
  final List<Object?> args;
}

/// [DirectoryPathPicker] 的記錄器：回中性 null，不作結局替身用。
class _PickerRecorder {
  final calls = <_Call>[];

  Future<String?> call() async {
    calls.add(const _Call('pickDirectoryPath'));
    return null;
  }
}

/// [WorkspacePreferencesPort] 的記錄器：`open()` 回一個同樣只記錄的 handle。
class _PreferencesRecorder implements WorkspacePreferencesPort {
  final calls = <_Call>[];

  @override
  Future<WorkspacePreferencesHandle> open() async {
    calls.add(const _Call('open'));
    return _HandleRecorder(calls);
  }
}

class _HandleRecorder implements WorkspacePreferencesHandle {
  _HandleRecorder(this._calls);
  final List<_Call> _calls;

  @override
  String? readString(String key) {
    _calls.add(_Call('readString', [key]));
    return null;
  }

  @override
  Future<bool> writeString(String key, String value) async {
    _calls.add(_Call('writeString', [key, value]));
    return true;
  }
}

/// [WorkspaceDirectoryProbePort] 的記錄器：`exists` 回中性 true 供上游驅動。
class _DirectoryProbeRecorder implements WorkspaceDirectoryProbePort {
  final calls = <_Call>[];

  @override
  Future<bool> exists(String path) async {
    calls.add(_Call('exists', [path]));
    return true;
  }

  @override
  Future<void> readFirstEntry(String path) async {
    calls.add(_Call('readFirstEntry', [path]));
  }
}

/// 日誌記錄器：實作 `LogSink<WorkspaceLogEvent>`，累積 (事件識別碼, 負載,
/// 等級, 錯誤)，供索引順序斷言。
///
/// 斷言綁 [WorkspaceLogEvent]（穩定契約）與 FR-03 白名單負載；
/// 等級以 `developer.log` 數值（warning = 900）記錄。
class _LogRecorder {
  final entries = <_LogEntry>[];

  void call(
    WorkspaceLogEvent event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) {
    entries.add(_LogEntry(fields.toJson(), event, level.devLogLevel, error));
  }

  /// 是否存在任何一筆識別碼為 [event] 的日誌。
  bool containsEvent(WorkspaceLogEvent event) =>
      entries.any((e) => e.event == event);

  /// 第一個識別碼為 [event] 的日誌項索引；找不到回傳 -1。
  int indexOfEvent(WorkspaceLogEvent event) =>
      entries.indexWhere((e) => e.event == event);
}

class _LogEntry {
  const _LogEntry(this.payload, this.event, this.level, this.error);
  final Map<String, Object> payload;
  final WorkspaceLogEvent event;
  final int? level;
  final Object? error;
}

// ============================================================
// 行為替身（Fake）：獨立類別，只用於受理／結果測試，可配置結局。
// ============================================================

class _FakePicker {
  _FakePicker({this.path, this.error});
  final String? path;
  final Object? error;

  Future<String?> call() async {
    final err = error;
    if (err != null) throw err;
    return path;
  }
}

class _FakePreferencesPort implements WorkspacePreferencesPort {
  _FakePreferencesPort({
    this.openError,
    this.readValue,
    this.writeResult = true,
    this.writeError,
  });

  final Object? openError;
  final String? readValue;
  final bool writeResult;
  final Object? writeError;

  @override
  Future<WorkspacePreferencesHandle> open() async {
    final err = openError;
    if (err != null) throw err;
    return _FakePreferencesHandle(
      readValue: readValue,
      writeResult: writeResult,
      writeError: writeError,
    );
  }
}

class _FakePreferencesHandle implements WorkspacePreferencesHandle {
  _FakePreferencesHandle({
    this.readValue,
    this.writeResult = true,
    this.writeError,
  });

  final String? readValue;
  final bool writeResult;
  final Object? writeError;

  @override
  String? readString(String key) => readValue;

  @override
  Future<bool> writeString(String key, String value) async {
    final err = writeError;
    if (err != null) throw err;
    return writeResult;
  }
}

/// 支援多個獨立 key 的偏好設定假資料（G5 遷移測試專用）。與
/// [_FakePreferencesPort] 不同：後者不分 key 一律回同一個 `readValue`，
/// 無法表達「path 存在但版號 key 不存在」這種舊資料形狀，故另立獨立類別
/// 而非把可配置性塞進既有 fake（module 檔頭紀律 1）。
class _FakeKeyedPreferencesPort implements WorkspacePreferencesPort {
  _FakeKeyedPreferencesPort({required this.values});
  final Map<String, String?> values;

  @override
  Future<WorkspacePreferencesHandle> open() async =>
      _FakeKeyedPreferencesHandle(values);
}

class _FakeKeyedPreferencesHandle implements WorkspacePreferencesHandle {
  _FakeKeyedPreferencesHandle(this.values);
  final Map<String, String?> values;

  @override
  String? readString(String key) => values[key];

  @override
  Future<bool> writeString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _FakeDirectoryProbe implements WorkspaceDirectoryProbePort {
  _FakeDirectoryProbe({this.existsResult = true, this.readFirstEntryError});

  final bool existsResult;
  final Object? readFirstEntryError;

  @override
  Future<bool> exists(String path) async => existsResult;

  @override
  Future<void> readFirstEntry(String path) async {
    final err = readFirstEntryError;
    if (err != null) throw err;
  }
}

/// path key 寫入成功，版號 key 依配置回 false 或拋例外。
class _VersionKeyPort implements WorkspacePreferencesPort {
  _VersionKeyPort({this.writeResult = true, this.error});
  final bool writeResult;
  final Object? error;

  @override
  Future<WorkspacePreferencesHandle> open() async =>
      _VersionKeyHandle(writeResult, error);
}

class _VersionKeyHandle implements WorkspacePreferencesHandle {
  _VersionKeyHandle(this.writeResult, this.error);
  final bool writeResult;
  final Object? error;

  @override
  String? readString(String key) => null;

  @override
  Future<bool> writeString(String key, String value) async {
    if (key == 'workspace.path') return true;
    final err = error;
    if (err != null) throw err;
    return writeResult;
  }
}
