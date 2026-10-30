/// 實機字型截圖產生器（路徑 b：integration_test + RepaintBoundary.toImage）。
///
/// 0.5.0-W1-466.2。單獨執行（macOS 一次只能啟動一次 app）：
/// `fvm flutter test integration_test/research/ux_capture.dart -d macos`
///
/// 刻意不帶 `_test` 後綴：合併閘門以 `flutter test integration_test` 掃描目錄，
/// 帶後綴會在同一次執行中啟動第二個 App 而失敗；明確指定檔名時不受後綴影響。
///
/// 每個（版本 x 語系）輸出三個檔案到 `<repo>/build/ux_capture/<variant>/`：
/// - `<locale>.png`          無標記截圖（固定 1280x800）
/// - `<locale>.coords.json`  互動元件座標、DPR、輸出像素、PNG 的 sha256
/// - `<locale>.marked.png`   由座標檔在送圖階段繪製編號框，不改 widget 樹
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:integration_test/integration_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'ux_variants.dart';

/// 要擷取的版本；第二批在此加入壞版本。
final List<UxVariant> kCaptureVariants = [
  kOriginalVariant,
  kLongTitleVariant,
  for (final pair in kUxPairs) ...[pair.original, pair.broken],
];
const List<Locale> kCaptureLocales = [Locale('zh'), Locale('en')];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final variant in kCaptureVariants) {
    for (final locale in kCaptureLocales) {
      if (variant.locales != null && !variant.locales!.contains(locale)) {
        continue;
      }
      for (final destination in AppDestination.values) {
        // 成對變體只擷取自己的畫面。
        if (variant.destination != null && variant.destination != destination) {
          continue;
        }
        // 長標題變體以 wrapApp 取代整個 App，與畫面無關；各畫面輸出會完全相同。
        if (variant == kLongTitleVariant &&
            destination != AppDestination.domain) {
          continue;
        }
        final title = destination == AppDestination.domain
            ? '擷取 ${variant.id}/${locale.languageCode}'
            : '擷取 ${variant.id}/${destination.name}/${locale.languageCode}';
        testWidgets(title, (tester) async {
          final fixture = UxFixture(
            snapshot: 'graph_project_docs_manager',
            locale: locale,
          );
          await fixture.materialize();
          addTearDown(fixture.dispose);
          await _capture(tester, fixture, variant, destination);
        });
      }
    }
  }

  testWidgets('擷取入口：破洞畫面落無法判定破洞時必須紅燈並印出標記', (tester) async {
    final fixture = UxFixture(
      snapshot: 'graph_project_docs_manager',
      locale: const Locale('zh'),
    );
    await fixture.materialize();
    addTearDown(fixture.dispose);
    await expectLater(
      _capture(
        tester,
        fixture,
        kCaptureVariants.first,
        AppDestination.gaps,
        extraOverrides: [
          scanCorpusFnProvider.overrideWithValue(
            ({required fileSystem, required table, required builtinTable}) =>
                throw StateError('E2 注入：掃描輪次拋出例外'),
          ),
        ],
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  // E2 正向對照：違規輸入在真實字型環境下必須被各自的準則判為失敗。
  // 僅 pump 自帶 widget，不寫入 build/ux_capture。
  for (final name in const [
    'textContrast',
    'labeledTapTarget',
    'minTapTarget28',
  ]) {
    testWidgets('準則正向對照：$name 對已知違規輸入必須判失敗', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_violationFixture(name));
      await tester.pump(const Duration(milliseconds: 500));
      final r = await _evaluateGuideline(_guidelineSet()[name]!, tester);
      handle.dispose();
      // ignore: avoid_print
      print('UX_E2 $name passed=${r.passed} reason=${r.reason}');
      expect(r.passed, isFalse, reason: '$name 未攔下已知違規輸入');
    });
  }

  testWidgets('座標蒐集：二維捲動視口外的快取格子不得入檔', (tester) async {
    await tester.pumpWidget(_scrollClipFixture());
    final coords = _collectInteractive(tester);
    final keys = coords.map((e) => e['key']).toSet();
    // 正向對照：視口內（200x100，格 100x50 → 前 2 欄 x 前 2 列）必須在檔內
    expect(keys, containsAll(['cell-0-0', 'cell-0-1', 'cell-1-0', 'cell-1-1']));
    // 已知被捲出視口、僅因快取而建構的格子必須被剔除
    expect(keys, isNot(contains('cell-0-2')));
    expect(keys, isNot(contains('cell-3-0')));
    expect(keys, isNot(contains('cell-4-4')));
    expect(coords.length, 4);
    // 所有矩形不得超出所屬視口（左上 100,100 起 200x100）
    for (final e in coords) {
      final r = (e['rect']! as List).cast<double>();
      expect(r[0] + r[2], lessThanOrEqualTo(300.001));
      expect(r[1] + r[3], lessThanOrEqualTo(200.001));
    }
  });

  testWidgets('座標蒐集：不可被點到的元件（IgnorePointer）不得入檔', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            TextButton(
              key: const ValueKey('live'),
              onPressed: () {},
              child: const Text('a'),
            ),
            IgnorePointer(
              child: TextButton(
                key: const ValueKey('dead'),
                onPressed: () {},
                child: const Text('b'),
              ),
            ),
          ],
        ),
      ),
    );
    final keys = _collectInteractive(tester).map((e) => e['key']).toSet();
    expect(keys, contains('live'));
    expect(keys, isNot(contains('dead')));
  });

  testWidgets('座標蒐集：巢狀可互動元件帶最近可互動祖先的 parent', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            key: const ValueKey('outer'),
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: SizedBox(
              width: 400,
              height: 200,
              child: Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  key: const ValueKey('inner'),
                  onPressed: () {},
                  child: const Text('x'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final coords = _collectInteractive(tester);
    Map<String, Object?> byKey(String k) =>
        coords.firstWhere((e) => e['key'] == k);
    // 正向對照：內層必須指向外層 index；外層無可互動祖先為 null
    expect(byKey('inner')['parent'], byKey('outer')['index']);
    expect(byKey('outer')['parent'], isNull);
    expect(byKey('outer').containsKey('parent'), isTrue);
  });

  testWidgets('座標蒐集：部分超出視口的元件保留未裁切的原始矩形', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 1180,
              top: 10,
              width: 200,
              height: 40,
              child: TextButton(
                key: const ValueKey('wide'),
                onPressed: () {},
                child: const Text('y'),
              ),
            ),
          ],
        ),
      ),
    );
    final e = _collectInteractive(tester).firstWhere((e) => e['key'] == 'wide');
    final rect = (e['rect']! as List).cast<double>();
    final raw = (e['rawRect']! as List).cast<double>();
    // 裁切後矩形不超出視口；原始矩形必須超出視口且寬度為 200
    expect(rect[0] + rect[2], lessThanOrEqualTo(1280.001));
    expect(raw[0] + raw[2], greaterThan(1280));
    expect(raw[2], closeTo(200, 0.001));
  });
}

