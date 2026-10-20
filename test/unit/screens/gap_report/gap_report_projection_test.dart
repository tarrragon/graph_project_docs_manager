// 破洞報告項目投影（SPEC-001 §5 表一～三與〈定案〉M1／O1／J2）。
//
// 測試名稱前綴對應 M4 覆蓋自查：T1-n＝表一第 n 列、T2-n＝表二第 n 列、
// T3-n＝表三第 n 列，O1／E1／P6／P7／P8 對應票面期望紅燈。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event_builder.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_en.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_descriptions.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_projection.dart';

const _key = 'non_domain_path_patterns';

const _nodes = [
  LightNode(
    id: 'T-1',
    typeName: 'Ticket',
    status: null,
    title: null,
    path: 'docs/t1.md',
  ),
  LightNode(
    id: 'SPEC-1',
    typeName: 'SPEC',
    status: null,
    title: null,
    path: 'docs/spec/s1.md',
  ),
  LightNode(
    id: 'UC-01',
    typeName: 'UC',
    status: null,
    title: null,
    path: 'docs/usecases/UC-01.md',
  ),
  LightNode(
    id: 'DB-b',
    typeName: 'DomainBundle',
    status: null,
    title: null,
    path: 'docs/spec/b/domain-map.md',
  ),
  LightNode(
    id: 'DB-a',
    typeName: 'DomainBundle',
    status: null,
    title: null,
    path: 'docs/spec/a/domain-map.md',
  ),
];

ReferenceValue _ref(String sourceId, String field, Object? value) =>
    ReferenceValue(
      sourceId: sourceId,
      sourcePath: _nodes.firstWhere((n) => n.id == sourceId).path,
      edgeTypeName: 'spawn',
      fieldName: field,
      isReverse: false,
      value: value,
      isShapeValid: value is String,
    );

CarrierParseFailureGap _carrier(
  String path,
  CarrierParseFailureReason reason, {
  UnreadableReason? unreadable,
  int? line,
  bool ambiguous = false,
}) => CarrierParseFailureGap(
  path: path,
  reason: reason.name,
  failureReason: reason,
  unreadableReason: unreadable,
  lineNumber: line,
  candidateTypes: ambiguous ? ['SPEC', 'UC'] : ['SPEC'],
  schemaAmbiguous: ambiguous,
);

NonDomainPathsMalformedGap _nonDomain(
  NonDomainPathsMalformedReason reason, {
  int? count,
}) => NonDomainPathsMalformedGap(
  path: 'docs/non-domain.yaml',
  reason: reason.name,
  subReason: reason,
  nonStringElementCount: count,
);

const _flowGap = FlowBlockMalformedGap(
  path: 'docs/usecases/UC-01.md',
  reason: 'flowBlockMalformed',
);

GraphDefectGap _dangling(
  String sourceId,
  String field,
  Object? value, [
  DanglingReason reason = DanglingReason.targetMissing,
]) => GraphDefectGap(
  DanglingRefGraphDefect(ref: _ref(sourceId, field, value), reason: reason),
);

GraphDefectGap _malformed(
  String sourceId,
  String field,
  Object? value, [
  MalformedReason reason = MalformedReason.invalidShape,
]) => GraphDefectGap(
  MalformedRefGraphDefect(ref: _ref(sourceId, field, value), reason: reason),
);

GraphDefectGap _flowDefect(
  FlowDefectKind kind, {
  String uc = 'UC-01',
  Object? stepId = 's1',
  String field = 'next',
  Object? raw = 'x',
}) => GraphDefectGap(
  FlowGraphDefect(
    kind: kind,
    ucId: uc,
    stepId: stepId,
    field: field,
    rawValue: raw,
  ),
);

List<GraphDefectGap> _mainDefectsFour() => [
  _dangling('T-1', 'f', 'X-9'),
  _malformed('T-1', 'f', 42),
  _dupId,
  _multi,
];

List<GraphDefectGap> _flowFour() => [
  _flowDefect(FlowDefectKind.unresolvedReference),
  _flowDefect(FlowDefectKind.duplicateStepId),
  _flowDefect(FlowDefectKind.traversesUndeclared),
  _flowDefect(FlowDefectKind.traversesKeyAbsent),
];

final _multi = GraphDefectGap(
  MultiSourceGraphDefect(
    from: 'T-1',
    edgeType: 'spawn',
    targets: [
      MultiSourceTarget(to: 'T-2', declaredBy: {'T-1'}),
      MultiSourceTarget(to: 'T-3', declaredBy: {'T-3'}),
    ],
  ),
);

final _dupId = GraphDefectGap(
  DuplicateIdGraphDefect(id: 'D-1', paths: ['docs/z.md', 'docs/a.md']),
);

final _domainDup = GraphDefectGap(
  DomainDuplicateDeclarationGraphDefect(
    domain: 'corpus',
    bundleIds: ['DB-b', 'DB-a'],
  ),
);

