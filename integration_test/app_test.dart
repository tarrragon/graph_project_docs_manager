import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/services/macos_scan_notifier.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import 'domain_view_v050.dart';
import 'gap_report_declaration_line.dart';

/// App 啟動後的預設落地畫面錨點（導覽殼的預設項目：Domain 視圖）。
///
/// 六項導覽的路由殼掛載後，[HomePage] 不再是進入點；「啟動後抵達某個確定
/// 畫面」這件事改由此錨點斷言。
final Key kLandingPageKey = AppDestination.domain.pageKey;

/// 一組要驗證的螢幕條件。
///
/// [size] 是 logical pixels（即 Flutter 版面配置實際看到的尺寸），
/// [dpr] 只影響點陣資源挑選，對 overflow 與否不構成影響。
typedef Viewport = ({String name, Size size, double dpr});

/// 版型驗收矩陣 —— 「任何版型都不跑版」的具體定義就是這份清單。
///
/// 桌面的驗收範圍是一段**連續區間**（使用者可任意拖曳視窗），不像行動
/// 裝置是一組離散機型。無法窮舉，因此策略是釘住區間的兩個端點加上基準：
/// 下限由 macOS 的 `minSize` 保證不會再更小，上限取常見的外接螢幕。
/// 中間尺寸若要出問題，幾乎都會在下限先爆出來。
///
/// dpr 一律取 2.0（Retina）；它只影響點陣資源挑選，對版面溢位無影響。
const List<Viewport> kViewports = [
  // 視窗下限，與 macOS `MainFlutterWindow.minimumSize` 同步。
  // 這是最嚴苛的條件，水平 overflow 會最先在這裡出現。
  (name: 'desktop-min', size: kMinWindowSize, dpr: 2),
  // 設計稿基準，ScreenUtil 換算係數為 1.0，等同「原尺寸」。
  (name: 'desktop-default', size: kDesignSize, dpr: 2),
  // MacBook Pro 14" 的邏輯解析度，最貼近實際開發與使用情境。
  (name: 'desktop-macbook', size: Size(1512, 982), dpr: 2),
  // 外接螢幕全螢幕。縮放係數 1.5，驗證放大後字級與間距仍不撐破容器。
  (name: 'desktop-large', size: Size(1920, 1080), dpr: 2),
];

/// 原生端 `authorizationStatus` 的合法回傳值
/// （`macos/Runner/AppDelegate.swift` 的 `authorizationString(for:)`，
/// SPEC-003 §2.2）。
const Set<String> kAuthorizationResults = {
  'granted',
  'denied',
  'notDetermined',
};

/// 0.1.0-W1-068 AC5：實機驗證 [MacosExternalOpener] 在沙盒關閉的 debug .app
/// 內直接呼叫，觀察真實 `Process.run('/usr/bin/open', ...)` 的行為。
///
/// 預設關閉（未帶 `RUN_OPEN_PROBE=true` 時兩案例皆 skip），因為此測試會
/// 實際開啟 Finder／文字編輯器視窗，不該在每次整合測試時觸發：
/// `fvm flutter test integration_test/ -d macos --dart-define=RUN_OPEN_PROBE=true`
const bool _runProbe = bool.fromEnvironment('RUN_OPEN_PROBE');