Widget _scrollClipFixture() => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(100),
      child: SizedBox(
        width: 200,
        height: 100,
        child: TableView.builder(
          columnCount: 5,
          rowCount: 5,
          columnBuilder: (_) =>
              const TableSpan(extent: FixedTableSpanExtent(100)),
          rowBuilder: (_) => const TableSpan(extent: FixedTableSpanExtent(50)),
          cellBuilder: (_, v) => TableViewCell(
            child: TextButton(
              key: ValueKey('cell-${v.row}-${v.column}'),
              onPressed: () {},
              child: const Text('x'),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _capture(
  WidgetTester tester,
  UxFixture fixture,
  UxVariant variant,
  AppDestination destination, {
  List<Override> extraOverrides = const [],
}) async {
  tester.view
    ..devicePixelRatio = kCaptureDpr
    ..physicalSize = kCaptureLogicalSize * kCaptureDpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();
  // 切換方式：以 provider 初值指定畫面（確定性高、不經導覽動畫）。
  // 落地畫面不加 override，維持與本票前相同的 widget 樹。
  final overrides = [
    ...await fixtureOverrides(),
    ...variant.overrides,
    ...extraOverrides,
    if (destination != AppDestination.domain)
      selectedDestinationProvider.overrideWith((ref) => destination),
  ];
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: variant.wrapApp(
        ProviderScope(
          key: UniqueKey(),
          overrides: overrides,
          child: DocsManagerApp(
            locale: fixture.locale,
            repository: UxStubRepository(
              WorkspaceReady(fixture.workspace.path),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );

  _failIfGapsUndeterminable(tester, destination);

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final png = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kCaptureDpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return (
      bytes: data!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  }))!;

  final coords = _collectInteractive(tester);
  final base = '${_repoRoot()}/build/ux_capture/${variant.id}';
  final dir = Directory(
    destination == AppDestination.domain ? base : '$base/${destination.name}',
  )..createSync(recursive: true);
  final name = fixture.locale.languageCode;
  final pngFile = File('${dir.path}/$name.png')..writeAsBytesSync(png.bytes);
  final sha = await _sha256(pngFile.path);
  File('${dir.path}/$name.coords.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'variant': variant.id,
      'destination': destination.name,
      'locale': name,
      'devicePixelRatio': kCaptureDpr,
      'logicalSize': [kCaptureLogicalSize.width, kCaptureLogicalSize.height],
      'outputPixels': [png.width, png.height],
      'sha256': sha,
      'elements': coords,
    }),
  );
  final marked = await tester.runAsync(
    () => drawMarkers(png.bytes, coords, png.width, png.height),
  );
  File('${dir.path}/$name.marked.png').writeAsBytesSync(marked!);

  if (variant.checksGuidelines) {
    await _writeGuidelines(tester, dir, name, variant);
  }

  if (variant.checksGuidelines) {
    _writeAnswers(tester, dir, name, variant);
  }

  expect(png.width, 1280);
  expect(png.height, 800);
  expect(coords, isNotEmpty, reason: '畫面上應至少有一個可互動元件');
  // ignore: avoid_print
  print('UX_CAPTURE ${pngFile.path} sha256=$sha interactive=${coords.length}');
}

/// 0.5.0-W1-466.8：成對變體的正解輸出 `<locale>.answers.json`。
/// 區域題記錄目標的全域 rect（含 key）；數字題記錄正解數值。找不到目標即失敗。
void _writeAnswers(
  WidgetTester tester,
  Directory dir,
  String name,
  UxVariant variant,
) {
  final code = variant.id.split('_').first;
  final answer = <String, Object?>{
    'variant': variant.id,
    'locale': name,
    'answerKey': variant.answerKey,
  };
  switch (code) {
    case 'T-C':
      answer['value'] = _countKeys(tester, 'badge-traceability-broken-');
    case 'K-C':
      answer['value'] = _countKeys(tester, 'badge-tickets-corrupted');
    case 'G-B':
      answer['value'] = _gapsSecondSectionCount(tester);
    case 'G-C':
      answer['targets'] = _targetRects(
        tester,
        (k) => k.startsWith('expander-gaps-'),
      );
    default:
      answer['targets'] = _targetRects(tester, (k) => k == variant.answerKey);
  }
  File('${dir.path}/$name.answers.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(answer));
}

Iterable<(String, Element)> _keyedElements(
  WidgetTester tester,
  bool Function(String key) match,
) sync* {
  for (final e in tester.allElements) {
    final k = e.widget.key;
    if (k is ValueKey && match('${k.value}')) yield ('${k.value}', e);
  }
}

List<Map<String, Object?>> _targetRects(
  WidgetTester tester,
  bool Function(String key) match,
) {
  final out = <Map<String, Object?>>[];
  final seen = <String>{};
  for (final (key, e) in _keyedElements(tester, match)) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (!seen.add('$key|${r.left},${r.top},${r.width},${r.height}')) continue;
    out.add({
      'key': key,
      'rect': [r.left, r.top, r.width, r.height],
    });
  }
  expect(out, isNotEmpty, reason: '找不到正解目標');
  return out;
}

int _countKeys(WidgetTester tester, String prefix) {
  final keys = _keyedElements(
    tester,
    (k) => k.startsWith(prefix),
  ).map((e) => e.$1).toSet();
  expect(keys, isNotEmpty, reason: '找不到正解目標 $prefix');
  return keys.length;
}

double _globalTop(Element e) =>
    (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;

/// 由上往下第二個破洞分組底下的 card-gaps-* 條數。
int _gapsSecondSectionCount(WidgetTester tester) {
  final sections =
      _keyedElements(
          tester,
          (k) => k.startsWith('state-gaps-section-'),
        ).map((e) => e.$2).where((e) => e.renderObject is RenderBox).toList()
        ..sort((a, b) => _globalTop(a).compareTo(_globalTop(b)));
  expect(sections.length, greaterThanOrEqualTo(2), reason: '找不到第二個分組');
  final keys = <String>{};
  void walk(Element e) {
    final k = e.widget.key;
    if (k is ValueKey && '${k.value}'.startsWith('card-gaps-')) {
      keys.add('${k.value}');
    }
    e.visitChildren(walk);
  }

  walk(sections[1]);
  expect(keys, isNotEmpty, reason: '第二個分組找不到條目');
  return keys.length;
}

/// 破洞畫面落「無法判定破洞」時印出標記與可取得的狀態並使擷取失敗。
/// 掃描例外只進 developer.log、不出現在 flutter test stdout，故需在此顯式印出。
void _failIfGapsUndeterminable(
  WidgetTester tester,
  AppDestination destination,
) {
  if (destination != AppDestination.gaps) return;
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DocsManagerApp)),
  );
  final state = container.read(gapReportProvider);
  if (state is! GapReportUndeterminable) return;
  final detail =
      'reason=${state.reason} isScanFailure=${state.isScanFailure} '
      'categories=${state.categories.length} '
      'pathDeclaration=${state.pathDeclaration}';
  // ignore: avoid_print
  print('UX_CAPTURE_GAPS_UNDETERMINABLE $detail');
  fail('破洞畫面落無法判定破洞（$detail）；擷取產物不可信');
}

/// 466.1 三準則集合；擷取與正向對照共用同一份，避免對照測到別的評估器。
Map<String, AccessibilityGuideline> _guidelineSet() => {
  'textContrast': textContrastGuideline,
  'labeledTapTarget': labeledTapTargetGuideline,
  'minTapTarget28': const MinimumTapTargetGuideline(
    size: Size(28, 28),
    link: 'lib/tokens/layout.dart hitTargetMin',
  ),
};

Future<Evaluation> _evaluateGuideline(
  AccessibilityGuideline g,
  WidgetTester tester,
) async => g.evaluate(tester);

/// 已知違規輸入：每條準則一個，各自只違反自己那條。
Widget _violationFixture(String guideline) {
  final Widget body = switch (guideline) {
    'textContrast' => const Text(
      'low contrast sample text',
      style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 14),
    ),
    'labeledTapTarget' => GestureDetector(
      onTap: () {},
      child: const SizedBox(width: 48, height: 48),
    ),
    _ => Semantics(
      label: 'tiny',
      child: GestureDetector(
        onTap: () {},
        child: const SizedBox(width: 20, height: 20),
      ),
    ),
  };
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      // 準則會略過貼著視窗邊緣的節點，故置中而非貼角。
      body: Center(child: body),
    ),
  );
}

