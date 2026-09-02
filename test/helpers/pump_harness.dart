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