/// 外層測試全部集中在本檔，**新增測試請加在這裡而不是新增檔案**。
///
/// macOS 上一次 `flutter test` 呼叫只能啟動一次 app：`integration_test/` 下放
/// 第二個檔案時，先跑完的那個佔住 app，後跑的必定以
/// `Unable to start the app on the device` 收場（實測 0.1.0-W3-097，與檔案內容
/// 無關，兩種順序皆重現）。`README.md` 記載的
/// `fvm flutter test integration_test/ -d macos` 會因此變紅，而紅燈的原因與被
/// 測功能無關，最容易被誤診。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('首頁啟動煙霧測試', () {
    itWidgets('App 能啟動並抵達首頁，且無任何 framework 錯誤', (tester) async {
      final errors = await _pumpAppAndCollectErrors(tester);

      expect(
        find.byKey(kLandingPageKey),
        findsOneWidget,
        reason: 'App 啟動後應停在導覽殼的預設落地畫面',
      );
      _expectNoErrors(errors, context: '預設尺寸');
    });

    for (final viewport in kViewports) {
      itWidgets('${viewport.name} (${viewport.size.width.toInt()}'
          'x${viewport.size.height.toInt()}) 下版面無溢位', (tester) async {
        _applyViewport(tester, viewport);

        final errors = await _pumpAppAndCollectErrors(tester);

        expect(find.byKey(kLandingPageKey), findsOneWidget);
        _expectNoErrors(errors, context: viewport.name);
      });
    }
  });

  group('錯誤收集器正向對照（E2）', () {
    itWidgets('未捕捉的非同步錯誤被收集且原文出現在失敗訊息', (tester) async {
      const marker = 'W1-442 故意拋出的非同步錯誤';
      final errors = await _pumpAppAndCollectErrors(
        tester,
        afterPump: () => Future<void>(() => throw StateError(marker)),
      );

      expect(
        () => _expectNoErrors(errors, context: '正向對照'),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            contains(marker),
          ),
        ),
      );
    });

    // 0.5.0-W1-479.1 E2：永不收斂的畫面須在逾時內以步驟名稱失敗，而非空等。
    itWidgets('永不收斂的畫面在步驟逾時內失敗並指名步驟', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: CircularProgressIndicator(),
        ),
      );

      Object? caught;
      try {
        await settleGuarded(
          tester,
          'W1-479.1 正向對照步驟',
          timeout: const Duration(seconds: 2),
        );
      } on TestFailure catch (e) {
        caught = e;
      }
      expect(
        caught,
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('W1-479.1 正向對照步驟'),
        ),
        reason: '永不收斂時 settleGuarded 必須失敗且訊息含步驟名稱',
      );
    });
  });

  group('多語系', () {
    // 語系不只是文案問題：不同語言的字串長度差異是版面溢位的常見來源，
    // 因此每個語系都要跑一次完整的錯誤收集，而非只斷言文字內容。
    const cases = <(Locale, String)>[
      (Locale('zh'), '專案文件流'),
      (Locale('en'), 'Docs Flow'),
    ];

    for (final (locale, expectedTitle) in cases) {
      itWidgets('以 ${locale.languageCode} 啟動時顯示對應語系文案', (tester) async {
        final errors = await _pumpAppAndCollectErrors(tester, locale: locale);

        expect(
          find.text(expectedTitle),
          findsOneWidget,
          reason: 'AppBar 標題應為 $locale 的在地化字串',
        );
        _expectNoErrors(errors, context: 'locale=$locale');
      });
    }
  });

  group('工作資料夾狀態', () {
    // 三種狀態的文案長度差異很大（尤其錯誤訊息由原生端提供、長度不可控），
    // 因此每種狀態都要在最窄視窗下驗證一次。
    final cases = <String, WorkspaceState>{
      '未選取': const WorkspaceUnset(),
      '已授權': const WorkspaceReady('/Users/someone/Documents/專案文件'),
      '授權失效': const WorkspaceUnavailable(
        lastKnownPath: '/Volumes/外接磁碟/專案文件',
        reason: '先前的資料夾授權已失效，且該磁碟目前未掛載',
      ),
    };

    cases.forEach((label, state) {
      itWidgets('$label 狀態在最窄視窗下不溢位', (tester) async {
        _applyViewport(tester, kViewports.first);

        final errors = await _pumpAppAndCollectErrors(
          tester,
          repository: _StubWorkspaceRepository(state),
        );

        expect(find.byKey(kLandingPageKey), findsOneWidget);
        _expectNoErrors(errors, context: '工作資料夾=$label');
      });
    });
  });

  group('DomainReady（內建矩陣）', () {
    // 資料來源：gate 讀訊號探測替身（_ReadyFrameworkSignalProbe，恆判 DomainReady）；
    // 矩陣建圖經共用掃描輪次（ScanRound）讀 systemTemp 下的真實工作區，
    // 內含內建版本的 tracking_schema.json 與最小 docs 語料。
    // 不涵蓋真實磁碟上的 gate 偵測（見 0.3.3-W3-383 Problem Analysis）。
    for (final viewport in kViewports) {
      itWidgets('${viewport.name} (${viewport.size.width.toInt()}'
          'x${viewport.size.height.toInt()}) 矩陣狀態無溢位', (tester) async {
        _applyViewport(tester, viewport);
        final builtinVersion = await _readBuiltinSchemaVersion();
        final workspace = await _createReadyWorkspace();
        addTearDown(() => workspace.delete(recursive: true));

        final errors = await _pumpAppAndCollectErrors(
          tester,
          repository: _StubWorkspaceRepository(WorkspaceReady(workspace.path)),
          overrides: [
            frameworkSignalProbeProvider.overrideWithValue(
              _ReadyFrameworkSignalProbe(builtinVersion),
            ),
          ],
        );

        expect(
          find.byKey(const Key('state-domain-matrix')),
          findsOneWidget,
          reason: '[${viewport.name}] 應渲染矩陣而非阻擋態',
        );
        _expectNoErrors(errors, context: 'DomainReady ${viewport.name}');
      });
    }
  });

  group('scan_notifier 原生端接線', () {
    const MethodChannel channel = MethodChannel(scanNotifierChannelName);

    itWidgets('withdraw 有原生端回應（handler 已註冊）', (tester) async {
      final error = await _invokeAndCaptureError(
        () => channel.invokeMethod<void>('withdraw'),
      );

      expect(
        error,
        isNot(isA<MissingPluginException>()),
        reason:
            '原生端未註冊 $scanNotifierChannelName 的 handler；'
            '檢查 macos/Runner/AppDelegate.swift 的 channel 註冊時機',
      );
      expect(error, isNull, reason: 'withdraw 不應拋出任何例外');
    });

    itWidgets('authorizationStatus 回傳真實授權狀態而非接線失敗', (tester) async {
      String? status;
      final error = await _invokeAndCaptureError(() async {
        status = await channel.invokeMethod<String>('authorizationStatus');
      });

      expect(
        error,
        isNot(isA<MissingPluginException>()),
        reason: '授權查詢打不到原生端；這是接線缺陷，不是 SPEC-003 §2.2 的 denied 降級',
      );
      expect(error, isNull, reason: 'authorizationStatus 不應拋出任何例外');
      expect(
        status,
        isIn(kAuthorizationResults),
        reason: '原生端回傳值須為 AppDelegate.authorizationString(for:) 的三個值之一',
      );
    });
  });

  group('MacosExternalOpener 實機探測（AC5）', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('external_opener_probe_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    itWidgets('開啟真實檔案', (tester) async {
      final file = File('${tempDir.path}/probe.txt')
        ..writeAsStringSync('probe');
      final opener = MacosExternalOpener();

      final result = await opener.open(file.path);

      // 例外：integration test 的 stdout 是唯一能被讀回主線程的通道，
      // 用來把觀測到的真實結果值帶出測試進程供 PM 記錄。
      // ignore: avoid_print
      print('PROBE file result=$result');

      expect(result, ExternalOpenResult.opened);
    }, skip: !_runProbe);

    itWidgets('開啟真實目錄', (tester) async {
      final opener = MacosExternalOpener();

      final result = await opener.open(tempDir.path);

      // 例外：同上，integration test 的 stdout 是唯一能被讀回的通道。
      // ignore: avoid_print
      print('PROBE dir result=$result');

      expect(result, ExternalOpenResult.opened);
    }, skip: !_runProbe);
  });

  // 外圈 IT-D1～IT-D4：測試本體在無 `_test` 後綴的兩檔（同一次 flutter test
  // 只能啟動一次 app，不能另立第二個 `_test.dart`），由此處註冊。
  registerDomainViewV050Tests(_openSnapshotWorkspace);
  registerGapReportDeclarationLineTests(_openSnapshotWorkspace);
}