List<GapReportCategory> _project({
  List<ParseFailureGap> parse = const [],
  List<GraphDefectGap> defects = const [],
  List<GapReportItem> orphan = const [],
  List<GapReportItem> mismatch = const [],
}) => projectGapReport(
  parseFailures: parse,
  graphDefects: defects,
  nodes: _nodes,
  nonDomainPathsKey: _key,
  orphanEventItems: orphan,
  eventDeclarationMismatchItems: mismatch,
);

List<GapReportItem> _itemsOf(List<GapReportCategory> cats, String id) =>
    cats.firstWhere((c) => c.id == id).items;

GapReportItem _only(List<GapReportCategory> cats) {
  expect(cats, hasLength(1));
  expect(cats.single.items, hasLength(1));
  return cats.single.items.single;
}

const _eventItem = GapReportItem(
  id: 'evt-a',
  filePath: 'docs/events/EVT-1.md',
  pointerType: GapItemPointerType.event,
  pointerNodeId: 'EVT-1',
  eventUcId: 'UC-01',
  eventId: 'EVT-1',
);

void main() {
  group('表一：分節', () {
    test('T1-1 EVT-CORPUS-003 全部原因 → parse-failure', () {
      final cats = _project(
        parse: [
          for (final r in CarrierParseFailureReason.values)
            _carrier(
              'docs/${r.name}.md',
              r,
              unreadable: r == CarrierParseFailureReason.unreadable
                  ? UnreadableReason.encoding
                  : null,
            ),
        ],
      );
      expect(cats.map((c) => c.id), ['parse-failure']);
      expect(cats.single.items, hasLength(5));
    });

    test('T1-2 EVT-CORPUS-004 → flow-block-malformed', () {
      expect(_project(parse: [_flowGap]).single.id, 'flow-block-malformed');
    });

    test('T1-3 EVT-CORPUS-005 四個子原因 → non-domain-paths-malformed', () {
      final cats = _project(
        parse: [
          _nonDomain(NonDomainPathsMalformedReason.yamlInvalid),
          _nonDomain(NonDomainPathsMalformedReason.keyMissing),
          _nonDomain(NonDomainPathsMalformedReason.notList),
          _nonDomain(NonDomainPathsMalformedReason.elementNotString, count: 2),
        ],
      );
      expect(cats.map((c) => c.id), ['non-domain-paths-malformed']);
      expect(cats.single.items, hasLength(4));
    });

    test('T1-4 主圖四子類 → graph-defect', () {
      final cats = _project(
        defects: [
          _dangling('T-1', 'spawned_tickets', 'X-9'),
          _malformed('T-1', 'spawned_tickets', 42),
          _dupId,
          _multi,
        ],
      );
      expect(cats.map((c) => c.id), ['graph-defect']);
      expect(cats.single.items, hasLength(4));
    });

    test('T1-5 domain 重複宣告與主圖同節（graph-defect）', () {
      final cats = _project(
        defects: [_dangling('T-1', 'f', 'X-9'), _domainDup],
      );
      expect(cats.map((c) => c.id), ['graph-defect']);
      expect(cats.single.items, hasLength(2));
    });

    test('T1-6 flow 四子類 → graph-defect-flow，與主圖分開', () {
      final cats = _project(
        defects: [
          _dangling('T-1', 'f', 'X-9'),
          _flowDefect(FlowDefectKind.unresolvedReference),
          _flowDefect(FlowDefectKind.duplicateStepId),
          _flowDefect(FlowDefectKind.traversesUndeclared),
          _flowDefect(FlowDefectKind.traversesKeyAbsent),
        ],
      );
      expect(cats.map((c) => c.id), ['graph-defect', 'graph-defect-flow']);
      expect(_itemsOf(cats, 'graph-defect-flow'), hasLength(4));
    });

    test('D4-2（E1）主圖四子類加 flow 四子類 → 主圖組四筆、flow 小組四筆', () {
      final cats = _project(defects: [..._mainDefectsFour(), ..._flowFour()]);
      expect(cats.map((c) => c.id), ['graph-defect', 'graph-defect-flow']);
      expect(_itemsOf(cats, 'graph-defect'), hasLength(4));
      expect(_itemsOf(cats, 'graph-defect-flow'), hasLength(4));
    });

    test('D5-2（E1）重複宣告歸主圖組（五筆），flow 小組仍四筆', () {
      final cats = _project(
        defects: [..._mainDefectsFour(), ..._flowFour(), _domainDup],
      );
      expect(_itemsOf(cats, 'graph-defect'), hasLength(5));
      expect(_itemsOf(cats, 'graph-defect-flow'), hasLength(4));
    });
  });

  group('O1分節順序與空分節', () {
    final all = <ParseFailureGap>[
      _carrier('docs/a.md', CarrierParseFailureReason.noFrontmatter),
      _flowGap,
      _nonDomain(NonDomainPathsMalformedReason.notList),
    ];

    test('七個分節依 O1 固定順序，與輸入順序無關', () {
      final defects = [_flowDefect(FlowDefectKind.duplicateStepId), _dupId];
      final cats = _project(
        parse: all.reversed.toList(),
        defects: defects,
        orphan: [_eventItem],
        mismatch: [_eventItem],
      );
      expect(cats.map((c) => c.id), [
        'parse-failure',
        'flow-block-malformed',
        'non-domain-paths-malformed',
        'graph-defect',
        'graph-defect-flow',
        'orphan-event',
        'event-declaration-mismatch',
      ]);
    });

    test('E1 空分節不產生：去掉某類破洞後該節消失，其餘節不變', () {
      final withFlow = _project(
        parse: all,
        defects: [_flowDefect(FlowDefectKind.duplicateStepId), _dupId],
      );
      final withoutFlow = _project(parse: all, defects: [_dupId]);
      expect(withFlow.map((c) => c.id), contains('graph-defect-flow'));
      expect(
        withoutFlow.map((c) => c.id),
        isNot(contains('graph-defect-flow')),
      );
      expect(
        withoutFlow.map((c) => c.id),
        withFlow.map((c) => c.id).where((id) => id != 'graph-defect-flow'),
      );
    });

    test('全空輸入 → 無分節', () {
      expect(_project(), isEmpty);
    });

    test('既有事件類項目原樣進入對應分節', () {
      final cats = _project(orphan: [_eventItem]);
      expect(cats.single.id, 'orphan-event');
      expect(cats.single.items.single, same(_eventItem));
    });
  });

  group('表二：項目 id', () {
    test('T2-1 EVT-CORPUS-003／004／005：category id、相對路徑', () {
      expect(
        _only(
          _project(
            parse: [
              _carrier('docs/x.md', CarrierParseFailureReason.noFrontmatter),
            ],
          ),
        ).id,
        'parse-failure:docs%2Fx.md',
      );
      expect(
        _only(_project(parse: [_flowGap])).id,
        'flow-block-malformed:docs%2Fusecases%2FUC-01.md',
      );
      expect(
        _only(
          _project(
            parse: [_nonDomain(NonDomainPathsMalformedReason.keyMissing)],
          ),
        ).id,
        'non-domain-paths-malformed:docs%2Fnon-domain.yaml',
      );
    });

    test('T2-2 danglingRef／malformedRef：子類名、來源節點 ID、欄位名、原始值', () {
      expect(
        _only(_project(defects: [_dangling('T-1', 'spawned_tickets', 'X-9')]))
            .id,
        'danglingRef:T-1:spawned_tickets:X-9',
      );
      expect(
        _only(_project(defects: [_malformed('T-1', 'spawned_tickets', 42)])).id,
        'malformedRef:T-1:spawned_tickets:42',
      );
    });

    test('T2-3 duplicateId：子類名、重複的 ID', () {
      expect(_only(_project(defects: [_dupId])).id, 'duplicateId:D-1');
    });

    test('T2-4 multiSource：子類名、起點 ID、邊型', () {
      expect(_only(_project(defects: [_multi])).id, 'multiSource:T-1:spawn');
    });

    test('T2-5 flow 四子類：子類名、UC ID、step id、欄位名、原始值', () {
      expect(
        _only(
          _project(defects: [_flowDefect(FlowDefectKind.unresolvedReference)]),
        ).id,
        'flowUnresolvedRef:UC-01:s1:next:x',
      );
    });

    test('T2-5b traverses 鍵缺席：原始值為字面 null', () {
      expect(
        _only(
          _project(
            defects: [
              _flowDefect(
                FlowDefectKind.traversesKeyAbsent,
                field: 'traverses',
                raw: null,
              ),
            ],
          ),
        ).id,
        'flowTraversesKeyAbsent:UC-01:s1:traverses:null',
      );
    });

    test('T2-6 domain 重複宣告：子類名、domain 值', () {
      expect(
        _only(_project(defects: [_domainDup])).id,
        'domainDuplicateDeclaration:corpus',
      );
    });

    test('P3 含冒號的原始值經編碼，不破壞成分序列一對一', () {
      final a = _only(_project(defects: [_dangling('T-1', 'a:b', 'c')])).id;
      final b = _only(_project(defects: [_dangling('T-1', 'a', 'b:c')])).id;
      expect(a, 'danglingRef:T-1:a%3Ab:c');
      expect(b, 'danglingRef:T-1:a:b%3Ac');
      expect(a, isNot(b));
    });

    test('P3 同輪成分完全相同者第二筆起加 #2、#3', () {
      final cats = _project(
        defects: [
          _dangling('T-1', 'f', 'X-9'),
          _dangling('T-1', 'f', 'X-9'),
          _dangling('T-1', 'f', 'X-9'),
        ],
      );
      expect(cats.single.items.map((i) => i.id), [
        'danglingRef:T-1:f:X-9',
        'danglingRef:T-1:f:X-9#2',
        'danglingRef:T-1:f:X-9#3',
      ]);
    });

    test('P4/E1 輸入順序不同的兩輪，同一缺陷得到同一 id（id 集合相同）', () {
      final defects = [
        _dangling('T-1', 'f', 'X-9'),
        _malformed('SPEC-1', 'g', 7),
        _dupId,
        _multi,
        _flowDefect(FlowDefectKind.duplicateStepId),
        _domainDup,
      ];
      final parse = <ParseFailureGap>[
        _carrier('docs/a.md', CarrierParseFailureReason.yamlInvalid),
        _flowGap,
        _nonDomain(NonDomainPathsMalformedReason.yamlInvalid),
      ];
      Set<String> ids(List<GapReportCategory> c) => {
        for (final cat in c) ...cat.items.map((i) => i.id),
      };
      final first = _project(parse: parse, defects: defects);
      final second = _project(
        parse: parse.reversed.toList(),
        defects: defects.reversed.toList(),
      );
      expect(ids(first), ids(second));
      expect(ids(first), hasLength(9));
    });

    test('P4 缺陷修正後該 id 消失，不被其他項目沿用', () {
      final before = _project(
        defects: [_dangling('T-1', 'f', 'X-9'), _dangling('T-1', 'f', 'Y-1')],
      );
      final after = _project(defects: [_dangling('T-1', 'f', 'Y-1')]);
      expect(after.single.items.single.id, before.single.items[1].id);
    });
  });

  group('表三：指向', () {
    test('T3-1 EVT-CORPUS-003：路徑、行號有值時附、無指向', () {
      final item = _only(
        _project(
          parse: [
            _carrier(
              'docs/x.md',
              CarrierParseFailureReason.yamlInvalid,
              line: 7,
            ),
          ],
        ),
      );
      expect(item.filePath, 'docs/x.md');
      expect(item.lineNumber, 7);
      expect(item.pointerType, GapItemPointerType.none);
      expect(item.pointerNodeId, isNull);
      expect(
        _only(
          _project(
            parse: [
              _carrier('docs/y.md', CarrierParseFailureReason.noFrontmatter),
            ],
          ),
        ).lineNumber,
        isNull,
      );
    });

    test('T3-2 EVT-CORPUS-004：flow 類，帶 UC id，無 step id', () {
      final item = _only(_project(parse: [_flowGap]));
      expect(item.filePath, 'docs/usecases/UC-01.md');
      expect(item.pointerType, GapItemPointerType.flow);
      expect(item.flowUcId, 'UC-01');
      expect(item.flowStepId, isNull);
    });

    List<GapReportCategory> projectWithoutNodes({
      List<ParseFailureGap> parse = const [],
      List<GraphDefectGap> defects = const [],
    }) => projectGapReport(
      parseFailures: parse,
      graphDefects: defects,
      nodes: const [],
      nonDomainPathsKey: _key,
    );

    // 降級落點不變式（SPEC-001 v1.44 §5〈定案〉）：debug 下 assert；release
    // 下降為無指向且不可開檔的分支無法在 debug 測試套件內走到。
    test('T3-2b 004 的 UC 路徑查無節點 → AssertionError', () {
      expect(
        () => projectWithoutNodes(parse: [_flowGap]),
        throwsAssertionError,
      );
    });

    test('T3-6b multiSource 起點查無節點 → AssertionError', () {
      expect(
        () => projectWithoutNodes(defects: [_multi]),
        throwsAssertionError,
      );
    });

    test('T3-8b domain 重複宣告的最小 bundle 查無節點 → AssertionError', () {
      expect(
        () => projectWithoutNodes(defects: [_domainDup]),
        throwsAssertionError,
      );
    });

    test('T3-7b flow 四子類的 UC 查無節點 → 各自 AssertionError', () {
      for (final kind in FlowDefectKind.values) {
        expect(
          () => projectWithoutNodes(defects: [_flowDefect(kind)]),
          throwsAssertionError,
          reason: '$kind',
        );
      }
    });

    test('T3-3 EVT-CORPUS-005：清單檔路徑、無指向', () {
      final item = _only(
        _project(parse: [_nonDomain(NonDomainPathsMalformedReason.notList)]),
      );
      expect(item.filePath, 'docs/non-domain.yaml');
      expect(item.pointerType, GapItemPointerType.none);
    });

    test('T3-4 danglingRef／malformedRef：來源節點為 Ticket → ticket，其餘 → 其他圖節點', () {
      final ticket = _only(_project(defects: [_dangling('T-1', 'f', 'X')]));
      expect(ticket.pointerType, GapItemPointerType.ticket);
      expect(ticket.pointerNodeId, 'T-1');
      expect(ticket.filePath, 'docs/t1.md');
      final other = _only(_project(defects: [_malformed('SPEC-1', 'f', 1)]));
      expect(other.pointerType, GapItemPointerType.otherNode);
      expect(other.pointerNodeId, 'SPEC-1');
      expect(other.filePath, 'docs/spec/s1.md');
    });

    test('T3-5 duplicateId：code point 序最小路徑、無指向', () {
      final item = _only(_project(defects: [_dupId]));
      expect(item.filePath, 'docs/a.md');
      expect(item.pointerType, GapItemPointerType.none);
      expect(item.pointerNodeId, isNull);
    });

    test('T3-5b 最小路徑依 code point 序而非 UTF-16 碼元序', () {
      // U+FF5E（BMP）< U+1F600（星芒面）依 code point；UTF-16 碼元序相反。
      final item = _only(
        _project(
          defects: [
            GraphDefectGap(
              DuplicateIdGraphDefect(
                id: 'D-2',
                paths: ['docs/\u{1F600}.md', 'docs/～.md'],
              ),
            ),
          ],
        ),
      );
      expect(item.filePath, 'docs/～.md');
    });

    test('T3-6 multiSource：起點節點路徑，起點為 Ticket → ticket', () {
      final item = _only(_project(defects: [_multi]));
      expect(item.filePath, 'docs/t1.md');
      expect(item.pointerType, GapItemPointerType.ticket);
      expect(item.pointerNodeId, 'T-1');
    });

    test('T3-7 flow 四子類：flow 類，帶 UC id 與 step id（原值字串化）', () {
      for (final kind in FlowDefectKind.values) {
        final item = _only(_project(defects: [_flowDefect(kind)]));
        expect(item.pointerType, GapItemPointerType.flow, reason: '$kind');
        expect(item.filePath, 'docs/usecases/UC-01.md', reason: '$kind');
        expect(item.flowUcId, 'UC-01', reason: '$kind');
        expect(item.flowStepId, 's1', reason: '$kind');
      }
    });

    test('T3-8 domain 重複宣告：code point 序最小的 DomainBundle，其他圖節點', () {
      final item = _only(_project(defects: [_domainDup]));
      expect(item.pointerNodeId, 'DB-a');
      expect(item.filePath, 'docs/spec/a/domain-map.md');
      expect(item.pointerType, GapItemPointerType.otherNode);
    });

    test('graphDefect 各子類不顯示行號', () {
      final cats = _project(
        defects: [
          _dangling('T-1', 'f', 'X'),
          _malformed('T-1', 'f', 1),
          _dupId,
          _multi,
          _domainDup,
          _flowDefect(FlowDefectKind.duplicateStepId),
        ],
      );
      for (final cat in cats) {
        expect(cat.items.every((i) => i.lineNumber == null), isTrue);
      }
    });

    test('事件類項目經投影後原樣保留事件 id 與既有 UC id', () {
      final projected = _itemsOf(
        _project(orphan: [_eventItem]),
        'orphan-event',
      ).single;
      expect(projected.eventId, 'EVT-1');
      expect(projected.eventUcId, 'UC-01');
      expect(projected.pointerType, GapItemPointerType.event);
    });
  });

  group('P6 項目說明 key', () {
    final en = AppLocalizationsEn();
    final zh = AppLocalizationsZh();

    String? text(AppLocalizations l, GapReportItem i) =>
        gapItemDescriptionText(l, i.description);

    test('003 七原因各對到一個 gapParse* key（zh／en 皆查得到且互異）', () {
      final cases = <(GapReportItem, String Function(AppLocalizations))>[];
      GapReportItem one(CarrierParseFailureReason r, [UnreadableReason? u]) =>
          _only(_project(parse: [_carrier('docs/x.md', r, unreadable: u)]));
      cases.addAll([
        (
          one(CarrierParseFailureReason.noFrontmatter),
          (l) => l.gapParseNoFrontmatter,
        ),
        (
          one(CarrierParseFailureReason.frontmatterUnclosed),
          (l) => l.gapParseFrontmatterUnclosed,
        ),
        (
          one(CarrierParseFailureReason.frontmatterNotMap),
          (l) => l.gapParseFrontmatterNotMap,
        ),
        (
          one(CarrierParseFailureReason.yamlInvalid),
          (l) => l.gapParseYamlInvalid,
        ),
        (
          one(CarrierParseFailureReason.unreadable, UnreadableReason.encoding),
          (l) => l.gapParseUnreadableEncoding,
        ),
        (
          one(
            CarrierParseFailureReason.unreadable,
            UnreadableReason.permission,
          ),
          (l) => l.gapParseUnreadablePermission,
        ),
        (
          one(
            CarrierParseFailureReason.unreadable,
            UnreadableReason.fileDeleted,
          ),
          (l) => l.gapParseUnreadableMissing,
        ),
      ]);
      final seen = <String>{};
      final seenZh = <String>{};
      for (final (item, expected) in cases) {
        expect(text(en, item), expected(en));
        expect(text(zh, item), expected(zh));
        expect(seen.add(text(en, item)!), isTrue, reason: '七則 en 文案互異');
        expect(seenZh.add(text(zh, item)!), isTrue, reason: '七則 zh 文案互異');
      }
    });

    test('003 歸屬型別不明：附 gapParseTypeAmbiguous，非歧義不附', () {
      final ambiguous = _only(
        _project(
          parse: [
            _carrier(
              'docs/x.md',
              CarrierParseFailureReason.noFrontmatter,
              ambiguous: true,
            ),
          ],
        ),
      );
      expect(ambiguous.ambiguousTypes, ['SPEC', 'UC']);
      expect(
        gapAmbiguousTypesText(en, ambiguous.ambiguousTypes),
        en.gapParseTypeAmbiguous('SPEC, UC'),
      );
      expect(
        gapAmbiguousTypesText(zh, ambiguous.ambiguousTypes),
        zh.gapParseTypeAmbiguous('SPEC、UC'),
      );
      final plain = _only(
        _project(
          parse: [
            _carrier('docs/x.md', CarrierParseFailureReason.noFrontmatter),
          ],
        ),
      );
      expect(gapAmbiguousTypesText(en, plain.ambiguousTypes), isNull);
    });

    test('004 → gapFlowBlockMalformed', () {
      final item = _only(_project(parse: [_flowGap]));
      expect(text(en, item), en.gapFlowBlockMalformed);
      expect(text(zh, item), zh.gapFlowBlockMalformed);
    });

    test('005 沿用 gapNonDomainPaths* 四個 key，key 取呼叫端提供值', () {
      GapReportItem one(NonDomainPathsMalformedReason r, {int? count}) =>
          _only(_project(parse: [_nonDomain(r, count: count)]));
      expect(
        text(en, one(NonDomainPathsMalformedReason.yamlInvalid)),
        en.gapNonDomainPathsYamlInvalid,
      );
      expect(
        text(en, one(NonDomainPathsMalformedReason.keyMissing)),
        en.gapNonDomainPathsKeyMissing(_key),
      );
      expect(
        text(zh, one(NonDomainPathsMalformedReason.notList)),
        zh.gapNonDomainPathsNotList(_key),
      );
      expect(
        text(en, one(NonDomainPathsMalformedReason.elementNotString, count: 1)),
        en.gapNonDomainPathsNonStringElements(1),
      );
      expect(
        text(en, one(NonDomainPathsMalformedReason.elementNotString, count: 3)),
        en.gapNonDomainPathsNonStringElements(3),
      );
    });

    test('graphDefect 十二子類各對到〈1.80 提案〉key，參數取原值', () {
      GapReportItem one(GraphDefectGap g) => _only(_project(defects: [g]));
      final cases = <(GraphDefectGap, String Function(AppLocalizations))>[
        (
          _dangling('T-1', 'f', 'V'),
          (l) => l.gapDanglingRefTargetMissing('f', 'V'),
        ),
        (
          _dangling('T-1', 'f', 'V', DanglingReason.targetDuplicated),
          (l) => l.gapDanglingRefTargetDuplicated('f', 'V'),
        ),
        (
          _malformed('T-1', 'f', 'V'),
          (l) => l.gapMalformedRefInvalidShape('f', 'V'),
        ),
        (
          _malformed('T-1', 'f', 'V', MalformedReason.patternMismatch),
          (l) => l.gapMalformedRefPatternMismatch('f', 'V'),
        ),
        (
          _malformed('T-1', 'f', 'V', MalformedReason.selfReference),
          (l) => l.gapMalformedRefSelfReference('f'),
        ),
        (
          _dupId,
          (l) => l.gapDuplicateId(
            'D-1',
            2,
            l.localeName.startsWith('zh')
                ? 'docs/z.md、docs/a.md'
                : 'docs/z.md, docs/a.md',
          ),
        ),
        (
          _multi,
          (l) => l.gapMultiSource(
            'spawn',
            l.localeName.startsWith('zh') ? 'T-2、T-3' : 'T-2, T-3',
          ),
        ),
        (
          _flowDefect(FlowDefectKind.unresolvedReference, raw: 'R'),
          (l) => l.gapFlowRefUnresolved('s1', 'next', 'R'),
        ),
        (
          _flowDefect(FlowDefectKind.duplicateStepId),
          (l) => l.gapFlowStepIdDuplicated('s1'),
        ),
        (
          _flowDefect(FlowDefectKind.traversesUndeclared, raw: 'nope'),
          (l) => l.gapTraversesUndeclared('s1', 'nope'),
        ),
        (
          _flowDefect(FlowDefectKind.traversesKeyAbsent, raw: null),
          (l) => l.gapTraversesMissing('s1'),
        ),
        (
          _domainDup,
          (l) => l.gapDomainDeclaredTwice(
            'corpus',
            l.localeName.startsWith('zh') ? 'DB-b、DB-a' : 'DB-b, DB-a',
          ),
        ),
      ];
      expect(cases, hasLength(12));
      for (final (gap, expected) in cases) {
        final item = one(gap);
        expect(text(en, item), expected(en), reason: '${gap.kind}');
        expect(text(zh, item), expected(zh), reason: '${gap.kind}');
      }
    });

    test('每個 GapDescriptionKind 都被某個投影案例覆蓋（防新增識別名漏接）', () {
      final produced = <GapDescriptionKind>{};
      final items = <GapReportItem>[
        for (final r in CarrierParseFailureReason.values)
          _only(
            _project(
              parse: [
                _carrier(
                  'docs/x.md',
                  r,
                  unreadable: r == CarrierParseFailureReason.unreadable
                      ? UnreadableReason.permission
                      : null,
                ),
              ],
            ),
          ),
        for (final u in UnreadableReason.values)
          _only(
            _project(
              parse: [
                _carrier(
                  'docs/x.md',
                  CarrierParseFailureReason.unreadable,
                  unreadable: u,
                ),
              ],
            ),
          ),
        _only(_project(parse: [_flowGap])),
        for (final r in NonDomainPathsMalformedReason.values)
          _only(_project(parse: [_nonDomain(r, count: 1)])),
        for (final d in DanglingReason.values)
          _only(_project(defects: [_dangling('T-1', 'f', 'V', d)])),
        for (final m in MalformedReason.values)
          _only(_project(defects: [_malformed('T-1', 'f', 'V', m)])),
        _only(_project(defects: [_dupId])),
        _only(_project(defects: [_multi])),
        for (final k in FlowDefectKind.values)
          _only(_project(defects: [_flowDefect(k)])),
        _only(_project(defects: [_domainDup])),
      ];
      for (final i in items) {
        produced.add(i.description!.kind);
      }
      expect(produced, GapDescriptionKind.values.toSet());
    });
  });

  group('分節標籤', () {
    test('表一五個 category id 與兩個既有事件類 id 皆查得到標籤', () {
      final en = AppLocalizationsEn();
      for (final id in gapCategoryOrder) {
        expect(gapCategoryLabel(en, id), isNot(id), reason: id);
      }
      expect(gapCategoryLabel(en, 'unknown-x'), 'unknown-x');
    });
  });

  group('P8 EVT-CORPUS-003 原因碼列舉', () {
    test('五值列舉與 ParseOutcome 一一對應，unreadable 另帶三值子原因', () {
      expect(CarrierParseFailureReason.values, hasLength(5));
      expect(
        carrierFailureReasonOf(ParseOutcome.noFrontmatter()),
        CarrierParseFailureReason.noFrontmatter,
      );
      expect(
        carrierFailureReasonOf(ParseOutcome.unclosed()),
        CarrierParseFailureReason.frontmatterUnclosed,
      );
      expect(
        carrierFailureReasonOf(ParseOutcome.emptyOrNotMap()),
        CarrierParseFailureReason.frontmatterNotMap,
      );
      expect(
        carrierFailureReasonOf(ParseOutcome.yamlSyntaxError(lineNumber: 3)),
        CarrierParseFailureReason.yamlInvalid,
      );
      for (final u in UnreadableReason.values) {
        expect(
          carrierFailureReasonOf(ParseOutcome.unreadable(u)),
          CarrierParseFailureReason.unreadable,
        );
      }
    });

    test('事件 reason 字串值域不變（列舉是型別化欄位，字串仍由單一對照產生）', () {
      // EVT-CORPUS-003 `reason` 值域的七個字面值（事件契約，不得變動）。
      expect(
        parseOutcomeReasonText(ParseOutcome.noFrontmatter()),
        '無 frontmatter',
      );
      expect(
        parseOutcomeReasonText(ParseOutcome.unclosed()),
        'frontmatter 未閉合',
      );
      expect(
        parseOutcomeReasonText(ParseOutcome.emptyOrNotMap()),
        'frontmatter 為空或非 map',
      );
      expect(
        parseOutcomeReasonText(ParseOutcome.yamlSyntaxError()),
        'YAML 語法錯誤',
      );
      expect(
        parseOutcomeReasonText(
          ParseOutcome.unreadable(UnreadableReason.encoding),
        ),
        '無法讀取（編碼）',
      );
      expect(
        parseOutcomeReasonText(
          ParseOutcome.unreadable(UnreadableReason.permission),
        ),
        '無法讀取（權限）',
      );
      expect(
        parseOutcomeReasonText(
          ParseOutcome.unreadable(UnreadableReason.fileDeleted),
        ),
        '無法讀取（檔案消失）',
      );
    });

    test('carrierFailureReasonOf(Available) 結構上不可達 → StateError', () {
      expect(
        () => carrierFailureReasonOf(ParseOutcome.available({'a': 1})),
        throwsStateError,
      );
    });
  });

  group('P7 ARB 與 SPEC-004 一致', () {
    final zh = jsonDecode(
      File('lib/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final spec = File('docs/spec/ui/SPEC-004-component-library.md')
        .readAsStringSync();
    // 表格列解析：以未跳脫的 `|` 分欄，`\|` 還原為文案內的 `|`。
    // 拆欄函式由 P7 實際比對與下方自檢共用。
    List<String> splitRow(String line) {
      const escapedPipe = '\u0001';
      return line
          .replaceAll(r'\|', escapedPipe)
          .split('|')
          .map((c) => c.replaceAll(escapedPipe, '|').trim())
          .toList();
    }

    final rowStart = RegExp(r'^\| `(gap[A-Za-z]+)` \|');
    final rows = <String, (String, String)>{};
    final duplicateKeys = <String>[];
    for (final line in spec.split('\n')) {
      final m = rowStart.firstMatch(line);
      if (m == null) continue;
      final cells = splitRow(line);
      final key = m.group(1)!;
      if (rows.containsKey(key)) duplicateKeys.add(key);
      rows[key] = (cells[2], cells[3]);
    }
    // 〈1.80 提案〉表與 gapNonDomainPaths* 四列。
    final keys = rows.keys
        .where(
          (k) =>
              k.startsWith('gapCategory') ||
              k.startsWith('gapParse') ||
              k.startsWith('gapNonDomainPaths') ||
              const {
                'gapFlowBlockMalformed',
                'gapDanglingRefTargetMissing',
                'gapDanglingRefTargetDuplicated',
                'gapMalformedRefInvalidShape',
                'gapMalformedRefPatternMismatch',
                'gapMalformedRefSelfReference',
                'gapDuplicateId',
                'gapMultiSource',
                'gapFlowRefUnresolved',
                'gapFlowStepIdDuplicated',
                'gapTraversesUndeclared',
                'gapTraversesMissing',
                'gapDomainDeclaredTwice',
              }.contains(k),
        )
        .toList();

    test('規格表抽到重複 key 即失敗', () {
      expect(duplicateKeys, isEmpty);
    });

    test('SPEC-004 表中的 gap* key 全數存在於 zh／en ARB 且文案逐字相同', () {
      // 〈1.80 提案〉26 個 + gapNonDomainPaths* 4 個 + 既有的
      // gapCategoryOrphanEvent／gapCategoryEventDeclarationMismatch。
      expect(keys, hasLength(32));
      expect(keys, contains('gapCategoryOrphanEvent'));
      expect(keys, contains('gapCategoryEventDeclarationMismatch'));
      for (final k in keys) {
        expect(zh.containsKey(k), isTrue, reason: 'zh 缺 $k');
        expect(en.containsKey(k), isTrue, reason: 'en 缺 $k');
        expect(zh[k], rows[k]!.$1, reason: 'zh 文案 $k');
        expect(en[k], rows[k]!.$2, reason: 'en 文案 $k');
      }
    });

    test('表格含跳脫豎線的文案可正確比對（解析器自檢）', () {
      final cells = splitRow(r'| `gapX` | a \| b | c |');
      expect(cells[2], 'a | b');
      expect(cells[3], 'c');
    });

    test('gapNonDomainPathsNonStringElements en 為單複數 ICU', () {
      expect(
        AppLocalizationsEn().gapNonDomainPathsNonStringElements(1),
        '1 non-string element in the list',
      );
      expect(
        AppLocalizationsEn().gapNonDomainPathsNonStringElements(2),
        '2 non-string elements in the list',
      );
    });

    test('gapCategoryMissingFrontmatter 已刪除（M1）', () {
      expect(zh.containsKey('gapCategoryMissingFrontmatter'), isFalse);
      expect(zh.containsKey('@gapCategoryMissingFrontmatter'), isFalse);
      expect(en.containsKey('gapCategoryMissingFrontmatter'), isFalse);
    });
  });

  group('GraphBuiltEvent 輸入對照（防型別漂移）', () {
    test('投影吃 GraphBuiltEvent.graphDefects 經 Diagnostics 包裝的結果', () {
      final event = GraphBuiltEvent(
        nodes: _nodes,
        edges: const [],
        graphDefects: [
          DuplicateIdGraphDefect(id: 'D-1', paths: ['docs/a.md', 'docs/b.md']),
        ],
        totalReferences: 0,
        resolvedCount: 0,
      );
      final result = detectGraphDefectGaps(
        GraphDefectInputAvailable(event),
      ) as GraphDefectsDetected;
      final cats = projectGapReport(
        parseFailures: const [],
        graphDefects: result.gaps,
        nodes: event.nodes,
        nonDomainPathsKey: _key,
      );
      expect(cats.single.items.single.id, 'duplicateId:D-1');
    });
  });
}