/// 466.1 三準則（textContrast／labeledTapTarget／minTapTarget28）與區段間距量測，
/// 結果寫入 `<locale>.guidelines.json`；準則失敗只記錄、不使測試失敗。
Future<void> _writeGuidelines(
  WidgetTester tester,
  Directory dir,
  String name,
  UxVariant variant,
) async {
  final handle = tester.ensureSemantics();
  await tester.pump(const Duration(milliseconds: 500));
  final guidelines = _guidelineSet();
  final results = <String, Object?>{};
  for (final g in guidelines.entries) {
    final r = await _evaluateGuideline(g.value, tester);
    results[g.key] = {
      'passed': r.passed,
      'labels': RegExp(r'label: "([^"]*)"')
          .allMatches(r.reason ?? '')
          .map((m) => m.group(1))
          .toList(),
      'reason': r.reason,
    };
  }
  handle.dispose();
  File('${dir.path}/$name.guidelines.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'variant': variant.id,
      'question': variant.question,
      'answerKey': variant.answerKey,
      'guidelines': results,
      'sectionGaps': _sectionGaps(tester),
    }),
  );
}

/// 相鄰區段（gaps 類別／tickets 主題）之間的實際垂直間距，供 sectionItemGap 定值。
Map<String, Object?> _sectionGaps(WidgetTester tester) {
  final out = <String, Object?>{};
  for (final prefix in const [
    'state-gaps-section-',
    'state-tickets-topic-section-',
  ]) {
    final rects = <(String, Rect)>[];
    for (final e in tester.allElements) {
      final k = e.widget.key;
      if (k is! ValueKey || !'${k.value}'.startsWith(prefix)) continue;
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      rects.add(('${k.value}', box.localToGlobal(Offset.zero) & box.size));
    }
    rects.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    if (rects.isEmpty) continue;
    out[prefix] = [
      for (var i = 0; i < rects.length; i++)
        {
          'key': rects[i].$1,
          'top': rects[i].$2.top,
          'bottom': rects[i].$2.bottom,
          if (i > 0) 'gapAbove': rects[i].$2.top - rects[i - 1].$2.bottom,
        },
    ];
  }
  return out;
}