/// 以 [workspace]（凍結快照實體化的真實工作區）為已授權工作區啟動 App。
///
/// 只替換資料夾選擇器（[_StubWorkspaceRepository.restore]）與 gate 的版本訊號
/// 探測（快照無 `VERSION` 檔）；掃描、建圖、Layout 皆為真實實作。
Future<void> _openSnapshotWorkspace(
  WidgetTester tester,
  Directory workspace, {
  Locale? locale,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  _applyViewport(tester, kViewports.last);
  final builtinVersion = await _readBuiltinSchemaVersion();
  final errors = await _pumpAppAndCollectErrors(
    tester,
    locale: locale,
    repository: _StubWorkspaceRepository(WorkspaceReady(workspace.path)),
    overrides: [
      frameworkSignalProbeProvider.overrideWithValue(
        _ReadyFrameworkSignalProbe(builtinVersion),
      ),
      ...overrides,
    ],
    settle: settle,
  );
  if (settle) _expectNoErrors(errors, context: '外圈 ${workspace.path}');
}

/// 執行 [action] 並回傳它拋出的例外；沒有例外時回傳 `null`。
///
/// 直接 `await` 讓例外冒出來也能讓測試變紅，但失敗訊息會是原始的
/// `MissingPluginException` 堆疊，讀者得自行推斷「這代表原生端沒接線」。
/// 捕捉後交給 `expect` 的 `reason` 陳述，是為了讓紅燈直接說出診斷結論。
Future<Object?> _invokeAndCaptureError(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } catch (error) {
    return error;
  }
}

