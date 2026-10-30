// 需求：系統層 §2.1 L4 內部分層，components／app／screens 的 import 方向（0.5.0-W1-213.6）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pkg = 'package:graph_project_docs_manager/';
final _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// 把 import 目標解析為相對 lib/ 的路徑；非本專案目標（dart:、其他套件）回傳 null。
String? resolveTarget(String fromLibPath, String target) {
  if (target.startsWith(_pkg)) return target.substring(_pkg.length);
  if (target.contains(':')) return null;
  final parts = fromLibPath.split('/')..removeLast();
  for (final seg in target.split('/')) {
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (seg != '.') {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// 目錄即層：回傳層名；screens 帶功能目錄（screens/<功能>）。
String? layerOf(String libPath) {
  final seg = libPath.split('/');
  if (seg.first == 'assembly' || libPath == 'main.dart') return 'assembly';
  if (seg.first == 'app' || seg.first == 'components') return seg.first;
  if (seg.first == 'screens') {
    return seg.length > 2 ? 'screens/${seg[1]}' : 'screens';
  }
  return null;
}

/// 判斷 [from] 層 import [to] 層是否違規。
bool isForbidden(String from, String to) {
  if (to == 'assembly') return from != 'assembly';
  if (from == 'components') return to == 'app' || to.startsWith('screens');
  if (from == 'app') return to.startsWith('screens');
  if (from.startsWith('screens/') && to.startsWith('screens/')) {
    return from != to;
  }
  return false;
}

/// 回傳 [source]（位於 lib/[libPath]）中違規的 import 目標。
List<String> violationsIn(String libPath, String source) {
  final from = layerOf(libPath);
  if (from == null) return const [];
  return [
    for (final line in source.split('\n'))
      if (_importPattern.firstMatch(line)?.group(1) case final t?)
        if (resolveTarget(libPath, t) case final r?)
          if (layerOf(r) case final to? when isForbidden(from, to)) t,
  ];
}

Map<String, List<String>> violationsUnderLib(String dir) => {
  for (final f in Directory('lib/$dir').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      if (violationsIn(f.path.substring('lib/'.length), f.readAsStringSync())
          case final bad when bad.isNotEmpty)
        f.path: bad,
};

void main() {
  group('E2 正向對照：每條規則的違規輸入被攔下', () {
    test('規則 1 components 不 import app、screens、組裝根', () {
      const src =
          "import 'package:graph_project_docs_manager/app/scan_round.dart';\n"
          "import '../screens/home/home.dart';\n"
          "import '../assembly/shell.dart' show\n  Shell;\n";
      expect(violationsIn('components/x.dart', src), [
        'package:graph_project_docs_manager/app/scan_round.dart',
        '../screens/home/home.dart',
        '../assembly/shell.dart',
      ]);
    });

    test('規則 2 app 不 import screens 與組裝根', () {
      const src =
          "import 'package:graph_project_docs_manager/screens/a/b.dart';\n"
          "import '../assembly/shell.dart';\n";
      expect(violationsIn('app/x.dart', src), [
        'package:graph_project_docs_manager/screens/a/b.dart',
        '../assembly/shell.dart',
      ]);
    });

    test('規則 3 screens 不 import 組裝根', () {
      const src =
          "import 'package:graph_project_docs_manager/assembly/shell.dart';\n"
          "import '../../assembly/shell.dart';\n";
      expect(violationsIn('screens/a/x.dart', src), [
        'package:graph_project_docs_manager/assembly/shell.dart',
        '../../assembly/shell.dart',
      ]);
    });

    test('規則 4 screens 功能目錄之間不互相 import', () {
      const src =
          "import 'package:graph_project_docs_manager/screens/b/y.dart';\n"
          "import '../b/y.dart';\n"
          "import 'same_feature.dart';\n"
          "import 'sub/deeper.dart';\n";
      expect(violationsIn('screens/a/x.dart', src), [
        'package:graph_project_docs_manager/screens/b/y.dart',
        '../b/y.dart',
      ]);
    });

    test('同目錄不帶路徑的相對 import 依所在目錄判層', () {
      expect(
        resolveTarget('components/x.dart', 'app.dart'),
        'components/app.dart',
      );
      expect(layerOf('components/app.dart'), 'components');
      expect(
        violationsIn('components/x.dart', "import 'badge.dart';\n"),
        isEmpty,
      );
    });

    test('合法方向放行', () {
      const src =
          "import 'package:graph_project_docs_manager/components/badge.dart';\n"
          "import 'package:graph_project_docs_manager/app/scan_round.dart';\n"
          "import 'package:flutter/material.dart';\n";
      expect(violationsIn('screens/a/x.dart', src), isEmpty);
      expect(violationsIn('assembly/shell.dart', src), isEmpty);
    });
  });

  for (final dir in ['components', 'app', 'screens']) {
    test('lib/$dir 無違規 import', () {
      expect(violationsUnderLib(dir), isEmpty);
    });
  }
}