bool _isInteractive(Widget w) =>
    w is ButtonStyleButton ||
    w is InkResponse ||
    w is TextField ||
    w is Checkbox ||
    w is Switch ||
    w is Radio ||
    w is PopupMenuButton ||
    (w is GestureDetector && w.onTap != null);

/// 蒐集可互動元件的全域矩形（與視口取交集，丟棄不可見者），依樹序編號。
List<Map<String, Object?>> _collectInteractive(WidgetTester tester) {
  final viewport = Offset.zero & kCaptureLogicalSize;
  final seen = <String>{};
  final indexOf = <Element, int>{};
  final out = <Map<String, Object?>>[];
  for (final element in tester.allElements) {
    if (!_isInteractive(element.widget)) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = _clipByAncestors(box, rect.intersect(viewport));
    if (visible.isEmpty) continue;
    final key =
        '${visible.left},${visible.top},${visible.width},${visible.height}';
    // 實際可被點到者才算可見：排除透明切換殘留、被覆蓋、IgnorePointer 內的元件。
    if (!_isHitAtCenter(tester, box, visible)) continue;
    if (!seen.add(key)) continue; // 巢狀包裝（Button 內的 InkWell）同矩形只計一次
    final widgetKey = element.widget.key;
    final index = out.length + 1;
    indexOf[element] = index;
    out.add({
      'index': index,
      'type': element.widget.runtimeType.toString(),
      'key': widgetKey is ValueKey ? '${widgetKey.value}' : null,
      'rect': [visible.left, visible.top, visible.width, visible.height],
      // 未與視口、祖先裁切取交集的原始矩形（供幾何檢查判斷超出視口）。
      'rawRect': [rect.left, rect.top, rect.width, rect.height],
      'parent': _nearestRecordedAncestor(element, indexOf),
    });
  }
  return out;
}

