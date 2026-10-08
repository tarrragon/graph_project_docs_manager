import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/corpus/uc_flow_extractor.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import '../../helpers/spec006/fake_docs_fs.dart';
import '../../helpers/spec006/type_table_builder.dart';
import '../../helpers/spec006/uc_body_builder.dart';

const _ucPath = 'docs/usecases/UC-01.md';

TypeTable _table() => TypeTableBuilder()
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
    .addType('SPEC', idPattern: r'^SPEC-\d+$')
    .build();

Future<CorpusScanResult> _scan(Map<String, List<int>> files) {
  final fs = FakeDocsFileSystem();
  files.forEach(fs.addFile);
  return scanCorpus(fileSystem: fs, table: _table());
}

Future<CorpusScanResult> _scanOneUc(List<String> blocks) =>
    _scan({_ucPath: ucBytes(blocks: blocks)});

/// C10-1 的型別表（見 corpus_scanner_test.dart），另加 UC 型別。
TypeTable _c10Table() => TypeTableBuilder()
    .addType('Alpha', idPattern: r'^A-\d+$')
    .addType('UC', idPattern: r'^UC-\d{2}$')
    .addType(
      'CarrierType',
      carrierPathPatterns: const [
        PathPatternSpec(pattern: r'^docs/carrier/.*\.md$', specificity: [2, 0]),
      ],
    )
    .addType(
      'TieTypeA',
      carrierPathPatterns: const [
        PathPatternSpec(pattern: r'^docs/tie/.*\.md$', specificity: [2, 0]),
      ],
    )
    .addType(
      'TieTypeB',
      carrierPathPatterns: const [
        PathPatternSpec(pattern: r'^docs/tie/.*\.md$', specificity: [2, 0]),
      ],
    )
    .build();

/// C10-1 的七檔 fixture（節點 1、非節點 1、五種失敗原因各 1）。
FakeDocsFileSystem _c10Fixture() => FakeDocsFileSystem()
  ..addFile('docs/node.md', utf8.encode('---\nid: A-1\n---\n'))
  ..addFile('docs/nonnode.md', utf8.encode('---\ntitle: 無 id\n---\n'))
  ..addFile('docs/carrier/nofm.md', utf8.encode('# title\n'))
  ..addFile('docs/tie/unclosed.md', utf8.encode('---\nkey: 1\n'))
  ..addFile('docs/other/empty.md', utf8.encode('---\n- a\n- b\n---\n'))
  ..addFile(
    'docs/carrier/badyaml.md',
    utf8.encode('---\nkey: "unterminated\n---\n'),
  )
  ..addFile('docs/other/unreadable.md', [0x80, 0x81]);

Future<CorpusScanResult> _scanWithC10Table(FakeDocsFileSystem fs) =>
    scanCorpus(fileSystem: fs, table: _c10Table());

/// 節點的逐項比對鍵：路徑、型別、完整 frontmatter、flow 步驟。
String _nodeKey(RawNode n) =>
    '${n.path}|${n.typeName}|${jsonEncode(n.frontmatter)}|'
    '${jsonEncode(n.flowSteps)}';

/// 解析錯誤的逐項比對鍵：路徑、結果分類、顯示文字。
String _errorKey(ParseError e) => '${e.path}|${e.outcome.kind}|${e.reasonText}';

/// EVT-CORPUS-003 負載的逐欄比對鍵。
String _eventKey(ParseFailureEvent e) =>
    '${e.path}|${e.reason}|${e.line}|${e.nodeType}|${e.candidateTypes}|'
    '${e.schemaAmbiguous}|${e.salvagedFields}|${e.lostFields}|${e.severity}';

List<String> _stepIds(CorpusScanResult r) => [
  for (final s in r.rawNodes.single.flowSteps) s['id'] as String,
];

