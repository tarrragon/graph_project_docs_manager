/// 實機字型截圖產生器的共用件：變體介面、fixture 狀態、替身（0.5.0-W1-466.2）。
///
/// 本檔不帶 `_test` 後綴，原因同 `integration_test/domain_view_v050.dart`：
/// macOS 上一次 `flutter test` 只能啟動一次 app，`integration_test/` 下的第二個
/// `_test.dart` 必定啟動失敗。
///
/// 變體只能在測試／研究入口內覆寫（AC 5：不改 lib/）。第一批只有 [kOriginalVariant]；
/// 第二批（AC 4）依 466 已提交的變體目錄在此新增 [UxVariant]，同一題的原設計與
/// 壞版本共用 [UxFixture]，因此可互動元件數的差異只會來自變體本身。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../test/helpers/spec001/corpus_snapshot.dart';

/// 擷取尺寸（logical px）。DPR 固定為 [kCaptureDpr]，輸出像素即 1280x800。
const Size kCaptureLogicalSize = Size(1280, 800);
const double kCaptureDpr = 1.0;

/// 一個可被擷取的設計版本。
///
/// [overrides] 與 [wrapApp] 是變體注入點：前者覆寫 Provider 狀態，後者在 App
/// 外層包裝版面／Theme 覆寫。原設計兩者皆為空操作。
class UxVariant {
  const UxVariant({
    required this.id,
    this.overrides = const [],
    this.wrapApp = _identity,
  });

  final String id;
  final List<Override> overrides;
  final Widget Function(Widget app) wrapApp;
}

Widget _identity(Widget app) => app;

/// 第一批唯一的版本：未經覆寫的原設計。
const UxVariant kOriginalVariant = UxVariant(id: 'original');

/// 同一份 fixture 狀態：凍結快照實體化出的真實工作區 + 固定語系。
class UxFixture {
  UxFixture({required this.snapshot, required this.locale});

  final String snapshot;
  final Locale locale;
  Directory? _workspace;

  Directory get workspace => _workspace!;

  Future<void> materialize() async {
    _workspace = await materializeSnapshotWorkspace(snapshot);
  }

  Future<void> dispose() async {
    await _workspace?.delete(recursive: true);
    _workspace = null;
  }
}

/// 組出固定 fixture 狀態所需的 Provider 覆寫（版本訊號探測就緒）。
Future<List<Override>> fixtureOverrides() async {
  final container = ProviderContainer();
  try {
    final version = await container.read(builtinSchemaVersionProvider.future);
    return [
      frameworkSignalProbeProvider.overrideWithValue(_ReadyProbe(version)),
    ];
  } finally {
    container.dispose();
  }
}

class _ReadyProbe implements FrameworkSignalProbePort {
  const _ReadyProbe(this._version);
  final String _version;

  @override
  Future<String?> readVersion(String workspacePath) async => _version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => true;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async => _version;
}

/// 回傳固定工作區狀態的 repository 替身（不碰 UserDefaults）。
class UxStubRepository implements WorkspaceRepository {
  UxStubRepository(this._state);
  final WorkspaceState _state;

  @override
  Future<WorkspaceState> restore() async => _state;

  @override
  Future<ChooseFolderResult> chooseFolder() async =>
      ChooseFolderSelected(_state);

  @override
  Future<ChooseFolderResult> openPath(String path) async =>
      ChooseFolderSelected(_state);

  @override
  Future<List<RecentProject>> loadRecentProjects() async => const [];

  @override
  Future<bool> addRecentProject(String path) async => true;
}
