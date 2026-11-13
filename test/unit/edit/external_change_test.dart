import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_corpus_parsed_source.dart';
import '../../helpers/spec009/fake_validator_port.dart';

/// 需求：[SPEC-009 FR-06] 外部改動預警（test-design §3 X-1～X-10）。
/// 觸發來源為 EVT-CORPUS-001；判定來自重讀內容，不讀事件負載。
class _Rig {
  _Rig(this.h, this.session, this.source);

  final EditHarness h;
  final EditSession session;
  final FakeCorpusParsedSource source;

  Future<void> round() async {
    source.emitRound();
    await pumpEventQueue();
  }

  void changeDisk() => h.files.files[h.path.absolute] = flipLastByte(h.target!);

  int get reads => h.files.ops.where((op) => op.kind == 'read').length;
}

Future<_Rig> _start({FakeValidatorPort? validator}) async {
  final h = await EditHarness.create(validator: validator);
  final source = FakeCorpusParsedSource();
  final session = await h.begin(corpusParsed: source);
  return _Rig(h, session, source);
}

void main() {
  test('X-1 內容與 M 不同：重讀一次並轉為預警', () async {
    final r = await _start();
    r.changeDisk();
    await r.round();
    expect(r.reads, 1);
    expect(r.session.externalChangeWarning, isTrue);
  });

  test('X-2 內容與 M 相同：重讀但狀態不變（對照 X-1）', () async {
    final r = await _start();
    await r.round();
    expect(r.reads, 1);
    expect(r.session.externalChangeWarning, isFalse);
  });

  test('X-3 預警後磁碟仍不同：修正 blocked(externallyModified)', () async {
    final r = await _start();
    r.changeDisk();
    await r.round();
    final result = await r.session.writeField(field: 'title', newValue: 'x');
    expect(
      result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
  });

  test('X-4 預警後磁碟改回與 M 相同：修正 written', () async {
    final r = await _start();
    final original = Uint8List.fromList(r.h.target!);
    r.changeDisk();
    await r.round();
    r.h.files.files[r.h.path.absolute] = original;
    final result = await r.session.writeField(field: 'title', newValue: 'x');
    expect(result, isA<Written>());
  });

  test('X-5 無 EVT-CORPUS-001：修正仍判 externallyModified', () async {
    final r = await _start();
    r.changeDisk();
    final result = await r.session.writeField(field: 'title', newValue: 'x');
    expect(result, isA<Blocked>());
    expect(r.session.externalChangeWarning, isFalse);
  });

  test('X-6 預警後放棄並重讀：M 為磁碟內容、預警清除、之後可 written', () async {
    final port = FakeValidatorPort();
    final r = await _start(validator: port);
    await r.session.baselineIdle;
    final callsBefore = port.calls.length;
    r.changeDisk();
    await r.round();
    expect(await r.session.discardAndReload(), isNull);
    expect(r.session.baseline, r.h.target);
    expect(r.session.externalChangeWarning, isFalse);
    await r.session.baselineIdle;
    expect(port.calls.length, greaterThan(callsBefore));
    expect(
      await r.session.writeField(field: 'title', newValue: 'x'),
      isA<Written>(),
    );
  });

  test('X-7 預警期間不發出任何焦點通道請求', () async {
    final r = await _start();
    var requests = 0;
    r.session.observations.listen((_) => requests++);
    r.changeDisk();
    await r.round();
    expect(r.session.externalChangeWarning, isTrue);
    expect(requests, 0);
  });

  test('X-8 重讀得 notFound：視為 W != M，轉為預警', () async {
    final r = await _start();
    r.h.files.files.remove(r.h.path.absolute);
    await r.round();
    expect(r.session.externalChangeWarning, isTrue);
  });

  test('X-9 負載不含該檔、磁碟已變：仍轉預警（判定來自重讀，對照 X-2）', () async {
    final r = await _start();
    r.changeDisk();
    await r.round(); // FakeCorpusParsedSource 的負載恆為空
    expect(r.session.externalChangeWarning, isTrue);
  });

  test('X-10 已預警再收一輪：維持預警且不重複通知', () async {
    final r = await _start();
    var changes = 0;
    r.session.externalChangeWarningChanges.listen((_) => changes++);
    r.changeDisk();
    await r.round();
    await r.round();
    expect(r.session.externalChangeWarning, isTrue);
    expect(changes, 1);
  });

  test('dispose 後不再訂閱 EVT-CORPUS-001', () async {
    final r = await _start();
    await r.session.dispose();
    expect(r.source.hasListener, isFalse);
  });
}