/// 最近的已入檔可互動祖先的 index；無則 null。樹序保證祖先先於後代入檔。
int? _nearestRecordedAncestor(Element element, Map<Element, int> indexOf) {
  int? found;
  element.visitAncestorElements((ancestor) {
    found = indexOf[ancestor];
    return found == null;
  });
  return found;
}

/// 可見矩形中心點做 hit test，路徑上含該 RenderBox 才視為可見。
bool _isHitAtCenter(WidgetTester tester, RenderBox box, Rect visible) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, visible.center, tester.view.viewId);
  return result.path.any((entry) => entry.target == box);
}

/// 逐層套用祖先的繪製裁切（捲動區、圓角卡片），避免回報被裁掉的部分。
Rect _clipByAncestors(RenderBox box, Rect initial) {
  var visible = initial;
  RenderObject child = box;
  var parent = box.parent;
  while (parent != null && !visible.isEmpty) {
    final clip = parent.describeApproximatePaintClip(child);
    // 捲動視口（含 two_dimensional_scrollables）於 paint 時才裁切，
    // describeApproximatePaintClip 不一定回報，故以視口自身邊界補上。
    final bounds = parent is RenderAbstractViewport && parent is RenderBox
        ? Offset.zero & (parent as RenderBox).size
        : null;
    final effective = clip ?? bounds;
    if (effective != null) {
      final matrix = parent.getTransformTo(null);
      visible = visible.intersect(MatrixUtils.transformRect(matrix, effective));
    }
    child = parent;
    parent = parent.parent;
  }
  return visible;
}

/// 送圖階段：由座標檔在無標記 PNG 上繪製編號框（不動 widget 樹）。
Future<List<int>> drawMarkers(
  List<int> pngBytes,
  List<Map<String, Object?>> elements,
  int width,
  int height,
) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
  final base = (await codec.getNextFrame()).image;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(base, Offset.zero, Paint());
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFFE5004C);
  for (final e in elements) {
    final r = (e['rect']! as List).cast<double>();
    final rect = Rect.fromLTWH(r[0], r[1], r[2], r[3]);
    canvas.drawRect(rect, stroke);
    final tp = TextPainter(
      text: TextSpan(
        text: '${e['index']}',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          backgroundColor: Color(0xFFE5004C),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.topLeft);
  }
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<String> _sha256(String path) async {
  final r = await Process.run('/usr/bin/shasum', ['-a', '256', path]);
  if (r.exitCode != 0) throw StateError('shasum 失敗：${r.stderr}');
  return (r.stdout as String).split(' ').first;
}

/// 由執行檔路徑往上找含 pubspec.yaml 的 repo 根（.app 位於 build/ 之下）。
String _repoRoot() {
  var dir = File(Platform.resolvedExecutable).parent.absolute;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('找不到 repo 根（pubspec.yaml）');
    }
    dir = parent;
  }
}
