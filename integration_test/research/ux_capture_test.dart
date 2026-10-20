/// 實機字型截圖產生器（路徑 b：integration_test + RepaintBoundary.toImage）。
///
/// 0.5.0-W1-466.2。單獨執行（macOS 一次只能啟動一次 app）：
/// `fvm flutter test integration_test/research/ux_capture_test.dart -d macos`
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
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:integration_test/integration_test.dart';

import 'ux_variants.dart';

/// 要擷取的版本；第二批在此加入壞版本。
const List<UxVariant> kCaptureVariants = [kOriginalVariant];
const List<Locale> kCaptureLocales = [Locale('zh'), Locale('en')];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final variant in kCaptureVariants) {
    for (final locale in kCaptureLocales) {
      testWidgets('擷取 ${variant.id}/${locale.languageCode}', (tester) async {
        final fixture = UxFixture(
          snapshot: 'graph_project_docs_manager',
          locale: locale,
        );
        await fixture.materialize();
        addTearDown(fixture.dispose);
        await _capture(tester, fixture, variant);
      });
    }
  }
}

Future<void> _capture(
  WidgetTester tester,
  UxFixture fixture,
  UxVariant variant,
) async {
  tester.view
    ..devicePixelRatio = kCaptureDpr
    ..physicalSize = kCaptureLogicalSize * kCaptureDpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();
  final overrides = [...await fixtureOverrides(), ...variant.overrides];
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
  final dir = Directory('${_repoRoot()}/build/ux_capture/${variant.id}')
    ..createSync(recursive: true);
  final name = fixture.locale.languageCode;
  final pngFile = File('${dir.path}/$name.png')..writeAsBytesSync(png.bytes);
  final sha = await _sha256(pngFile.path);
  File('${dir.path}/$name.coords.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'variant': variant.id,
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

  expect(png.width, 1280);
  expect(png.height, 800);
  expect(coords, isNotEmpty, reason: '畫面上應至少有一個可互動元件');
  // ignore: avoid_print
  print('UX_CAPTURE ${pngFile.path} sha256=$sha interactive=${coords.length}');
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
  final out = <Map<String, Object?>>[];
  for (final element in tester.allElements) {
    if (!_isInteractive(element.widget)) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = _clipByAncestors(box, rect.intersect(viewport));
    if (visible.isEmpty) continue;
    final key = '${visible.left},${visible.top},${visible.width},${visible.height}';
    if (!seen.add(key)) continue; // 巢狀包裝（Button 內的 InkWell）同矩形只計一次
    final widgetKey = element.widget.key;
    out.add({
      'index': out.length + 1,
      'type': element.widget.runtimeType.toString(),
      'key': widgetKey is ValueKey ? '${widgetKey.value}' : null,
      'rect': [visible.left, visible.top, visible.width, visible.height],
    });
  }
  return out;
}

/// 逐層套用祖先的繪製裁切（捲動區、圓角卡片），避免回報被裁掉的部分。
Rect _clipByAncestors(RenderBox box, Rect initial) {
  var visible = initial;
  RenderObject child = box;
  var parent = box.parent;
  while (parent != null && !visible.isEmpty) {
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final matrix = parent.getTransformTo(null);
      visible = visible.intersect(MatrixUtils.transformRect(matrix, clip));
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
