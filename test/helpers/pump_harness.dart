/// 渲染基座：把任一 widget 放進與正式 App 同構的外殼後 pump。
///
/// 外殼由外而內：`ProviderScope(overrides)` → `ScreenUtilInit(kDesignSize)`
/// → `MaterialApp`（本專案 l10n、無 debug banner）→ `MediaQuery`（減少動態
/// 效果開關）→ `Scaffold(body: child)`。與 `lib/main.dart` 的 `DocsManagerApp`
/// 同一順序，元件在測試裡看到的 `.w` / `.sp` 換算、`AppLocalizations`、
/// `Motion.*(context)` 求值結果都與正式執行一致。
///
/// 兩種用法：
///
/// | 情境 | 入口 |
/// |------|------|
/// | 元件／畫面片段（SPEC-004 第 4 章測試點、SPEC-003 §4 逐列） | [pumpHarness] |
/// | 整個 App（導覽殼、切換行為） | [pumpApp] |
///
/// **狀態注入**：畫面級狀態透過 [pumpHarness] 的 `overrides` 參數注入——
/// 把該畫面的狀態 provider `overrideWithValue(<目標狀態>)`，畫面就直接渲染
/// 該狀態，不經真實解析（SPEC-003 §設計約束「狀態注入而非等待真實解析」，
/// 阻擋態與損壞態靠真實解析根本走不到）。元件庫元件依 SPEC-004 §2 為
/// 傳值 + callback 的純 widget，不需 overrides，直接以建構子參數指定變體。
///
/// **時間**：一律用 `tester.pump(Motion.<契約>)` 推進假時鐘，禁止以計時器
/// 量測真實耗時作 pass-fail（test-assertion-design-rules 規則 D1）。[pumpContract] 是這條規則的
/// 具名入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/main.dart';

import 'window_sizes.dart';

/// 預設語系：繁中為樣板語系（CLAUDE.md §6）。
const Locale kDefaultTestLocale = Locale('zh');

/// 兩語系集合（ARB 只有 zh / en），供「每個文字 slot × 兩語系」矩陣展開。
const List<Locale> kTestLocales = [Locale('zh'), Locale('en')];

/// 把 [child] 放進 App 同構外殼後 pump，並把視窗設為 [size]。
///
/// | 參數 | 用途 |
/// |------|------|
/// | `overrides` | `ProviderScope.overrides`——畫面級狀態注入點 |
/// | `size` | 測試視窗尺寸，預設最嚴苛的 [WindowSize.min] |
/// | `locale` | 鎖定語系，預設 zh |
/// | `disableAnimations` | 模擬「減少動態效果」，動畫類 `Motion` 歸零 |
/// | `settle` | `true` 用 `pumpAndSettle`；含無限動畫（spinner、shimmer）的畫面 |
/// |          | 須傳 `false`，否則 settle 永不收斂 |
///
/// 回傳 [ProviderContainer]，測試可用 `container.read(...)` 觀察狀態轉換
/// （例如取消後是否回到未載入態），不需再從 widget tree 挖 `ref`。
Future<ProviderContainer> pumpHarness(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  WindowSize size = WindowSize.min,
  Locale locale = kDefaultTestLocale,
  bool disableAnimations = false,
  bool settle = true,
}) async {
  setWindowSize(tester, size);
  // key 掛在 scope 的直接子節點：containerOf 只往祖先找，掛在 scope 本身
  // 會回報「No ProviderScope found」。
  final chromeKey = UniqueKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: _AppChrome(
        key: chromeKey,
        locale: locale,
        disableAnimations: disableAnimations,
        child: child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return ProviderScope.containerOf(
    tester.element(find.byKey(chromeKey)),
    listen: false,
  );
}

/// 以真實 [DocsManagerApp] 起 App，視窗設為 [size]。
///
/// 供導覽殼與跨畫面切換的測試；單一畫面或元件用 [pumpHarness] 即可，
/// 不必把六頁全部建起來。
Future<void> pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  WindowSize size = WindowSize.min,
  Locale locale = kDefaultTestLocale,
  bool settle = true,
}) async {
  setWindowSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: DocsManagerApp(locale: locale),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// 推進假時鐘 [contract] 這麼久（`Motion` 契約類 token）。
///
/// 與 `tester.pump(duration)` 等價，具名是為了讓「時間斷言走假時鐘」在
/// 測試碼裡可 grep：出現 `pumpContract(Motion.cancelDeadline)` 即表示
/// 該斷言驗的是 SPEC-003 §2.5 的取消時限，而非量測真實耗時。
Future<void> pumpContract(WidgetTester tester, Duration contract) =>
    tester.pump(contract);

/// 斷言上一次 pump 沒有拋出任何例外（含 RenderFlex overflow）。
///
/// flutter_test 把 overflow 報為 `FlutterError` 並在測試結束時判失敗，
/// 本函式把它提前到斷言點，讓紅燈訊息落在「哪個尺寸、哪個變體」的
/// 測試名下，而不是測試尾端的籠統報告。
void expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: '渲染拋出例外（多為溢位）');
}

/// 佈局比較容差：固有高度與實際高度可能落在同一值的浮點誤差兩側，
/// 0.01 邏輯像素遠小於任何可見裁切（最小可見量為 1 邏輯像素）。
const double _kLayoutEpsilon = 0.01;

/// 斷言 [content] 命中的節點沒有被祖先壓得比自身內容所需高度還矮。
///
/// [expectNoOverflow] 對這一類缺陷零鑑別力：`SizedBox(height:)` 給子項的是
/// **緊約束**，子項只會照做並把超出的部分靜默裁切，不拋 `FlutterError`，於是
/// 「不溢位」測試全綠而畫面上字形與圖示被切掉上下緣。本函式改問另一個問題
/// ——這個節點拿到的高度，夠不夠放下它自己的內容（`getMaxIntrinsicHeight`）？
///
/// | 參數 | 說明 |
/// |------|------|
/// | `content` | 被固定高度祖先包住的內容節點，通常是最內層的 `Row` / `Column` |
///
/// [content] 必須落在固定高度容器**之內**：對容器本身求固有高度會被它自己的
/// `additionalConstraints` 夾回同一個值，斷言恆成立而沒有鑑別力。
///
/// 文字裁切在 widget test 裡不會自行顯形——測試字型每個字符高度恰等於
/// `fontSize`，中文字形較高的 ascender／descender 只在實機出現。本斷言驗的是
/// 造成裁切的**結構**（容器高度小於內容固有高度），與字型無關，因此在測試
/// 環境同樣紅燈。
void expectNoVerticalClip(WidgetTester tester, Finder content) {
  final box = tester.renderObject<RenderBox>(content);
  final intrinsicHeight = box.getMaxIntrinsicHeight(box.size.width);
  expect(
    box.size.height,
    greaterThanOrEqualTo(intrinsicHeight - _kLayoutEpsilon),
    // i18n-exempt: 測試紅燈訊息，讀者是開發者，不進 App 的 ARB
    reason:
        '內容固有高度 $intrinsicHeight，實得 ${box.size.height}：' // i18n-exempt
        '祖先的固定高度把內容壓小，超出的部分被靜默裁切', // i18n-exempt
  );
}

/// 與 `DocsManagerApp` 同序的外殼，但 body 由測試提供。
class _AppChrome extends StatelessWidget {
  const _AppChrome({
    super.key,
    required this.locale,
    required this.disableAnimations,
    required this.child,
  });

  final Locale locale;
  final bool disableAnimations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: kDesignSize,
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: app!,
        ),
        home: Scaffold(body: child),
      ),
    );
  }
}
