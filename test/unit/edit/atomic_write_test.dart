import 'dart:io' show pid;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

/// 需求：[SPEC-009 FR-03] 暫存檔與 rename 的原子寫入（test-design §3
/// R-9～R-12）。
const Set<String> _sequenceKinds = {'read', 'write', 'fsync', 'rename'};

Future<WriteResult> _writeTitle(EditSession session) =>
    session.writeField(field: 'title', newValue: '新標題');

void main() {
  test('R-9 操作序列：讀 W、寫暫存檔、fsync、重讀、rename；暫存檔同目錄', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    expect(await _writeTitle(session), isA<Written>());
    final sequence = [
      for (final op in h.files.ops)
        if (_sequenceKinds.contains(op.kind)) op,
    ];
    expect(
      [for (final op in sequence) op.kind],
      ['read', 'write', 'fsync', 'read', 'rename'],
    );
    final temp = sequence[1].path;
    final dir = h.path.absolute.substring(
      0,
      h.path.absolute.lastIndexOf('/') + 1,
    );
    final name = temp.substring(temp.lastIndexOf('/') + 1);
    expect(temp.startsWith(dir), isTrue);
    expect(temp.substring(dir.length), isNot(contains('/')));
    expect(name, startsWith('.'));
    expect(name, contains('$pid'));
    expect(name, isNot(endsWith('.md')));
    expect(sequence[0].path, h.path.absolute);
    expect(sequence[3].path, h.path.absolute);
    expect(sequence[4].path, '$temp->${h.path.absolute}');
  });

  test('R-10 rename 失敗：ioFailed，目標檔不變，無暫存檔', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.failOp('rename');
    final result = await _writeTitle(session);
    expect(result, isA<IoFailed>());
    expect((result as IoFailed).failure.operation, IoOperation.rename);
    expect(h.target, fixtureBytes(docPlainText));
    expect(h.strayFiles, isEmpty);
  });

  test('R-11 暫存檔寫入或 fsync 失敗：ioFailed，目標檔不變，無暫存檔', () async {
    for (final kind in ['write', 'fsync']) {
      final h = await EditHarness.create();
      final session = await h.begin();
      h.files.failOp(kind);
      expect(await _writeTitle(session), isA<IoFailed>(), reason: kind);
      expect(h.target, fixtureBytes(docPlainText), reason: kind);
      expect(h.strayFiles, isEmpty, reason: kind);
    }
  });

  test('R-12 暫存檔在 rename 前已設為原檔權限 0640', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.modes[h.path.absolute] = 416; // 0o640
    expect(await _writeTitle(session), isA<Written>());
    final kinds = h.files.kinds;
    expect(kinds.indexOf('setMode'), lessThan(kinds.indexOf('rename')));
    expect(h.files.modes[h.path.absolute], 416);
  });
}