void main() {
  group('C12 UC flow 區塊取步驟（FR-09 規則 1～6）', () {
    test('C12-1 先無 flow 鍵的 yaml、再合法 flow：取第二個區塊', () async {
      final r = await _scanOneUc([
        noFlowKeyBlock,
        validFlowBlock(['s1', 's2']),
      ]);
      expect(_stepIds(r), ['s1', 's2']);
    });

    test('C12-2 多個合法區塊取第一個', () async {
      final r = await _scanOneUc([
        validFlowBlock(['s1']),
        validFlowBlock(['t1', 't2']),
      ]);
      expect(_stepIds(r), ['s1']);
    });

    test('C12-3 空清單、純量、清單結果的區塊皆略過', () async {
      final r = await _scanOneUc([
        'flow: []',
        'flow: x',
        '- a\n- b',
        validFlowBlock(['s1']),
      ]);
      expect(_stepIds(r), ['s1']);
      expect(r.flowParseFailedEvents, isEmpty);
    });

    test('C12-4 原始順序、不排序、不去重', () async {
      final r = await _scanOneUc([
        validFlowBlock(['a', 'c', 'b', 'd', 'd']),
      ]);
      expect(_stepIds(r), ['a', 'c', 'b', 'd', 'd']);
    });

    test('C12-5 保存完整 map：多餘鍵保留、缺鍵照缺', () async {
      final r = await _scanOneUc([
        'flow:\n  - id: s1\n    name: n\n    extra: 1\n  - id: s2',
      ]);
      final steps = r.rawNodes.single.flowSteps;
      expect(steps[0], {'id': 's1', 'name': 'n', 'extra': 1});
      expect(steps[1], {'id': 's2'});
      expect(r.flowParseFailedEvents, isEmpty);
    });

    test('C12-6 守衛：SPEC 節點不帶步驟；同本文改為 UC 則帶', () async {
      final specBytes = utf8.encode(
        '---\nid: SPEC-001\n---\n\n```yaml\n${validFlowBlock(['s1'])}\n```\n',
      );
      final specResult = await _scan({'docs/spec/a.md': specBytes});
      expect(specResult.rawNodes.single.typeName, 'SPEC');
      expect(specResult.rawNodes.single.flowSteps, isEmpty);

      final ucResult = await _scanOneUc([
        validFlowBlock(['s1']),
      ]);
      expect(_stepIds(ucResult), ['s1']);
    });

    test('C12-7 無 yaml 區塊：空清單、節點、無 004', () async {
      final r = await _scanOneUc([]);
      expect(r.rawNodes.single.typeName, 'UC');
      expect(r.rawNodes.single.flowSteps, isEmpty);
      expect(r.flowParseFailedEvents, isEmpty);
    });

    test('C12-8 只有無 flow 鍵的合法 yaml：同 C12-7', () async {
      final r = await _scanOneUc([noFlowKeyBlock]);
      expect(r.rawNodes.single.flowSteps, isEmpty);
      expect(r.flowParseFailedEvents, isEmpty);
    });
  });

  group('C13 flow 區塊損壞與 EVT-CORPUS-004（FR-09 規則 3a、3b）', () {
    test('C13-1 守衛：唯一壞 flow 區塊：空步驟、節點、恰一筆 004、無 003', () async {
      final r = await _scanOneUc([malformedFlowBlock]);
      expect(r.rawNodes.single.flowSteps, isEmpty);
      expect(r.flowParseFailedEvents, hasLength(1));
      expect(r.parseFailureEvents, isEmpty);
      expect(r.parseErrors, isEmpty);
    });

    test('C13-2 壞區塊後有合法區塊：取合法步驟且仍一筆 004', () async {
      final r = await _scanOneUc([
        malformedFlowBlock,
        validFlowBlock(['s1']),
      ]);
      expect(_stepIds(r), ['s1']);
      expect(r.flowParseFailedEvents, hasLength(1));
    });

    test('C13-3 兩個壞區塊：仍恰一筆 004', () async {
      final r = await _scanOneUc([malformedFlowBlock, malformedFlowBlock]);
      expect(r.flowParseFailedEvents, hasLength(1));
    });

    test('C13-4 負向對照：壞 yaml 但無頂層 flow: 行：不發 004', () async {
      final r = await _scanOneUc([malformedNonFlowBlock]);
      expect(r.flowParseFailedEvents, isEmpty);
      expect(r.rawNodes.single.flowSteps, isEmpty);
    });

    test('C13-5 E1 鑑別：壞區塊與無區塊步驟同為空，事件不同', () async {
      final broken = await _scanOneUc([malformedFlowBlock]);
      final none = await _scanOneUc([]);
      expect(broken.rawNodes.single.flowSteps, none.rawNodes.single.flowSteps);
      expect(broken.flowParseFailedEvents.length, 1);
      expect(none.flowParseFailedEvents.length, 0);
      expect(
        broken.flowParseFailedEvents.length,
        isNot(none.flowParseFailedEvents.length),
      );
    });

    test('C13-6 頂層 flow: 在、其下縮排錯誤：發一筆 004', () async {
      final r = await _scanOneUc([badIndentUnderFlowBlock]);
      expect(r.flowParseFailedEvents, hasLength(1));
    });

    test('C13-7 已知限制釘住：flow: 行本身縮排：不發 004、無破洞、空步驟', () async {
      final indented = await _scanOneUc([indentedFlowKeyBlock]);
      expect(indented.flowParseFailedEvents, isEmpty);
      expect(indented.parseFailureEvents, isEmpty);
      expect(indented.rawNodes.single.flowSteps, isEmpty);
      // 對照組：與 C13-6 內容相同，只差 flow: 行的縮排，結果不同。
      expect(
        indentedFlowKeyBlock.split('\n').skip(1).join('\n'),
        badIndentUnderFlowBlock.split('\n').skip(1).join('\n'),
      );
      // 縮排版本的 YAML 仍然損壞，排除「因內容變合法才不報」的誤判。
      expect(
        () => loadYaml(indentedFlowKeyBlock),
        throwsA(isA<YamlException>()),
      );
      final topLevel = await _scanOneUc([badIndentUnderFlowBlock]);
      expect(topLevel.flowParseFailedEvents, hasLength(1));
      expect(indented.flowParseFailedEvents, isEmpty);
    });

    test('C13-8 負載：鍵集合恰為 path、reason；reason 為具名原因碼', () async {
      final r = await _scanOneUc([malformedFlowBlock]);
      final event = r.flowParseFailedEvents.single;
      expect(event.toPayload().keys.toSet(), {'path', 'reason'});
      expect(event.path, _ucPath);
      expect(event.reason, flowBlockMalformedReasonCode);
    });

    test('C13-9 守衛：SPEC 節點本文壞 flow 區塊：不發 004', () async {
      final specBytes = utf8.encode(
        '---\nid: SPEC-001\n---\n\n```yaml\n$malformedFlowBlock\n```\n',
      );
      final r = await _scan({'docs/spec/a.md': specBytes});
      expect(r.flowParseFailedEvents, isEmpty);
      // 正向對照：同本文放在 UC 則發。
      final uc = await _scanOneUc([malformedFlowBlock]);
      expect(uc.flowParseFailedEvents, hasLength(1));
    });

    test('C13-10 UC 路徑上 frontmatter 未閉合：發 003、不發 004', () async {
      final bytes = utf8.encode(
        '---\nid: UC-01\n\n```yaml\n$malformedFlowBlock\n```\n',
      );
      final r = await _scan({_ucPath: bytes});
      expect(r.parseFailureEvents, hasLength(1));
      expect(r.parseErrors.single.outcome, isA<Unclosed>());
      expect(r.flowParseFailedEvents, isEmpty);
    });

    test('C13-11 失敗隔離：加入壞 UC 不改變其他檔案結果', () async {
      // C10-1 的 fixture（七檔、五種失敗原因）；差別只在多一份壞 flow 的 UC。
      final base = await _scanWithC10Table(_c10Fixture());
      final withBad = await _scanWithC10Table(
        _c10Fixture()..addFile(_ucPath, ucBytes(blocks: [malformedFlowBlock])),
      );

      expect(
        withBad.rawNodes.where((n) => n.path != _ucPath).map(_nodeKey),
        base.rawNodes.map(_nodeKey),
      );
      expect(
        withBad.parseErrors.map(_errorKey),
        base.parseErrors.map(_errorKey),
      );
      expect(
        withBad.parseFailureEvents.map(_eventKey),
        base.parseFailureEvents.map(_eventKey),
      );
      expect(
        withBad.schemaAmbiguousNodes.length,
        base.schemaAmbiguousNodes.length,
      );
      final b = base.summary;
      final w = withBad.summary;
      expect(w.totalFilesScanned, b.totalFilesScanned + 1);
      expect(w.nodeCount, b.nodeCount + 1);
      expect(w.nonNodeWithFrontmatterCount, b.nonNodeWithFrontmatterCount);
      expect(w.failureReasonCounts, b.failureReasonCounts);
      expect(w.hitCarrierCount, b.hitCarrierCount);
      expect(w.noHitCount, b.noHitCount);
      expect(w.undeterminedCount, b.undeterminedCount);
      expect(w.carrierPathQueryAvailable, b.carrierPathQueryAvailable);
      expect(w.unlistableDirectories, b.unlistableDirectories);
      expect(b.flowBlockMalformedUcCount, 0);
      expect(w.flowBlockMalformedUcCount, 1);
      expect(checkScanSummaryConservation(w), isTrue);
    });

    test('L1 flow 擷取拋出非 YamlException：該 UC 視為無 flow 區塊，掃描完成', () async {
      final fs = FakeDocsFileSystem()
        ..addFile(
          _ucPath,
          ucBytes(
            blocks: [
              validFlowBlock(['s1']),
            ],
          ),
        )
        ..addFile('docs/usecases/UC-02.md', ucBytes(id: 'UC-02'));
      final r = await scanCorpus(
        fileSystem: fs,
        table: _table(),
        extractFlow: (bytes, path) {
          if (path == _ucPath) {
            throw StateError('模擬 YAML 解析器的非預期例外');
          }
          return extractUcFlow(bytes, path);
        },
      );
      expect(r.rawNodes, hasLength(2));
      final thrown = r.rawNodes.firstWhere((n) => n.path == _ucPath);
      expect(thrown.flowSteps, isEmpty);
      expect(r.flowParseFailedEvents, isEmpty);
      expect(checkScanSummaryConservation(r.summary), isTrue);
    });
  });

  group('C10-6～C10-8 FR-07 flow 區塊解析失敗的 UC 數', () {
    Map<String, List<int>> fixture({required bool fixU1}) => {
      'docs/spec/a.md': utf8.encode('---\nid: SPEC-001\n---\n'),
      'docs/other/note.md': utf8.encode('---\ntitle: t\n---\n'),
      'docs/usecases/none.md': utf8.encode('# no frontmatter\n'),
      'docs/usecases/U1.md': ucBytes(
        id: 'UC-01',
        blocks: [
          fixU1 ? validFlowBlock(['s1']) : malformedFlowBlock,
        ],
      ),
      'docs/usecases/U2.md': ucBytes(
        id: 'UC-02',
        blocks: [malformedFlowBlock, malformedFlowBlock],
      ),
    };

    test('C10-6 以 UC 計不以區塊計；UC 計入節點數；守恆式成立', () async {
      final r = await _scan(fixture(fixU1: false));
      final s = r.summary;
      expect(s.flowBlockMalformedUcCount, 2);
      expect(s.nodeCount, 3);
      expect(s.nonNodeWithFrontmatterCount, 1);
      expect(s.totalFilesScanned, 5);
      expect(checkScanSummaryConservation(s), isTrue);
    });

    test('C10-7 E1 鑑別：修好 U1 後只有該計數項由 2 變 1', () async {
      final a = (await _scan(fixture(fixU1: false))).summary;
      final b = (await _scan(fixture(fixU1: true))).summary;
      expect(a.flowBlockMalformedUcCount, 2);
      expect(b.flowBlockMalformedUcCount, 1);
      expect(b.nodeCount, a.nodeCount);
      expect(b.nonNodeWithFrontmatterCount, a.nonNodeWithFrontmatterCount);
      expect(b.failureReasonCounts, a.failureReasonCounts);
      expect(b.hitCarrierCount, a.hitCarrierCount);
      expect(b.noHitCount, a.noHitCount);
      expect(b.undeterminedCount, a.undeterminedCount);
    });

    test('C10-8 守衛：把 flow 失敗 UC 數加進失敗原因總和則守恆檢查回報失敗', () async {
      final s = (await _scan(fixture(fixU1: false))).summary;
      final wrong = ScanSummary(
        totalFilesScanned: s.totalFilesScanned,
        nodeCount: s.nodeCount,
        nonNodeWithFrontmatterCount: s.nonNodeWithFrontmatterCount,
        failureReasonCounts: {
          ...s.failureReasonCounts,
          ParseResultKind.noFrontmatter:
              (s.failureReasonCounts[ParseResultKind.noFrontmatter] ?? 0) +
              s.flowBlockMalformedUcCount,
        },
        hitCarrierCount: s.hitCarrierCount,
        noHitCount: s.noHitCount,
        undeterminedCount: s.undeterminedCount,
        carrierPathQueryAvailable: s.carrierPathQueryAvailable,
      );
      expect(checkScanSummaryConservation(wrong), isFalse);
    });
  });

  group('FR-09 驗收：兩語料 UC 步驟總數', () {
    const root = 'test/fixtures/spec001/corpus_snapshot';

    /// 快照的 UC 檔只保留 flow 區塊位元組（無 frontmatter，見各專案
    /// MANIFEST.md）；測試補上最小 UC frontmatter 後交給掃描器。
    /// 回傳「UC id → 步驟數」。檔名前五個字元（`UC-0N`）即兩位數補零的 UC
    /// id，符合 `^UC-\\d{2}$`；掃描路徑以該 id 命名。
    Future<Map<String, int>> stepsPerUc(String project) async {
      final dir = Directory('$root/$project/docs/usecases');
      final fs = FakeDocsFileSystem();
      for (final file in dir.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        final id = name.substring(0, 5);
        final prefix = utf8.encode('---\nid: $id\n---\n\n');
        fs.addFile('docs/usecases/$id.md', [
          ...prefix,
          ...file.readAsBytesSync(),
        ]);
      }
      final result = await scanCorpus(fileSystem: fs, table: _table());
      expect(result.flowParseFailedEvents, isEmpty);
      return {
        for (final n in result.rawNodes.where((n) => n.typeName == 'UC'))
          n.frontmatter['id'] as String: n.flowSteps.length,
      };
    }

    test('graph_project_docs_manager 逐 UC 步數，總數 40', () async {
      final perUc = await stepsPerUc('graph_project_docs_manager');
      expect(perUc, {
        'UC-01': 7,
        'UC-02': 7,
        'UC-03': 6,
        'UC-04': 6,
        'UC-05': 7,
        'UC-06': 7,
      });
      expect(perUc.values.fold<int>(0, (a, b) => a + b), 40);
    });

    test('flutter_balance 逐 UC 步數，總數 9', () async {
      final perUc = await stepsPerUc('flutter_balance');
      expect(perUc, {'UC-01': 9});
      expect(perUc.values.fold<int>(0, (a, b) => a + b), 9);
    });
  });
}
