import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('首頁啟動煙霧測試', () {
    testWidgets('App 能啟動並抵達首頁，且無任何 framework 錯誤', (tester) async {
      final errors = await _pumpAppAndCollectErrors(tester);

      expect(
        find.byKey(kLandingPageKey),
        findsOneWidget,
        reason: 'App 啟動後應停在導覽殼的預設落地畫面',
      );
      _expectNoErrors(errors, context: '預設尺寸');
    });

    for (final viewport in kViewports) {
      testWidgets('${viewport.name} (${viewport.size.width.toInt()}'
          'x${viewport.size.height.toInt()}) 下版面無溢位', (tester) async {
        _applyViewport(tester, viewport);

        final errors = await _pumpAppAndCollectErrors(tester);

        expect(find.byKey(kLandingPageKey), findsOneWidget);
        _expectNoErrors(errors, context: viewport.name);
      });
    }
  });

  group('多語系', () {
    // 語系不只是文案問題：不同語言的字串長度差異是版面溢位的常見來源，
    // 因此每個語系都要跑一次完整的錯誤收集，而非只斷言文字內容。
    const cases = <(Locale, String)>[
      (Locale('zh'), '專案文件流'),
      (Locale('en'), 'Docs Flow'),
    ];

    for (final (locale, expectedTitle) in cases) {
      testWidgets('以 ${locale.languageCode} 啟動時顯示對應語系文案', (tester) async {
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
      testWidgets('$label 狀態在最窄視窗下不溢位', (tester) async {
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

}

/// 套用螢幕尺寸，並登記還原，避免污染後續測試。
void _applyViewport(WidgetTester tester, Viewport viewport) {
  tester.view
    ..devicePixelRatio = viewport.dpr
    ..physicalSize = viewport.size * viewport.dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 啟動 App 並攔截這段期間所有 framework 錯誤。
///
/// 這裡刻意接管 [FlutterError.onError]：預設行為會讓錯誤直接把測試打掛，
/// 訊息埋在一長串 stack trace 裡。自行收集後才能在斷言階段輸出
/// 「哪個情境、溢出幾 px」這種可直接行動的訊息。
Future<List<FlutterErrorDetails>> _pumpAppAndCollectErrors(
  WidgetTester tester, {
  Locale? locale,
  WorkspaceRepository? repository,
}) async {
  final captured = <FlutterErrorDetails>[];
  final previousHandler = FlutterError.onError;
  FlutterError.onError = captured.add;
  try {
    await tester.pumpWidget(
      // main() 的 runApp 才包 ProviderScope（見 lib/main.dart）；直接
      // pump DocsManagerApp 時，導覽殼（AppShell 為 ConsumerWidget）需要
      // 自行補上這層祖先，否則 ref.watch 會找不到 ProviderScope 而拋錯。
      ProviderScope(
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
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousHandler;
  }
  return captured;
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
    reason: '[$context] 版面溢位：\n'
        '${overflows.map((e) => e.exceptionAsString()).join('\n')}',
  );

  // overflow 以外的 framework 錯誤（例如 RenderBox was not laid out）
  // 同樣代表版面壞掉，一併擋下。
  expect(
    errors,
    isEmpty,
    reason: '[$context] 啟動期間出現 framework 錯誤：\n'
        '${errors.map((e) => e.exceptionAsString()).join('\n')}',
  );
}

/// 回傳固定狀態的替身，讓版面測試不受真實檔案系統與偏好設定影響。
class _StubWorkspaceRepository implements WorkspaceRepository {
  _StubWorkspaceRepository(this._state);

  final WorkspaceState _state;

  @override
  Future<WorkspaceState> restore() async => _state;

  @override
  Future<WorkspaceState?> chooseFolder() async => _state;
}
