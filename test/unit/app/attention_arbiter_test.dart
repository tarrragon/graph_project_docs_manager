import 'package:graph_project_docs_manager/app/attention_arbiter.dart';
import 'package:graph_project_docs_manager/app/attention_level.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClock {
  DateTime now = DateTime(2026, 1, 1);
  void advance(Duration d) => now = now.add(d);
}

typedef _Record = ({
  AttentionArbiterLogEvent event,
  Map<String, Object?> fields,
  int? level,
});

class _Recorder {
  final List<_Record> records = [];

  void sink(
    AttentionArbiterLogEvent event,
    Map<String, Object?> fields, {
    int? level,
  }) {
    records.add((event: event, fields: Map.of(fields), level: level));
  }

  List<_Record> of(AttentionArbiterLogEvent event) =>
      records.where((r) => r.event == event).toList();

  _Record singleOf(AttentionArbiterLogEvent event) {
    final found = of(event);
    expect(found.length, 1, reason: '期望恰一筆 $event，實得 ${found.length}');
    return found.single;
  }
}

void expectSevenFields(_Record record) {
  final fields = record.fields;
  expect(fields.containsKey('requestId'), isTrue);
  expect(fields.containsKey('arrival'), isTrue);
  expect(fields.containsKey('level'), isTrue);
  expect(fields.containsKey('channel'), isTrue);
  expect(fields.containsKey('decision') || fields.containsKey('reason'), isTrue);
  expect(fields.containsKey('occupancy'), isTrue);
  expect(fields.containsKey('deadlineRemaining'), isTrue);
  final occupancy = fields['occupancy'] as Map;
  expect(occupancy.keys.toSet(), {'inFlight', 'queueDepth', 'oldestAge'});
  expect(fields['channel'], 'userFocus');
  expect(occupancy['queueDepth'], 0);
}

