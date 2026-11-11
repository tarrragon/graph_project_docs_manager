// nodeDetailBodyProvider 的本文切分（1.0.0-W3-673.2，SPEC-001 §6〈主欄分隔線上下的內容〉）。
//
// 以含 frontmatter 的暫存檔驅動 provider：回傳值只含 frontmatter 之後的本文；
// 讀取或切分失敗回傳 null，由畫面層改放 `nodeDetailBodyUnavailableMessage`。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/screens/node_detail/node_detail_fixtures.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('node_detail_body_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer containerFor(String path) {
    final c = ProviderContainer(
      overrides: [
        nodeDetailNodesProvider.overrideWithValue({
          'n1': NodeDetailFixture(
            id: 'n1',
            type: 'SPEC',
            status: 'draft',
            title: '標題',
            filePath: path,
            markdown: '',
          ),
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  String? bodyOf(String content) {
    final file = File('${dir.path}/a.md')..writeAsStringSync(content);
    return containerFor(file.path).read(nodeDetailBodyProvider('n1'));
  }

  test('回傳值不含 frontmatter 任何一行，且含本文第一行（正向對照）', () {
    final body = bodyOf('---\ntitle: 標題\nstatus: draft\n---\n本文第一行\n第二行\n');
    expect(body, isNotNull);
    expect(body, contains('本文第一行'));
    expect(body, isNot(contains('title: 標題')));
    expect(body, isNot(contains('status: draft')));
    expect(body, isNot(contains('---')));
  });

  test('frontmatter 之後緊接的 --- 水平線保留', () {
    final body = bodyOf('---\ntitle: t\n---\n---\n水平線之後\n');
    expect(body, startsWith('---'));
    expect(body, contains('水平線之後'));
  });

  test('無 frontmatter 回傳 null', () {
    expect(bodyOf('# 只有本文\n'), isNull);
  });

  test('frontmatter 未閉合回傳 null', () {
    expect(bodyOf('---\ntitle: t\n# 未閉合\n'), isNull);
  });

  test('無法以 UTF-8 解碼回傳 null', () {
    final file = File('${dir.path}/bad.md')
      ..writeAsBytesSync([0x2d, 0x2d, 0x2d, 0x0a, 0xff, 0xfe, 0x0a]);
    expect(containerFor(file.path).read(nodeDetailBodyProvider('n1')), isNull);
  });

  test('檔案不存在回傳 null，不退回節點標題', () {
    final c = containerFor('${dir.path}/missing.md');
    expect(c.read(nodeDetailBodyProvider('n1')), isNull);
  });
}
