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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';

void main() {
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
      expect(log.contains('開啟資料夾選取面板'), isTrue);
    });

    test('G1-2 使用者取消時「呼叫發出」事件仍存在（提早返回路徑）', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: null).call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      expect(log.contains('開啟資料夾選取面板'), isTrue);
      expect(log.contains('使用者取消選取'), isTrue);
    });

    test('G1-3 面板拋例外時「呼叫發出」事件仍存在（提早返回路徑）', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(error: Exception('面板開不起來')).call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      final issuedIndex = log.indexOfSubstring('開啟資料夾選取面板');
      final failureIndex = log.indexOfSubstring('面板不可用');
      expect(issuedIndex, greaterThanOrEqualTo(0));
      expect(failureIndex, greaterThan(issuedIndex));
    });

    test('G1-4 持久化前發出呼叫事件（含目標 key 與 path）', () async {
      final preferences = _PreferencesRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort: preferences,
        logSink: log.call,
      );

      await repo.chooseFolder();

      expect(preferences.calls.any((c) => c.method == 'open'), isTrue);
      expect(log.containsAll(['準備持久化', 'workspace.path', '/tmp/ws']), isTrue);
    });

    test('G1-5 restore() 進入即發出呼叫事件', () async {
      final preferences = _PreferencesRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: preferences,
        logSink: log.call,
      );

      await repo.restore();

      expect(log.containsAll(['還原工作資料夾', 'workspace.path']), isTrue);
      expect(preferences.calls.any((c) => c.method == 'open'), isTrue);
    });

    test('G1-6 _inspect 的 Directory.exists 有呼叫發出事件（acceptance 第 5 條）',
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
      expect(log.contains('探測資料夾是否存在'), isTrue);
    });

    test('G1-7 _inspect 的 dir.list().first 有呼叫發出事件（acceptance 第 5 條）',
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
      expect(log.contains('讀取資料夾內容'), isTrue);
    });

    test('G1-8 restore() 儲存層拋例外時「呼叫發出」事件仍存在（提早返回路徑）',
        () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(openError: Exception('讀取失敗')),
        logSink: log.call,
      );

      await repo.restore();

      expect(log.contains('還原工作資料夾'), isTrue);
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
        log.indexOfSubstring('開啟資料夾選取面板'),
        log.indexOfSubstring('已選取'),
        log.indexOfSubstring('準備持久化'),
        log.indexOfSubstring('偏好設定儲存已就緒'),
        log.indexOfSubstring('已持久化'),
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
        log.entries.any((e) => e.level == 900 && e.message.contains('持久化失敗')),
        isTrue,
      );
    });

    test('G2-3 寫入拋例外 → ChooseFolderNotRemembered', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: _FakePicker(path: '/tmp/ws').call,
        preferencesPort:
            _FakePreferencesPort(writeError: Exception('寫入失敗：磁碟已滿')),
        directoryProbe: _FakeDirectoryProbe(),
        logSink: log.call,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderNotRemembered>());
      final notRemembered = result as ChooseFolderNotRemembered;
      expect(notRemembered.reason, contains('寫入失敗'));
      expect(
        log.entries.any((e) => e.level == 900),
        isTrue,
      );
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

    test('G2-5 使用者取消 → ChooseFolderCancelled 且不觸碰 SharedPreferences',
        () async {
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
        pickDirectoryPath:
            _FakePicker(error: Exception('MissingPluginException')).call,
        preferencesPort: preferences,
        logSink: log.call,
      );

      final result = await repo.chooseFolder();

      expect(result, isA<ChooseFolderUnavailable>());
      expect((result as ChooseFolderUnavailable).reason, isNotEmpty);
      expect(preferences.calls, isEmpty);
      expect(
        log.entries.any((e) => e.level == 900),
        isTrue,
      );
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
        log.indexOfSubstring('還原工作資料夾'),
        log.indexOfSubstring('偏好設定儲存已就緒'),
        log.indexOfSubstring('無已儲存路徑'),
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
      expect(
        log.entries.any((e) => e.level == 900),
        isTrue,
      );
    });

    // 3b-E 回歸鎖：restore() 例外路徑的 reason 曾直接插值原始例外字串
    // （'$e'），使 _WorkspaceBanner 顯示例外型別名給使用者看。日誌拿例外
    // 細節、reason 拿固定文案，兩者不互相抵扣，此測試鎖住這條界線。
    test('G3-2b restore() 例外路徑的 reason 不含例外型別名（不外露原始例外字串）',
        () async {
      final repo = WorkspaceRepository(
        preferencesPort:
            _FakePreferencesPort(openError: Exception('儲存層失效：磁碟已拔除')),
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
      expect(log.contains('已還原'), isTrue);
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

      final issuedIndex = log.indexOfSubstring('還原工作資料夾');
      final acceptedIndex = log.indexOfSubstring('偏好設定儲存已就緒');
      final resultIndex = log.indexOfSubstring('無已儲存路徑');
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

      expect(log.contains('偏好設定儲存已就緒'), isFalse);
    });

    test('G4-3 file_selector 無受理事件（負向，鎖定裁決 C 的不適用判定）',
        () async {
      final picker = _PickerRecorder();
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        pickDirectoryPath: picker.call,
        logSink: log.call,
      );

      await repo.chooseFolder();

      // 記錄器只回中性 null，chooseFolder 走取消路徑，不觸碰 preferences；
      // picker 相關的日誌只有「呼叫發出」與「使用者取消」兩類，無受理事件。
      expect(log.contains('偏好設定儲存已就緒'), isFalse);
    });
  });

  group('G6｜_inspect 探測結局', () {
    test('G6-1 資料夾不存在 → WorkspaceUnavailable(lastKnownPath: path)',
        () async {
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/missing'),
        directoryProbe: _FakeDirectoryProbe(existsResult: false),
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      expect((result as WorkspaceUnavailable).lastKnownPath, '/tmp/missing');
    });

    test(
        'G6-2 readFirstEntry 拋 FileSystemException → WorkspaceUnavailable '
        '+ level 900 日誌', () async {
      final log = _LogRecorder();
      final repo = WorkspaceRepository(
        preferencesPort: _FakePreferencesPort(readValue: '/tmp/broken'),
        directoryProbe: _FakeDirectoryProbe(
          readFirstEntryError:
              const FileSystemException('讀取失敗', '/tmp/broken'),
        ),
        logSink: log.call,
      );

      final result = await repo.restore();

      expect(result, isA<WorkspaceUnavailable>());
      expect(
        log.entries.any((e) => e.level == 900),
        isTrue,
      );
    });

    // Phase 4b 回歸鎖：_inspect() 的 FileSystemException 分支曾把
    // e.osError?.message（OS 語系文字）塞進 reason；改為固定文案常數後，
    // 用一個帶有明顯可辨識訊息的 OSError 驗證該訊息不會外露到 reason。
    // 比照 G3-2b 的裝置，鎖住 WorkspaceUnavailable.reason 契約的第二條
    // 產生路徑（restore() 例外路徑已由 G3-2b 鎖定）。
    test(
        'G6-2b _inspect 的 FileSystemException 分支 reason 不含 OSError '
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

    test('G6-3 readFirstEntry 拋 StateError（空資料夾）→ WorkspaceReady（不是失敗）',
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
    });

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

/// 日誌記錄器：累積 (訊息, 等級, 錯誤)，供索引順序斷言。
class _LogRecorder {
  final entries = <_LogEntry>[];

  void call(String message, {int? level, Object? error}) {
    entries.add(_LogEntry(message, level, error));
  }

  bool contains(String substring) =>
      entries.any((e) => e.message.contains(substring));

  bool containsAll(List<String> substrings) =>
      substrings.every(contains);

  /// 第一個包含 [substring] 的日誌項索引；找不到回傳 -1。
  int indexOfSubstring(String substring) =>
      entries.indexWhere((e) => e.message.contains(substring));
}

class _LogEntry {
  const _LogEntry(this.message, this.level, this.error);
  final String message;
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

class _FakeDirectoryProbe implements WorkspaceDirectoryProbePort {
  _FakeDirectoryProbe({
    this.existsResult = true,
    this.readFirstEntryError,
  });

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