void main() {
  late _FakeClock clock;
  late _Recorder recorder;
  late AttentionArbiterImpl arbiter;
  late List<AttentionConsumed> consumedLog;

  AttentionRequest req(
    String id, {
    AttentionLevel level = AttentionLevel.discardable,
    AttentionArrival arrival = AttentionArrival.waiting,
    AttentionSource source = AttentionSource.diagnostics,
    AttentionLevel? parentLevel,
    Duration? deadline,
  }) {
    return AttentionRequest(
      id: id,
      level: level,
      arrival: arrival,
      source: source,
      parentLevel: parentLevel,
      deadline: deadline,
    );
  }

  AttentionHandle hold(
    AttentionRequest request, {
    Duration? naturalLifespan,
  }) {
    final decision = arbiter.request(request);
    expect(decision, isA<AttentionAccepted>());
    final handle = (decision as AttentionAccepted).handle;
    arbiter.presented(handle, naturalLifespan: naturalLifespan);
    return handle;
  }

  void setUp2() {
    arbiter.dispose();
    clock = _FakeClock();
    recorder = _Recorder();
    arbiter = AttentionArbiterImpl(now: () => clock.now, logSink: recorder.sink);
    consumedLog = [];
    arbiter.consumed.listen(consumedLog.add);
  }

  setUp(() {
    clock = _FakeClock();
    recorder = _Recorder();
    arbiter = AttentionArbiterImpl(now: () => clock.now, logSink: recorder.sink);
    consumedLog = [];
    arbiter.consumed.listen(consumedLog.add);
  });

  tearDown(() {
    arbiter.dispose();
  });

  group('G-A 空通道與持有者生命週期', () {
    test('T-1 空通道接受等待型', () {
      expect(arbiter.holder, isNull);
      expect(recorder.records, isEmpty);
      expect(consumedLog, isEmpty);

      final decision = arbiter.request(
        req(
          'r1',
          level: AttentionLevel.discardable,
          arrival: AttentionArrival.waiting,
          source: AttentionSource.diagnostics,
          deadline: Motion.snackBar,
        ),
      );

      expect(decision, isA<AttentionAccepted>());
      final accepted = decision as AttentionAccepted;
      expect(accepted.preempted, isNull);
      expect(accepted.sameLevelReplace, isFalse);
      expect(accepted.handle.requestId, 'r1');
      expect(accepted.handle.level, AttentionLevel.discardable);
      expect(accepted.handle.arrival, AttentionArrival.waiting);
      expect(accepted.handle.source, AttentionSource.diagnostics);
      expect(accepted.handle.acceptedAt, clock.now);

      expect(arbiter.holder!.handle.requestId, 'r1');
      expect(arbiter.holder!.presentedAt, isNull);
      expect(arbiter.holder!.naturalLifespan, isNull);

      final record = recorder.singleOf(AttentionArbiterLogEvent.accepted);
      expect(record.fields['requestId'], 'r1');
      expect(record.fields['arrival'], AttentionArrival.waiting);
      expect(record.fields['level'], AttentionLevel.discardable);
      expect(record.fields['channel'], 'userFocus');
      expect(record.fields['decision'], 'accepted');
      expect(record.fields['occupancy'], {
        'inFlight': 0,
        'queueDepth': 0,
        'oldestAge': null,
      });
      expect(record.fields['deadlineRemaining'], Motion.snackBar);
      expect(
        record.fields['deadlineAssigned'] == null ||
            record.fields['deadlineAssigned'] == false,
        isTrue,
      );
      expect(consumedLog, isEmpty);
    });

    test('T-2 空通道接受自發型', () {
      final decision = arbiter.request(
        req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
      );
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).preempted, isNull);
      expect(arbiter.holder!.handle.requestId, 'r1');
      final record = recorder.singleOf(AttentionArbiterLogEvent.accepted);
      expect(record.fields['arrival'], AttentionArrival.spontaneous);
      expect(record.level == null || record.level != 900, isTrue);
    });

    test('T-3 呈現、消費、訊號', () async {
      final handle = hold(
        req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
        naturalLifespan: Motion.snackBar,
      );
      expect(arbiter.holder!.presentedAt, clock.now);
      expect(arbiter.holder!.naturalLifespan, Motion.snackBar);

      clock.advance(Motion.feedback);
      arbiter.release(handle, AttentionReleaseReason.expired);
      await pumpEventQueue();

      expect(arbiter.holder, isNull);
      expect(consumedLog.length, 1);
      expect(consumedLog.single.handle.requestId, 'r1');
      expect(consumedLog.single.reason, AttentionReleaseReason.expired);
      expect(consumedLog.single.at, clock.now);

      final released = recorder.of(AttentionArbiterLogEvent.released);
      expect(released.length, 1);
      expect(released.single.fields['requestId'], 'r1');
      expect(released.single.fields['reason'], 'expired');
      expectSevenFields(released.single);
    });

    test('T-4 序列重借合法', () {
      final handle = hold(
        req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
      );
      arbiter.release(handle, AttentionReleaseReason.responded);
      expect(arbiter.holder, isNull);

      final decision = arbiter.request(
        req(
          'r2',
          level: AttentionLevel.discardable,
          arrival: AttentionArrival.spontaneous,
          parentLevel: AttentionLevel.discardable,
        ),
      );
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).preempted, isNull);
      expect(recorder.of(AttentionArbiterLogEvent.heldAndRequested), isEmpty);
      expect(arbiter.holder!.handle.requestId, 'r2');
    });

    test('T-5 接受後未呈現', () async {
      final decision = arbiter.request(req('r1'));
      final handle = (decision as AttentionAccepted).handle;
      expect(arbiter.holder!.presentedAt, isNull);

      arbiter.release(handle, AttentionReleaseReason.notPresented);
      await pumpEventQueue();

      expect(arbiter.holder, isNull);
      expect(consumedLog.length, 1);
      expect(consumedLog.single.reason, AttentionReleaseReason.notPresented);
      final released = recorder.singleOf(AttentionArbiterLogEvent.released);
      expect(released.fields['reason'], 'notPresented');
    });

    test('T-6 非持有者的回報只留痕不改狀態', () async {
      // 列 1：release
      final r1Handle = hold(req('r1'));
      arbiter.release(r1Handle, AttentionReleaseReason.responded);
      await pumpEventQueue();
      final r2Handle = hold(req('r2'));
      final consumedBefore = consumedLog.length;

      arbiter.release(r1Handle, AttentionReleaseReason.dismissed);
      await pumpEventQueue();

      expect(arbiter.holder!.handle.requestId, 'r2');
      final releasedNonHolderRelease = recorder
          .of(AttentionArbiterLogEvent.releasedNonHolder)
          .where((r) => r.fields['op'] == 'release')
          .single;
      expect(releasedNonHolderRelease.fields['requestId'], 'r1');
      expect(releasedNonHolderRelease.level, 900);
      expect(consumedLog.length, consumedBefore);

      // 列 2：presented
      arbiter.presented(r1Handle, naturalLifespan: Motion.snackBar);
      await pumpEventQueue();
      expect(arbiter.holder!.handle.requestId, 'r2');
      expect(arbiter.holder!.presentedAt, r2Handle.acceptedAt);
      final releasedNonHolderPresented = recorder
          .of(AttentionArbiterLogEvent.releasedNonHolder)
          .where((r) => r.fields['op'] == 'presented')
          .single;
      expect(releasedNonHolderPresented.fields['op'], 'presented');
      expect(releasedNonHolderPresented.level, 900);
    });

    test('T-7 naturalLifespan 零或負值視同 null', () {
      for (final value in [Duration.zero, const Duration(seconds: -1)]) {
        setUp2();
        final handle = arbiter.request(
              req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
            )
            as AttentionAccepted;
        arbiter.presented(handle.handle, naturalLifespan: value);
        clock.advance(const Duration(days: 1));
        final decision = arbiter.request(
          req('r2', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
        );

        expect(arbiter.holder!.naturalLifespan, isNull);
        final presentedRecord = recorder.singleOf(AttentionArbiterLogEvent.presented);
        expect(presentedRecord.fields['naturalLifespanRaw'], value);
        expect(recorder.of(AttentionArbiterLogEvent.expired), isEmpty);
        expect(decision, isA<AttentionAccepted>());
        expect((decision as AttentionAccepted).preempted!.requestId, 'r1');
        expect(decision.sameLevelReplace, isTrue);
      }
    });

    test('T-8 deadline 的兩種形態', () {
      arbiter.request(req('r1', deadline: null));
      final record1 = recorder.singleOf(AttentionArbiterLogEvent.accepted);
      expect(record1.fields.containsKey('deadlineRemaining'), isTrue);
      expect(record1.fields['deadlineRemaining'], isNull);
      expect(record1.fields['deadlineAssigned'], isTrue);

      setUp2();
      arbiter.request(req('r1', deadline: Motion.snackBarWithAction));
      final record2 = recorder.singleOf(AttentionArbiterLogEvent.accepted);
      expect(record2.fields['deadlineRemaining'], Motion.snackBarWithAction);
      expect(
        record2.fields['deadlineAssigned'] == null ||
            record2.fields['deadlineAssigned'] == false,
        isTrue,
      );
    });
  });

  group('G-B 裁決表 2.4', () {
    test('T-9 高級別搶佔低級別（三列）', () async {
      final cases = <(AttentionLevel, AttentionArrival, AttentionLevel, AttentionArrival, AttentionSource)>[
        (
          AttentionLevel.discardable,
          AttentionArrival.waiting,
          AttentionLevel.undroppable,
          AttentionArrival.spontaneous,
          AttentionSource.schema,
        ),
        (
          AttentionLevel.discardable,
          AttentionArrival.waiting,
          AttentionLevel.mustLeaveTrace,
          AttentionArrival.spontaneous,
          AttentionSource.diagnostics,
        ),
        (
          AttentionLevel.mustLeaveTrace,
          AttentionArrival.spontaneous,
          AttentionLevel.undroppable,
          AttentionArrival.waiting,
          AttentionSource.workspace,
        ),
      ];

      for (final c in cases) {
        setUp2();
        hold(req('low', level: c.$1, arrival: c.$2), naturalLifespan: Motion.snackBar);

        final decision = arbiter.request(
          req('high', level: c.$3, arrival: c.$4, source: c.$5),
        );
        await pumpEventQueue();

        expect(decision, isA<AttentionAccepted>());
        final accepted = decision as AttentionAccepted;
        expect(accepted.preempted!.requestId, 'low');
        expect(accepted.sameLevelReplace, isFalse);
        expect(accepted.handle.requestId, 'high');
        expect(arbiter.holder!.handle.requestId, 'high');
        expect(arbiter.holder!.presentedAt, isNull);

        final preemptedRecord = recorder.singleOf(AttentionArbiterLogEvent.preempted);
        expect(preemptedRecord.fields['requestId'], 'low');
        expect(preemptedRecord.fields['reason'], 'preempted');
        final acceptedRecord = recorder
            .of(AttentionArbiterLogEvent.accepted)
            .where((r) => r.fields['requestId'] == 'high')
            .single;
        expect(
          recorder.records.indexOf(preemptedRecord) <
              recorder.records.indexOf(acceptedRecord),
          isTrue,
        );
        expect(recorder.of(AttentionArbiterLogEvent.sameLevelReplaced), isEmpty);
        expect(consumedLog.length, 1);
        expect(consumedLog.single.handle.requestId, 'low');
        expect(consumedLog.single.reason, AttentionReleaseReason.preempted);
      }
    });

    test('T-10 同級別取代（三列）', () async {
      final cases = <(AttentionLevel, AttentionArrival, AttentionArrival)>[
        (AttentionLevel.discardable, AttentionArrival.waiting, AttentionArrival.spontaneous),
        (AttentionLevel.mustLeaveTrace, AttentionArrival.spontaneous, AttentionArrival.waiting),
        (AttentionLevel.undroppable, AttentionArrival.spontaneous, AttentionArrival.spontaneous),
      ];

      for (final c in cases) {
        setUp2();
        hold(req('old', level: c.$1, arrival: c.$2));
        final decision = arbiter.request(req('new', level: c.$1, arrival: c.$3));
        await pumpEventQueue();

        expect(decision, isA<AttentionAccepted>());
        final accepted = decision as AttentionAccepted;
        expect(accepted.preempted!.requestId, 'old');
        expect(accepted.sameLevelReplace, isTrue);
        expect(arbiter.holder!.handle.requestId, 'new');

        final sameLevel = recorder.singleOf(AttentionArbiterLogEvent.sameLevelReplaced);
        expect(sameLevel.fields['requestId'], 'old');
        expect(recorder.of(AttentionArbiterLogEvent.preempted), isEmpty);
        expect(consumedLog.length, 1);
        expect(consumedLog.single.handle.requestId, 'old');
        expect(consumedLog.single.reason, AttentionReleaseReason.preempted);
      }
    });

    test('T-11 低級別自發型被跳過（兩列）', () {
      for (final holderLevel in [AttentionLevel.undroppable, AttentionLevel.mustLeaveTrace]) {
        setUp2();
        hold(req('gate', level: holderLevel, arrival: AttentionArrival.spontaneous));

        final decision = arbiter.request(
          req('bg', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
        );

        expect(decision, isA<AttentionSkipped>());
        expect((decision as AttentionSkipped).blockedBy.requestId, 'gate');
        expect(arbiter.holder!.handle.requestId, 'gate');
        expect(arbiter.holder!.presentedAt, isNotNull);

        final skipped = recorder.singleOf(AttentionArbiterLogEvent.skipped);
        expect(skipped.fields['requestId'], 'bg');
        expect(skipped.level, 900);
        expect(skipped.fields['occupancy'], {
          'inFlight': 1,
          'queueDepth': 0,
          'oldestAge': Duration.zero,
        });
        expect(consumedLog, isEmpty);
      }
    });

    test('T-12 自發型須留痕被延後、訊號後重新請求', () async {
      final gateHandle = hold(
        req('gate', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous),
      );

      final d1 = arbiter.request(
        req('trace', level: AttentionLevel.mustLeaveTrace, arrival: AttentionArrival.spontaneous),
      );
      expect(d1, isA<AttentionDeferred>());
      final deferred = d1 as AttentionDeferred;
      expect(deferred.blockedBy.requestId, 'gate');

      final signalLog = <AttentionConsumed>[];
      deferred.signal.listen(signalLog.add);
      expect(signalLog, isEmpty);

      arbiter.release(gateHandle, AttentionReleaseReason.responded);
      await pumpEventQueue();
      expect(arbiter.holder, isNull);

      final d2 = arbiter.request(
        req(
          'trace-2',
          level: AttentionLevel.mustLeaveTrace,
          arrival: AttentionArrival.spontaneous,
        ),
      );

      expect(signalLog.length, 1);
      expect(signalLog.single.handle.requestId, 'gate');
      expect(signalLog.single.reason, AttentionReleaseReason.responded);
      expect(d2, isA<AttentionAccepted>());
      expect((d2 as AttentionAccepted).preempted, isNull);
      expect(recorder.singleOf(AttentionArbiterLogEvent.deferred).fields['requestId'], 'trace');
      expect(recorder.singleOf(AttentionArbiterLogEvent.deferred).level, 900);
      expect(
        recorder.of(AttentionArbiterLogEvent.accepted).any(
          (r) => r.fields['requestId'] == 'trace',
        ),
        isFalse,
      );
    });

    test('T-13 等待型被拒絕並可重試（三列）', () async {
      final cases = <(AttentionLevel, AttentionArrival, AttentionLevel, AttentionSource, bool)>[
        (AttentionLevel.undroppable, AttentionArrival.spontaneous, AttentionLevel.discardable, AttentionSource.workspace, false),
        (AttentionLevel.mustLeaveTrace, AttentionArrival.spontaneous, AttentionLevel.discardable, AttentionSource.diagnostics, false),
        (AttentionLevel.undroppable, AttentionArrival.spontaneous, AttentionLevel.mustLeaveTrace, AttentionSource.workspace, true),
      ];

      for (final c in cases) {
        setUp2();
        final gateHandle = hold(req('gate', level: c.$1, arrival: c.$2));

        final d = arbiter.request(
          req('user', level: c.$3, arrival: AttentionArrival.waiting, source: c.$4),
        );
        expect(d, isA<AttentionRejected>());
        final rejected = d as AttentionRejected;
        expect(rejected.blockedBy!.requestId, 'gate');

        final retryLog = <AttentionConsumed>[];
        rejected.retryAfter.listen(retryLog.add);
        expect(retryLog, isEmpty);
        expect(arbiter.holder!.handle.requestId, 'gate');

        arbiter.release(gateHandle, AttentionReleaseReason.responded);
        await pumpEventQueue();

        expect(arbiter.holder, isNull);
        expect(retryLog.length, 1);
        expect(retryLog.single.handle.requestId, 'gate');
        expect(retryLog.single.reason, AttentionReleaseReason.responded);

        final rejectedRecord = recorder.singleOf(AttentionArbiterLogEvent.rejected);
        expect(rejectedRecord.fields['requestId'], 'user');
        expect(rejectedRecord.fields['decision'], 'rejected');
        expect(rejectedRecord.level == null || rejectedRecord.level == 800, isTrue);
      }
    });

    test('T-14 持有者再請求被拒（兩列）', () {
      // 列 1
      hold(req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      var decision = arbiter.request(
        req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
      );
      expect(decision, isA<AttentionRejected>());
      expect((decision as AttentionRejected).blockedBy!.requestId, 'r1');
      expect(arbiter.holder!.handle.requestId, 'r1');
      expect(recorder.singleOf(AttentionArbiterLogEvent.heldAndRequested).level, 900);
      expect(recorder.of(AttentionArbiterLogEvent.preempted), isEmpty);
      expect(recorder.of(AttentionArbiterLogEvent.sameLevelReplaced), isEmpty);
      expect(consumedLog, isEmpty);

      // 列 2：同 id 判定先於級別比較
      setUp2();
      hold(req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      decision = arbiter.request(
        req('r1', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous),
      );
      expect(decision, isA<AttentionRejected>());
      expect((decision as AttentionRejected).blockedBy!.requestId, 'r1');
      expect(arbiter.holder!.handle.requestId, 'r1');
      expect(recorder.singleOf(AttentionArbiterLogEvent.heldAndRequested).fields['requestId'], 'r1');
    });

    test('T-15 級別傳播單調不升（四列）', () {
      // 列 1：空持有者，U/D -> Accepted，D，levelClamped
      var decision = arbiter.request(
        req('r1', level: AttentionLevel.undroppable, parentLevel: AttentionLevel.discardable),
      );
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).handle.level, AttentionLevel.discardable);
      final clamp1 = recorder.singleOf(AttentionArbiterLogEvent.levelClamped);
      expect(clamp1.level, 900);
      expect(clamp1.fields['requestedLevel'], AttentionLevel.undroppable);
      expect(clamp1.fields['parentLevel'], AttentionLevel.discardable);

      // 列 2：D/D -> Accepted，D，無 clamp
      setUp2();
      decision = arbiter.request(
        req('r1', level: AttentionLevel.discardable, parentLevel: AttentionLevel.discardable),
      );
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).handle.level, AttentionLevel.discardable);
      expect(recorder.of(AttentionArbiterLogEvent.levelClamped), isEmpty);

      // 列 3：D/U -> Accepted，D（降不夾）
      setUp2();
      decision = arbiter.request(
        req('r1', level: AttentionLevel.discardable, parentLevel: AttentionLevel.undroppable),
      );
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).handle.level, AttentionLevel.discardable);
      expect(recorder.of(AttentionArbiterLogEvent.levelClamped), isEmpty);

      // 列 4：持有者 T/spontaneous，請求 U/D(spontaneous) -> 夾成 D，Skipped
      setUp2();
      hold(req('gate', level: AttentionLevel.mustLeaveTrace, arrival: AttentionArrival.spontaneous));
      decision = arbiter.request(
        req(
          'r2',
          level: AttentionLevel.undroppable,
          parentLevel: AttentionLevel.discardable,
          arrival: AttentionArrival.spontaneous,
        ),
      );
      expect(decision, isA<AttentionSkipped>());
      expect(recorder.of(AttentionArbiterLogEvent.levelClamped), isNotEmpty);
    });

    test('T-16 空 id 被拒', () {
      final decision = arbiter.request(req(''));
      expect(decision, isA<AttentionRejected>());
      final record = recorder.singleOf(AttentionArbiterLogEvent.rejected);
      expect(record.fields['reason'], 'emptyId');
      expect(record.level, 900);
      expect(arbiter.holder, isNull);
    });
  });

  group('G-C 逾期懶檢查', () {
    test('T-17 逾期懶檢查', () async {
      hold(
        req('old', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
        naturalLifespan: Motion.snackBar,
      );
      clock.advance(Motion.snackBar + Motion.feedback);
      expect(arbiter.holder!.handle.requestId, 'old');

      final decision = arbiter.request(
        req('new', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
      );
      await pumpEventQueue();

      final expiredRecord = recorder.singleOf(AttentionArbiterLogEvent.expired);
      expect(expiredRecord.fields['requestId'], 'old');
      expect(expiredRecord.fields['reason'], 'expired');
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).preempted, isNull);
      expect(decision.sameLevelReplace, isFalse);
      expect(recorder.of(AttentionArbiterLogEvent.sameLevelReplaced), isEmpty);
      final acceptedRecord = recorder
          .of(AttentionArbiterLogEvent.accepted)
          .where((r) => r.fields['requestId'] == 'new')
          .single;
      expect(
        recorder.records.indexOf(expiredRecord) <
            recorder.records.indexOf(acceptedRecord),
        isTrue,
      );
      expect(consumedLog.length, 1);
      expect(consumedLog.single.handle.requestId, 'old');
      expect(consumedLog.single.reason, AttentionReleaseReason.expired);
      expect(arbiter.holder!.handle.requestId, 'new');
    });

    test('T-18 恰等於存活期不逾期', () {
      hold(
        req('old', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
        naturalLifespan: Motion.snackBar,
      );
      clock.advance(Motion.snackBar);

      final decision = arbiter.request(
        req('new', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
      );

      expect(recorder.of(AttentionArbiterLogEvent.expired), isEmpty);
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).preempted!.requestId, 'old');
      expect(decision.sameLevelReplace, isTrue);
    });

    test('T-19 無自然存活期不逾期', () {
      hold(req('gate', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));
      clock.advance(const Duration(days: 1));

      final decision = arbiter.request(
        req('bg', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
      );

      expect(recorder.of(AttentionArbiterLogEvent.expired), isEmpty);
      expect(decision, isA<AttentionSkipped>());
      expect(arbiter.holder!.handle.requestId, 'gate');
    });

    test('T-20 尚未 presented 不觸發懶檢查，年齡自接受起算', () {
      arbiter.request(req('r1'));
      clock.advance(Motion.snackBarWithAction);

      expect(arbiter.holder!.ageAt(clock.now), Motion.snackBarWithAction);
      expect(arbiter.holder!.presentedAt, isNull);

      final decision = arbiter.request(
        req('r2', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
      );

      expect(recorder.of(AttentionArbiterLogEvent.expired), isEmpty);
      expect(decision, isA<AttentionAccepted>());
      expect((decision as AttentionAccepted).preempted!.requestId, 'r1');
      expect(decision.sameLevelReplace, isTrue);
      final record = recorder.records.last;
      final occupancy = record.fields['occupancy'] as Map;
      expect(occupancy['oldestAge'], Motion.snackBarWithAction);
    });

    test('T-21 holder 讀取不觸發懶檢查', () {
      hold(
        req('old', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
        naturalLifespan: Motion.snackBar,
      );
      clock.advance(Motion.snackBar + Motion.feedback);

      expect(arbiter.holder!.handle.requestId, 'old');
      expect(arbiter.holder!.handle.requestId, 'old');
      expect(recorder.of(AttentionArbiterLogEvent.expired), isEmpty);
      expect(consumedLog, isEmpty);

      arbiter.request(req('new'));
      expect(recorder.of(AttentionArbiterLogEvent.expired), isNotEmpty);
    });
  });

  group('G-D 可觀測事件', () {
    test('T-22 每種事件、決策、離開原因各至少一則', () async {
      // 步 1
      arbiter.request(req('r0'));
      final r0Handle = (arbiter.request(req('r0-holder')) as AttentionAccepted).handle;
      arbiter.release(r0Handle, AttentionReleaseReason.responded);
      await pumpEventQueue();

      final r1Decision = arbiter.request(req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      // r1 became holder replacing r0
      final r1Handle = (r1Decision as AttentionAccepted).handle;

      // 步 2
      arbiter.request(req('r1', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));

      // 步 3
      arbiter.presented(r1Handle, naturalLifespan: Motion.snackBar);
      arbiter.release(r0Handle, AttentionReleaseReason.dismissed);
      await pumpEventQueue();

      // 步 4
      arbiter.request(
        req('r2', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous, parentLevel: AttentionLevel.discardable),
      );
      await pumpEventQueue();

      // 步 5
      final r3Decision = arbiter.request(
        req('r3', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous),
      );
      await pumpEventQueue();

      // 步 6
      arbiter.request(req('r4', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous));

      // 步 7
      arbiter.request(req('r5', level: AttentionLevel.mustLeaveTrace, arrival: AttentionArrival.spontaneous));

      // 步 8
      arbiter.request(req('r6', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));

      // 步 9
      final r3Handle = (r3Decision as AttentionAccepted).handle;
      arbiter.release(r3Handle, AttentionReleaseReason.responded);
      await pumpEventQueue();

      // 步 10
      final r7Decision = arbiter.request(req('r7', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      final r7Handle = (r7Decision as AttentionAccepted).handle;
      arbiter.presented(r7Handle, naturalLifespan: Motion.snackBar);
      clock.advance(Motion.snackBar + Motion.feedback);
      final r8Decision = arbiter.request(req('r8', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      await pumpEventQueue();

      // 步 11
      final r8Handle = (r8Decision as AttentionAccepted).handle;
      arbiter.release(r8Handle, AttentionReleaseReason.dismissed);
      await pumpEventQueue();

      // 步 12
      final r9Decision = arbiter.request(req('r9'));
      final r9Handle = (r9Decision as AttentionAccepted).handle;
      arbiter.release(r9Handle, AttentionReleaseReason.notPresented);
      await pumpEventQueue();

      // 步 13
      final r10Decision = arbiter.request(req('r10'));
      final r10Handle = (r10Decision as AttentionAccepted).handle;
      arbiter.presented(r10Handle, naturalLifespan: Motion.snackBar);
      arbiter.release(r10Handle, AttentionReleaseReason.withdrawn);
      await pumpEventQueue();

      for (final e in AttentionArbiterLogEvent.values) {
        expect(
          recorder.of(e),
          isNotEmpty,
          reason: '$e 未出現於 records',
        );
      }

      final reasonsSeen = recorder.records
          .map((r) => r.fields['reason'])
          .whereType<String>()
          .toSet();
      for (final reason in AttentionReleaseReason.values) {
        expect(
          reasonsSeen.contains(_reasonName(reason)),
          isTrue,
          reason: '$reason 未出現於任何事件的 fields[reason]',
        );
      }

      expect(recorder.of(AttentionArbiterLogEvent.accepted), isNotEmpty);
      expect(recorder.of(AttentionArbiterLogEvent.skipped), isNotEmpty);
      expect(recorder.of(AttentionArbiterLogEvent.rejected), isNotEmpty);
      expect(recorder.of(AttentionArbiterLogEvent.deferred), isNotEmpty);

      for (final record in recorder.records) {
        expectSevenFields(record);
      }
    });

    test('T-23 日誌等級依發起者，契約違反類恆為 warning', () {
      // 列 1：skipped，spontaneous -> 900
      hold(req('gate1', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));
      arbiter.request(req('bg1', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous));
      expect(recorder.singleOf(AttentionArbiterLogEvent.skipped).level, 900);

      // 列 2：deferred，spontaneous -> 900
      setUp2();
      hold(req('gate2', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));
      arbiter.request(req('bg2', level: AttentionLevel.mustLeaveTrace, arrival: AttentionArrival.spontaneous));
      expect(recorder.singleOf(AttentionArbiterLogEvent.deferred).level, 900);

      // 列 3：rejected，waiting -> null 或 800
      setUp2();
      hold(req('gate3', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));
      arbiter.request(req('bg3', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      final rejectedLevel = recorder.singleOf(AttentionArbiterLogEvent.rejected).level;
      expect(rejectedLevel == null || rejectedLevel == 800, isTrue);

      // 列 4：expired，逾期持有者為 spontaneous -> 900
      setUp2();
      hold(
        req('gate4', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous),
        naturalLifespan: Motion.snackBar,
      );
      clock.advance(Motion.snackBar + Motion.feedback);
      arbiter.request(req('trigger4'));
      expect(recorder.singleOf(AttentionArbiterLogEvent.expired).level, 900);

      // 列 5：expired，逾期持有者為 waiting -> null 或 800
      setUp2();
      hold(
        req('gate5', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
        naturalLifespan: Motion.snackBar,
      );
      clock.advance(Motion.snackBar + Motion.feedback);
      arbiter.request(req('trigger5'));
      final expiredLevel = recorder.singleOf(AttentionArbiterLogEvent.expired).level;
      expect(expiredLevel == null || expiredLevel == 800, isTrue);

      // 列 6：heldAndRequested，持有者為 waiting -> 恆 900
      setUp2();
      hold(req('gate6', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      arbiter.request(req('gate6', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      expect(recorder.singleOf(AttentionArbiterLogEvent.heldAndRequested).level, 900);

      // 列 7：levelClamped，請求 waiting -> 恆 900
      setUp2();
      arbiter.request(
        req(
          'gate7',
          level: AttentionLevel.undroppable,
          arrival: AttentionArrival.waiting,
          parentLevel: AttentionLevel.discardable,
        ),
      );
      expect(recorder.singleOf(AttentionArbiterLogEvent.levelClamped).level, 900);

      // 列 8：releasedNonHolder，對應 handle 為 waiting -> 恆 900
      setUp2();
      final gate8Handle = hold(req('gate8', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      arbiter.release(gate8Handle, AttentionReleaseReason.responded);
      hold(req('gate8b'));
      arbiter.release(gate8Handle, AttentionReleaseReason.dismissed);
      expect(recorder.singleOf(AttentionArbiterLogEvent.releasedNonHolder).level, 900);
    });

    test('T-24 occupancy 三項分列與年齡', () {
      // 列 1：空通道接受
      arbiter.request(req('r1'));
      expect(recorder.singleOf(AttentionArbiterLogEvent.accepted).fields['occupancy'], {
        'inFlight': 0,
        'queueDepth': 0,
        'oldestAge': null,
      });

      // 列 2：持有者存在、同一 tick 被跳過
      setUp2();
      hold(req('gate', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));
      arbiter.request(req('bg', level: AttentionLevel.discardable, arrival: AttentionArrival.spontaneous));
      expect(recorder.singleOf(AttentionArbiterLogEvent.skipped).fields['occupancy'], {
        'inFlight': 1,
        'queueDepth': 0,
        'oldestAge': Duration.zero,
      });

      // 列 3：推進 Δ 後被拒絕（無存活期）
      setUp2();
      hold(req('gate2', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));
      clock.advance(Motion.snackBarWithAction);
      arbiter.request(req('user', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting));
      expect(recorder.singleOf(AttentionArbiterLogEvent.rejected).fields['occupancy'], {
        'inFlight': 1,
        'queueDepth': 0,
        'oldestAge': Motion.snackBarWithAction,
      });
    });
  });

  group('G-E 結構、單例與訊號語意', () {
    test('T-26 推送型不可表達', () {
      expect(AttentionArrival.values, [AttentionArrival.waiting, AttentionArrival.spontaneous]);
    });

    test('T-27 級別列舉順序即優先序', () {
      expect(AttentionLevel.values, [
        AttentionLevel.discardable,
        AttentionLevel.mustLeaveTrace,
        AttentionLevel.undroppable,
      ]);
      expect(
        AttentionLevel.undroppable.index > AttentionLevel.mustLeaveTrace.index &&
            AttentionLevel.mustLeaveTrace.index > AttentionLevel.discardable.index,
        isTrue,
      );
    });

    test('T-28 來源列舉恰三值', () {
      expect(AttentionSource.values, [
        AttentionSource.workspace,
        AttentionSource.schema,
        AttentionSource.diagnostics,
      ]);
    });

    test('T-29 事件列舉', () {
      expect(AttentionArbiterLogEvent.values, [
        AttentionArbiterLogEvent.accepted,
        AttentionArbiterLogEvent.preempted,
        AttentionArbiterLogEvent.sameLevelReplaced,
        AttentionArbiterLogEvent.skipped,
        AttentionArbiterLogEvent.rejected,
        AttentionArbiterLogEvent.deferred,
        AttentionArbiterLogEvent.presented,
        AttentionArbiterLogEvent.released,
        AttentionArbiterLogEvent.expired,
        AttentionArbiterLogEvent.releasedNonHolder,
        AttentionArbiterLogEvent.heldAndRequested,
        AttentionArbiterLogEvent.levelClamped,
      ]);
    });

    test('T-30 provider 單例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final a = container.read(attentionArbiterProvider);
      final b = container.read(attentionArbiterProvider);
      expect(identical(a, b), isTrue);
      expect(a, isA<AttentionArbiter>());
    });

    test('T-31 consumed 無訂閱者不緩衝、不重播', () async {
      final freshArbiter = AttentionArbiterImpl(now: () => clock.now, logSink: recorder.sink);
      addTearDown(freshArbiter.dispose);

      final decision1 = freshArbiter.request(req('r1'));
      final handle1 = (decision1 as AttentionAccepted).handle;
      freshArbiter.release(handle1, AttentionReleaseReason.responded);
      await pumpEventQueue();

      final lateLog = <AttentionConsumed>[];
      freshArbiter.consumed.listen(lateLog.add);
      await pumpEventQueue();
      expect(lateLog, isEmpty);

      final decision2 = freshArbiter.request(req('r2'));
      final handle2 = (decision2 as AttentionAccepted).handle;
      freshArbiter.release(handle2, AttentionReleaseReason.responded);
      await pumpEventQueue();

      expect(lateLog.length, 1);
      expect(lateLog.single.handle.requestId, 'r2');
    });

    test('T-32 retryAfter／signal 為 blockedBy 那一筆的過濾視圖', () async {
      hold(req('g1', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous));

      final d = arbiter.request(
        req('user', level: AttentionLevel.discardable, arrival: AttentionArrival.waiting),
      );
      final rejected = d as AttentionRejected;
      final viewLog = <AttentionConsumed>[];
      rejected.retryAfter.listen(viewLog.add);

      final g2Decision = arbiter.request(
        req('g2', level: AttentionLevel.undroppable, arrival: AttentionArrival.spontaneous),
      );
      await pumpEventQueue();

      final g2Handle = (g2Decision as AttentionAccepted).handle;
      arbiter.release(g2Handle, AttentionReleaseReason.responded);
      await pumpEventQueue();

      expect(consumedLog.length, 2);
      expect(viewLog.length, 1);
      expect(viewLog.single.handle.requestId, 'g1');
      expect(viewLog.single.reason, AttentionReleaseReason.preempted);
    });
  });
}

String _reasonName(AttentionReleaseReason reason) {
  switch (reason) {
    case AttentionReleaseReason.responded:
      return 'responded';
    case AttentionReleaseReason.dismissed:
      return 'dismissed';
    case AttentionReleaseReason.expired:
      return 'expired';
    case AttentionReleaseReason.preempted:
      return 'preempted';
    case AttentionReleaseReason.notPresented:
      return 'notPresented';
    case AttentionReleaseReason.withdrawn:
      return 'withdrawn';
  }
}
