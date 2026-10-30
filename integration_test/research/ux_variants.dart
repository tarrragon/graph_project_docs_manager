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

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/main.dart' show kDesignSize;
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
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

/// 長標題變體（0.5.0-W1-505）：以真實元件直接組出三處超長文字，不經畫面資料。
///
/// ticket_list 的 SplitRow 左格是 l10n 字串、清單資料為固定假資料，overrides
/// 無法注入長文字，故由 [wrapApp] 以同一套 ScreenUtil／l10n／Theme 外殼承載
/// 真實的 SplitRow.footer、AppTableRow.ticket、ListRow.item，內容區寬度取
/// 1280 減側欄 172。每處各一筆中文無空白長字串與一筆英文長字串。
const UxVariant kLongTitleVariant = UxVariant(
  id: 'long_title',
  wrapApp: _longTitleHarness,
);

const String _zhLong =
    '這是一段沒有任何空白的超長中文標題用來測試固定列高下的呈現方式是換行還是溢出還是被裁切掉了'
    '而且還要更長一些以確保超過任何合理的欄寬上限所以再接續一整段沒有空白的文字'
    '直到寬度遠遠超過一千一百邏輯像素為止這樣每一處元件都會碰到自己的邊界';
const String _enLong =
    'This is an extremely long English title that keeps going well beyond any reasonable column '
    'width so that we can observe wrapping overflow or clipping behavior in a fixed height row';

Widget _longTitleHarness(Widget _) => ScreenUtilInit(
  designSize: kDesignSize,
  minTextAdapt: true,
  splitScreenMode: false,
  builder: (context, child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    home: child,
  ),
  child: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: 1280 - 172,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final text in const [_zhLong, _enLong]) ...[
              SplitRow.footer(
                leading: AppText.singleLine(text),
                trailing: const AppText.singleLine('trailing'),
              ),
              AppTableRow.ticket(
                id: const AppText.singleLine(
                  '0.5.0-W1-505',
                  variant: AppTextVariant.mono,
                ),
                title: AppText.singleLine(text),
                status: const Badge.status(label: 'in_progress'),
                priority: const AppText.singleLine(
                  'P3',
                  variant: AppTextVariant.caption,
                ),
                blockedBy: const AppText.singleLine(
                  '—',
                  variant: AppTextVariant.mono,
                ),
                onTap: () {},
                testKey: Key('long-ticket-${text.length}'),
              ),
              ListRow.item(
                primary: AppText.singleLine(text),
                onTap: () {},
                testKey: Key('long-list-${text.length}'),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    ),
  ),
);

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