/// 套用螢幕尺寸，並登記還原，避免污染後續測試。
void _applyViewport(WidgetTester tester, Viewport viewport) {
  tester.view
    ..devicePixelRatio = viewport.dpr
    ..physicalSize = viewport.size * viewport.dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 啟動後 settle，走 [settleGuarded]：涵蓋「不送幀」（Future 逾時）與
/// 「永不收斂」（無限進度動畫）兩種卡住形態，失敗訊息帶步驟名稱。
Future<void> _settleOrFailFast(WidgetTester tester) =>
    settleGuarded(tester, '啟動後 settle（疑似停在無限進度動畫或不送幀）');

/// 啟動 App 並攔截這段期間所有 framework 錯誤。
///
/// 這裡刻意接管 [FlutterError.onError]：預設行為會讓錯誤直接把測試打掛，
/// 訊息埋在一長串 stack trace 裡。自行收集後才能在斷言階段輸出
/// 「哪個情境、溢出幾 px」這種可直接行動的訊息。
Future<List<FlutterErrorDetails>> _pumpAppAndCollectErrors(
  WidgetTester tester, {
  Locale? locale,
  WorkspaceRepository? repository,
  List<Override> overrides = const [],
  void Function()? afterPump,
  bool settle = true,
}) async {
  final captured = <FlutterErrorDetails>[];
  final previousHandler = FlutterError.onError;
  final previousDispatcherHandler = PlatformDispatcher.instance.onError;
  FlutterError.onError = captured.add;
  PlatformDispatcher.instance.onError = (error, stack) {
    captured.add(FlutterErrorDetails(exception: error, stack: stack));
    return true;
  };
  try {
    // 未捕捉的非同步錯誤不經 FlutterError.onError，會直達 test zone 的
    // handleUncaughtError：binding 先中止測試，再報自身的
    // _pendingExceptionDetails assert，原文丟失。把 App 的整段執行放進子
    // zone，錯誤改由此處收集，binding 就不會接手。
    await runZonedGuarded(
      () => _pumpAndSettleApp(
        tester,
        locale,
        repository,
        overrides,
        afterPump,
        settle,
      ),
      (error, stack) =>
          captured.add(FlutterErrorDetails(exception: error, stack: stack)),
    );
  } finally {
    _drainPendingExceptions(tester, captured);
    FlutterError.onError = previousHandler;
    PlatformDispatcher.instance.onError = previousDispatcherHandler;
  }
  return captured;
}

Future<void> _pumpAndSettleApp(
  WidgetTester tester,
  Locale? locale,
  WorkspaceRepository? repository,
  List<Override> overrides,
  void Function()? afterPump,
  bool settle,
) async {
  {
    await tester.pumpWidget(
      // main() 的 runApp 才包 ProviderScope（見 lib/main.dart）；直接
      // pump DocsManagerApp 時，導覽殼（AppShell 為 ConsumerWidget）需要
      // 自行補上這層祖先，否則 ref.watch 會找不到 ProviderScope 而拋錯。
      ProviderScope(
        // 同一案例內重開 App（換工作區／語系）須是全新狀態；同型別同位置的
        // ProviderScope 會沿用既有 container，新的 overrides 與 repository 不生效。
        key: UniqueKey(),
        overrides: overrides,
        child: DocsManagerApp(
          locale: locale,
          // 預設也注入替身：真實 repository 會讀寫使用者的 UserDefaults，
          // 讓測試結果取決於機器上的殘留狀態。
          repository:
              repository ?? _StubWorkspaceRepository(const WorkspaceUnset()),
        ),
      ),
    );
    // ScreenUtilInit 首幀只做量測，需再 settle 一次才會渲染出真正的版面。
    afterPump?.call();
    // settle:false 供需觀察「進行中」中間態的案例（如 ITD4-A4 掃描中）。
    if (settle) await _settleOrFailFast(tester);
  }
}

/// 取回 binding 已接管的未捕捉錯誤（zone 層），併入收集結果以保留原文。
void _drainPendingExceptions(
  WidgetTester tester,
  List<FlutterErrorDetails> captured,
) {
  Object? pending;
  while ((pending = tester.takeException()) != null) {
    final isNew = !captured.any((d) => identical(d.exception, pending));
    if (isNew) captured.add(FlutterErrorDetails(exception: pending!));
  }
}

/// overflow 的錯誤訊息一律形如 "A RenderFlex overflowed by 12 pixels"。
bool _isOverflow(FlutterErrorDetails details) =>
    details.exceptionAsString().contains('overflowed');

void _expectNoErrors(
  List<FlutterErrorDetails> errors, {
  required String context,
}) {
  final overflows = errors.where(_isOverflow).toList();
  expect(
    overflows,
    isEmpty,
    reason:
        '[$context] 版面溢位：\n'
        '${overflows.map((e) => e.exceptionAsString()).join('\n')}',
  );

  // overflow 以外的 framework 錯誤（例如 RenderBox was not laid out）
  // 同樣代表版面壞掉，一併擋下。
  expect(
    errors,
    isEmpty,
    reason:
        '[$context] 啟動期間出現 framework 錯誤：\n'
        '${errors.map((e) => e.exceptionAsString()).join('\n')}',
  );
}

/// 讀取內建型別表版本（與 gate 偵測同源：builtinSchemaVersionProvider）。
Future<String> _readBuiltinSchemaVersion() async {
  final container = ProviderContainer();
  try {
    return await container.read(builtinSchemaVersionProvider.future);
  } finally {
    container.dispose();
  }
}

/// 建立可建圖的暫存工作區：內建型別表副本 + 最小 docs 語料。
Future<Directory> _createReadyWorkspace() async {
  final dir = await Directory.systemTemp.createTemp('domain_ready_');
  final schema = await rootBundle.loadString(
    builtinTrackingSchemaAssetPath,
    cache: false,
  );
  final schemaFile = File('${dir.path}/$projectSchemaRelativePath');
  await schemaFile.create(recursive: true);
  await schemaFile.writeAsString(schema);
  final doc = File('${dir.path}/docs/proposals/PROP-001.md');
  await doc.create(recursive: true);
  await doc.writeAsString(
    '---\nid: PROP-001\ntitle: fixture\n---\n\n# fixture\n',
  );
  return dir;
}

/// 訊號皆齊備且 JSON 版本等於內建版本的探測替身，使 gate 判 DomainReady。
class _ReadyFrameworkSignalProbe implements FrameworkSignalProbePort {
  const _ReadyFrameworkSignalProbe(this._version);

  final String _version;

  @override
  Future<String?> readVersion(String workspacePath) async => _version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => true;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async => _version;
}

/// 回傳固定狀態的替身，讓版面測試不受真實檔案系統與偏好設定影響。
class _StubWorkspaceRepository implements WorkspaceRepository {
  _StubWorkspaceRepository(this._state);

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
