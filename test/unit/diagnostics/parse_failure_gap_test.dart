import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/uc_flow_extractor.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../helpers/spec006/fake_docs_fs.dart';
import '../../helpers/spec006/type_table_builder.dart';
import '../../helpers/spec006/uc_body_builder.dart';

ParseFailureEvent _singleMatchEvent({
  required String path,
  required String type,
}) => ParseFailureEvent(
  path: path,
  reason: 'YAML 語法錯誤',
  nodeType: type,
  candidateTypes: [type],
  schemaAmbiguous: false,
  salvagedFields: const [],
  lostFields: const ['title'],
  severity: ParseFailureSeverity.edgeAffecting,
);

ParseFailureEvent _tieEvent({
  required String path,
  required List<String> types,
}) => ParseFailureEvent(
  path: path,
  reason: '無 frontmatter',
  candidateTypes: types,
  schemaAmbiguous: true,
  salvagedFields: const [],
  lostFields: const [],
  severity: ParseFailureSeverity.edgeAffecting,
);

const _okListYaml = 'non_domain_path_patterns:\n  - docs/a.md\n';
const _badListYaml = 'non_domain_path_patterns: nope\n';
const _yamlInvalidListYaml = 'non_domain_path_patterns: [unterminated\n';

TypeTable _builtinTable() => typeTableFromJson(
  jsonDecode(
    File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

TypeTable _threeSourceTable() => TypeTableBuilder()
    .addType(
      'UC',
      idPattern: r'^UC-\d{2}$',
      carrierPathPatterns: const [
        PathPatternSpec(
          pattern: r'^docs/usecases/.*\.md$',
          specificity: [2, 0],
        ),
      ],
    )
    .addType(
      'CarrierType',
      carrierPathPatterns: const [
        PathPatternSpec(pattern: r'^docs/carrier/.*\.md$', specificity: [2, 0]),
      ],
    )
    .build();

/// 一份 fixture 同時含三個來源：兩個命中 carrier 的失敗檔（003）、一個
/// flow 區塊壞掉的 UC（004）、一份清單檔（內容由 [listContent] 決定，005）。
Future<CorpusScanResult> _scanThreeSourceFixture({
  required String listContent,
}) {
  final fs = FakeDocsFileSystem()
    ..addFile('docs/carrier/nofm.md', utf8.encode('# title\n'))
    ..addFile(
      'docs/carrier/badyaml.md',
      utf8.encode('---\nkey: "unterminated\n---\n'),
    )
    ..addFile('docs/usecases/UC-01.md', ucBytes(blocks: [malformedFlowBlock]))
    ..addFile('docs/non-domain-paths.yaml', utf8.encode(listContent));
  return scanCorpus(
    fileSystem: fs,
    table: _threeSourceTable(),
    builtinTable: _builtinTable(),
  );
}

/// 以掃描產出的事件餵 Diagnostics（查詢可用）。
GapDetectionResult _detectFromScan(CorpusScanResult scan) =>
    detectParseFailureGaps(
      events: scan.parseFailureEvents,
      undeterminedCount: scan.summary.undeterminedCount,
      unavailableReason: null,
      flowEvents: scan.flowParseFailedEvents,
      nonDomainPathsEvent: scan.nonDomainPathsParseFailedEvent,
    );

void main() {
  group(
    'detectParseFailureGaps 一事件一破洞（SPEC-006-test-design §3.3 D1，FR-08）',
    () {
      test('D1-1 三筆事件（一型、一型、平手）→ 三筆破洞，逐欄位與事件一致', () {
        final events = [
          _singleMatchEvent(
            path: 'docs/proposals/PROP-001.md',
            type: 'Proposal',
          ),
          _singleMatchEvent(
            path: 'docs/spec/corpus/SPEC-006.md',
            type: 'SpecNode',
          ),
          _tieEvent(
            path: 'docs/events/corpus/EVT-CORPUS-003.md',
            types: ['EventNode', 'SpecNode'],
          ),
        ];

        final result = detectParseFailureGaps(
          events: events,
          undeterminedCount: 0,
          unavailableReason: null,
        );

        expect(result, isA<GapsDetected>());
        final gaps = result.gaps.cast<CarrierParseFailureGap>();
        expect(gaps, hasLength(3));

        for (var i = 0; i < events.length; i++) {
          final event = events[i];
          final gap = gaps[i];
          expect(gap.path, event.path);
          expect(gap.reason, event.reason);
          expect(gap.nodeType, event.nodeType);
          expect(gap.candidateTypes, event.candidateTypes);
          expect(gap.schemaAmbiguous, event.schemaAmbiguous);
        }

        // 平手者帶候選型別與歧義標記。
        final tieGap = gaps[2];
        expect(tieGap.nodeType, isNull);
        expect(tieGap.candidateTypes, ['EventNode', 'SpecNode']);
        expect(tieGap.schemaAmbiguous, isTrue);
      });

      test('D1-2 零筆事件 → 零筆破洞，非「無法判定」', () {
        final result = detectParseFailureGaps(
          events: const [],
          undeterminedCount: 0,
          unavailableReason: null,
        );

        expect(result, isA<GapsDetected>());
        expect((result as GapsDetected).gaps, isEmpty);
      });

      test('D1-3 破洞數等於輸入事件數，等於以同一構造獨立計數的命中 carrier 數', () {
        final events = [
          _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
          _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
          _tieEvent(path: 'docs/c.md', types: ['Proposal', 'SpecNode']),
        ];

        // 以同一構造（events 清單）獨立計數，模擬掃描摘要「命中 carrier 數」
        // 應與破洞數相等（FR-07 守恆式：命中 carrier 數 = 破洞數）。
        final independentlyCountedCarrierHits = events.length;

        final result = detectParseFailureGaps(
          events: events,
          undeterminedCount: 0,
          unavailableReason: null,
        );

        expect(result, isA<GapsDetected>());
        final gaps = (result as GapsDetected).gaps;
        expect(gaps, hasLength(events.length));
        expect(gaps, hasLength(independentlyCountedCarrierHits));
      });

      test('D1-4 破洞類別：本版只產生 parseFailure，不產生其餘三類', () {
        final result = detectParseFailureGaps(
          events: [_singleMatchEvent(path: 'docs/a.md', type: 'Proposal')],
          undeterminedCount: 0,
          unavailableReason: null,
        );

        expect(result, isA<GapsDetected>());
        for (final gap in (result as GapsDetected).gaps) {
          expect(gap.category, GapCategory.parseFailure);
        }
        expect(
          GapCategory.values,
          containsAll([
            GapCategory.parseFailure,
            GapCategory.graphDefect,
            GapCategory.traceGap,
            GapCategory.unlocatable,
          ]),
        );
      });
    },
  );

  group('detectParseFailureGaps 查詢不可用（SPEC-006-test-design §3.3 D2，FR-08）', () {
    test('D2-1a（守衛）查詢不可用、原因碼=沒有路徑模式 → 零筆 parseFailure，回報無法判定並帶原因碼', () {
      final events = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/c.md', type: 'Proposal'),
      ];

      final result = detectParseFailureGaps(
        events: events,
        undeterminedCount: 3,
        unavailableReason: UndeterminedGapReason.noPathPattern,
      );

      expect(result, isA<Undetermined>());
      final undetermined = result as Undetermined;
      expect(undetermined.undeterminedCount, 3);
      expect(undetermined.reason, UndeterminedGapReason.noPathPattern);
    });

    test('D2-1b（守衛）查詢不可用、原因碼=專案版本高於內建 → 回報無法判定並帶對應原因碼', () {
      final result = detectParseFailureGaps(
        events: const [],
        undeterminedCount: 5,
        unavailableReason: UndeterminedGapReason.projectVersionOutOfKnownRange,
      );

      expect(result, isA<Undetermined>());
      final undetermined = result as Undetermined;
      expect(undetermined.undeterminedCount, 5);
      expect(
        undetermined.reason,
        UndeterminedGapReason.projectVersionOutOfKnownRange,
      );
    });

    test('D2-2（正向對照）同一輸入但查詢可用、命中 3 → 三筆破洞，不回報無法判定', () {
      final events = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/c.md', type: 'Proposal'),
      ];

      final result = detectParseFailureGaps(
        events: events,
        undeterminedCount: 0,
        unavailableReason: null,
      );

      expect(result, isA<GapsDetected>());
      expect((result as GapsDetected).gaps, hasLength(3));
    });
  });

  group(
    'detectParseFailureGaps 收 EVT-CORPUS-004／005（§3.3 D1-3、D1-5～D1-10）',
    () {
      final twoCarrierEvents = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
      ];
      final flowEvent = FlowParseFailedEvent(
        path: 'docs/usecases/UC-01.md',
        reason: flowBlockMalformedReasonCode,
      );

      List<ParseFailureGap> gapsOf(GapDetectionResult result) => result.gaps;

      test('D1-5 一筆 004 → 一筆破洞：路徑、型別 UC、原因碼 flowBlockMalformed', () {
        final gaps = gapsOf(
          detectParseFailureGaps(
            events: const [],
            undeterminedCount: 0,
            unavailableReason: null,
            flowEvents: [flowEvent],
          ),
        );

        expect(gaps, hasLength(1));
        final gap = gaps.single as FlowBlockMalformedGap;
        expect(gap.path, 'docs/usecases/UC-01.md');
        expect(gap.nodeType, 'UC');
        expect(gap.reasonCode, flowBlockMalformedReasonCode);
        expect(gap.category, GapCategory.parseFailure);
      });

      test('D1-5 原因碼以前綴比對：reason 附說明仍對應 flowBlockMalformed', () {
        final gaps = gapsOf(
          detectParseFailureGaps(
            events: const [],
            undeterminedCount: 0,
            unavailableReason: null,
            flowEvents: [
              FlowParseFailedEvent(
                path: 'docs/usecases/UC-02.md',
                reason: '$flowBlockMalformedReasonCode：語法錯誤；非 map 項目',
              ),
            ],
          ),
        );

        final gap = gaps.single as FlowBlockMalformedGap;
        expect(gap.reasonCode, flowBlockMalformedReasonCode);
        expect(gap.reason, contains('語法錯誤'));
        expect(
          gap.reasonCode,
          isNot(equals(gap.reason)),
          reason: '全等比對會把附說明的 reason 判成非該原因碼',
        );
      });

      test('D1-6（E1）兩筆 003＋一筆 004 對照零筆 004：三筆對兩筆', () {
        final withFlow = gapsOf(
          detectParseFailureGaps(
            events: twoCarrierEvents,
            undeterminedCount: 0,
            unavailableReason: null,
            flowEvents: [flowEvent],
          ),
        );
        final withoutFlow = gapsOf(
          detectParseFailureGaps(
            events: twoCarrierEvents,
            undeterminedCount: 0,
            unavailableReason: null,
          ),
        );

        expect(withFlow, hasLength(3));
        expect(withoutFlow, hasLength(2));
        expect(withFlow.whereType<FlowBlockMalformedGap>(), hasLength(1));
        expect(withoutFlow.whereType<FlowBlockMalformedGap>(), isEmpty);
      });

      test(
        'D1-7 一筆 005（notList）→ 一筆破洞：原因碼 nonDomainPathsMalformed、子原因 notList',
        () {
          final event = NonDomainPathsReadMalformed(
            path: 'docs/non-domain-paths.yaml',
            reason: NonDomainPathsWholeFileReason.notList,
          ).malformedEvent;

          final gaps = gapsOf(
            detectParseFailureGaps(
              events: const [],
              undeterminedCount: 0,
              unavailableReason: null,
              nonDomainPathsEvent: event,
            ),
          );

          expect(gaps, hasLength(1));
          final gap = gaps.single as NonDomainPathsMalformedGap;
          expect(gap.path, 'docs/non-domain-paths.yaml');
          expect(gap.reasonCode, nonDomainPathsMalformedGapReasonCode);
          expect(gap.subReason, NonDomainPathsMalformedReason.notList);
          expect(gap.reasonCode, isNot(flowBlockMalformedReasonCode));
        },
      );

      test('D1-8（E1）兩筆 003＋一筆 004＋一筆 005 對照零筆 005：四筆對三筆', () {
        final listEvent = NonDomainPathsReadMalformed(
          path: 'docs/non-domain-paths.yaml',
          reason: NonDomainPathsWholeFileReason.keyMissing,
        ).malformedEvent;

        final with005 = gapsOf(
          detectParseFailureGaps(
            events: twoCarrierEvents,
            undeterminedCount: 0,
            unavailableReason: null,
            flowEvents: [flowEvent],
            nonDomainPathsEvent: listEvent,
          ),
        );
        final without005 = gapsOf(
          detectParseFailureGaps(
            events: twoCarrierEvents,
            undeterminedCount: 0,
            unavailableReason: null,
            flowEvents: [flowEvent],
          ),
        );

        expect(with005, hasLength(4));
        expect(without005, hasLength(3));
      });

      test(
        'D1-3 同一份 fixture 掃描：破洞數等於 命中 carrier 數＋flow 失敗 UC 數＋清單格式錯誤數',
        () async {
          final scan = await _scanThreeSourceFixture(listContent: _badListYaml);
          final summary = scan.summary;

          final gaps = gapsOf(_detectFromScan(scan));

          // 三項計數皆非零，公式任一項被漏收都會使等式不成立。
          expect(summary.hitCarrierCount, 2);
          expect(summary.flowBlockMalformedUcCount, 1);
          expect(summary.nonDomainPathsMalformedCount, 1);
          expect(
            gaps,
            hasLength(
              summary.hitCarrierCount +
                  summary.flowBlockMalformedUcCount +
                  summary.nonDomainPathsMalformedCount,
            ),
          );
        },
      );

      test('D1-8（E1）yamlInvalid：同一份清單檔正常對 YAML 壞掉，破洞數差 1', () async {
        final ok = await _scanThreeSourceFixture(listContent: _okListYaml);
        final broken = await _scanThreeSourceFixture(
          listContent: _yamlInvalidListYaml,
        );

        final okGaps = gapsOf(_detectFromScan(ok));
        final brokenGaps = gapsOf(_detectFromScan(broken));

        expect(brokenGaps.length - okGaps.length, 1);
        final extra = brokenGaps.whereType<NonDomainPathsMalformedGap>();
        expect(
          extra.single.subReason,
          NonDomainPathsMalformedReason.yamlInvalid,
        );
        expect(okGaps.whereType<NonDomainPathsMalformedGap>(), isEmpty);
      });

      test('D1-9（E1）004 的型別為 UC、無候選與歧義標記；平手 003 帶候選與歧義', () {
        final gaps = gapsOf(
          detectParseFailureGaps(
            events: [
              _tieEvent(path: 'docs/c.md', types: ['A', 'B']),
            ],
            undeterminedCount: 0,
            unavailableReason: null,
            flowEvents: [flowEvent],
          ),
        );

        final tie = gaps.firstWhere(
          (g) => g.path == 'docs/c.md',
        ) as CarrierParseFailureGap;
        final flow = gaps.firstWhere(
          (g) => g.path == flowEvent.path,
        ) as FlowBlockMalformedGap;
        // 004 子型別沒有候選型別與歧義標記欄位，型別恆為 UC。
        expect(flow.nodeType, 'UC');
        expect(tie.nodeType, isNull);
        expect(tie.candidateTypes, ['A', 'B']);
        expect(tie.schemaAmbiguous, isTrue);
      });

      test(
        'D1-10（E1）elementNotString 帶 nonStringElementCount=2；notList 為 null',
        () {
          final bad = NonDomainPathsReadDeclaredWithBadElements(
            path: 'docs/non-domain-paths.yaml',
            patterns: const ['docs/a.md'],
            nonStringElementCount: 2,
          ).malformedEvent;
          final notList = NonDomainPathsReadMalformed(
            path: 'docs/non-domain-paths.yaml',
            reason: NonDomainPathsWholeFileReason.notList,
          ).malformedEvent;

          final badGaps = gapsOf(
            detectParseFailureGaps(
              events: const [],
              undeterminedCount: 0,
              unavailableReason: null,
              nonDomainPathsEvent: bad,
            ),
          );
          final notListGaps = gapsOf(
            detectParseFailureGaps(
              events: const [],
              undeterminedCount: 0,
              unavailableReason: null,
              nonDomainPathsEvent: notList,
            ),
          );

          expect(badGaps, hasLength(1));
          final badGap = badGaps.single as NonDomainPathsMalformedGap;
          final notListGap = notListGaps.single as NonDomainPathsMalformedGap;
          expect(
            badGap.subReason,
            NonDomainPathsMalformedReason.elementNotString,
          );
          expect(badGap.nonStringElementCount, 2);
          expect(notListGap.nonStringElementCount, isNull);
        },
      );
    },
  );

  group('detectParseFailureGaps 查詢不可用時 004／005 照報（§3.3 D2-5～D2-7）', () {
    GapDetectionResult unavailable({
      List<FlowParseFailedEvent> flows = const [],
      NonDomainPathsParseFailedEvent? listEvent,
    }) => detectParseFailureGaps(
      events: [_singleMatchEvent(path: 'docs/a.md', type: 'Proposal')],
      undeterminedCount: 3,
      unavailableReason: UndeterminedGapReason.noPathPattern,
      flowEvents: flows,
      nonDomainPathsEvent: listEvent,
    );

    test('D2-5 無 004、無 005：零筆破洞，無法判定', () {
      final result = unavailable() as Undetermined;

      expect(result.gaps, isEmpty);
      expect(result.undeterminedCount, 3);
    });

    test('D2-6（E2）另加一筆 004：恰一筆 flowBlockMalformed 破洞，仍無法判定', () {
      final result = unavailable(
        flows: [
          FlowParseFailedEvent(
            path: 'docs/usecases/UC-01.md',
            reason: flowBlockMalformedReasonCode,
          ),
        ],
      ) as Undetermined;

      expect(result.gaps, hasLength(1));
      final gap = result.gaps.single as FlowBlockMalformedGap;
      expect(gap.nodeType, 'UC');
      expect(gap.reasonCode, flowBlockMalformedReasonCode);
      expect(result.reason, UndeterminedGapReason.noPathPattern);
      // 003 來源的破洞仍為零：唯一的破洞不是 carrier 來源。
      expect(result.gaps.whereType<CarrierParseFailureGap>(), isEmpty);
    });

    test('D2-7（E2）另加一筆 005（keyMissing）：恰一筆破洞，仍無法判定', () {
      final listEvent = NonDomainPathsReadMalformed(
        path: 'docs/non-domain-paths.yaml',
        reason: NonDomainPathsWholeFileReason.keyMissing,
      ).malformedEvent;

      final result = unavailable(listEvent: listEvent) as Undetermined;

      expect(result.gaps, hasLength(1));
      final gap = result.gaps.single as NonDomainPathsMalformedGap;
      expect(gap.reasonCode, nonDomainPathsMalformedGapReasonCode);
      expect(gap.subReason, NonDomainPathsMalformedReason.keyMissing);
      expect(result.undeterminedCount, 3);
    });
  });
}
