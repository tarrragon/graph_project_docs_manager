// 破洞報告頁宣告狀態行（SPEC-001 §5〈專案層級宣告狀態一行〉、SPEC-004 §4.0.6；
// 測試設計 SPEC-001-test-design §3.4 R1-1～R1-11、§3.5 K4 的 pathDeclaration*；
// 0.5.0-W1-119.2）。另含 acceptance 2（005 項目點擊開原始檔）與 acceptance 3
// （004 多行例外摘要單行呈現）。
//
// 案例編號沿用測試設計；「E1」「E2」標註對照輸入／正向對照輸入。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/graph/path_declaration_state.dart';
import 'package:graph_project_docs_manager/graph/project_path_declaration.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_en.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_round_state.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_screen.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';

const _lineKey = Key('text-gaps-declaration-line');
const _nonDomainKey = 'non_domain_path_patterns';

final _zh = AppLocalizationsZh();
final _en = AppLocalizationsEn();

class _FixedNotifier extends GapReportNotifier {
  _FixedNotifier(this._fixed);

  final GapReportState _fixed;

  @override
  GapReportState build() => _fixed;
}

/// 直接構造的專案層宣告彙整（不經比對器），供只驗呈現的案例。
ProjectPathDeclaration _decl({
  int declared = 8,
  int total = 8,
  NonDomainSideState side = NonDomainSideState.declared,
  int? count = 0,
  bool overall = false,
}) => ProjectPathDeclaration(
  declaredBundleCount: declared,
  totalBundleCount: total,
  nonDomainSide: side,
  overallUndeclared: overall,
  affectedPathCount: overall ? null : count,
);

const _gapItem = GapReportItem(id: 'a', filePath: 'docs/a.md');
const _categories = [
  GapReportCategory(id: 'parse-failure', items: [_gapItem]),
];

Future<void> _pump(
  WidgetTester tester,
  GapReportState state, {
  Locale locale = kDefaultTestLocale,
  bool settle = true,
}) async {
  // 先卸載上一棵樹：同一測試內換狀態時，既有 ProviderScope 不會套用新 overrides。
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpHarness(
    tester,
    child: const GapReportScreen(),
    locale: locale,
    settle: settle,
    overrides: [gapReportProvider.overrideWith(() => _FixedNotifier(state))],
  );
}

String? _lineText(WidgetTester tester) {
  final finder = find.byKey(_lineKey);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<AppText>(finder).text;
}

RawNode _bundle(String id, {List<String>? patterns}) => RawNode(
  path: 'docs/spec/$id/domain-map.md',
  typeName: 'DomainBundle',
  frontmatter: {'id': id, 'path_patterns': ?patterns},
);

RawNode _ticket(String id, List<String> files) => RawNode(
  path: 'docs/work-logs/v0/tickets/$id.md',
  typeName: 'Ticket',
  frontmatter: {
    'id': id,
    'where': {'files': files},
  },
);

/// 8 個 bundle，前 [declared] 個宣告；加上 [tickets]，經真實比對器彙整。
GapReportState _roundState({
  required int declared,
  required NonDomainPathsReadResult nonDomain,
  List<RawNode> tickets = const [],
  List<ParseFailureEvent> parse = const [],
  List<FlowParseFailedEvent> flow = const [],
}) => gapReportStateFromRound(
  fakeRound(
    nonDomainRead: nonDomain,
    nonDomainPathsEvent: nonDomain.malformedEvent,
    parseFailureEvents: parse,
    flowEvents: flow,
    extraRawNodes: [
      for (var i = 0; i < 8; i++)
        _bundle('b$i', patterns: i < declared ? ['lib/b$i/'] : null),
      ...tickets,
    ],
  ),
  nonDomainPathsKey: _nonDomainKey,
);

ProjectPathDeclaration? _declOf(GapReportState s) => switch (s) {
  GapReportNoGaps(:final pathDeclaration) ||
  GapReportFound(:final pathDeclaration) ||
  GapReportUndeterminable(:final pathDeclaration) => pathDeclaration,
  _ => null,
};

final _listOk = NonDomainPathsReadDeclared(['docs/']);
const _listAbsent = NonDomainPathsReadAbsent();
final _listMalformed = NonDomainPathsReadMalformed(
  path: 'docs/non-domain.yaml',
  reason: NonDomainPathsWholeFileReason.yamlInvalid,
);

void main() {
  group('R1 宣告狀態行文字', () {
    testWidgets('R1-1 5／8 宣告、清單有、影響 12 條 → zh 整行', (tester) async {
      await _pump(
        tester,
        GapReportFound(
          _categories,
          pathDeclaration: _decl(declared: 5, count: 12),
        ),
      );

      expect(_lineText(tester), '路徑宣告不完整：已宣告 5／8 個 domain（影響 12 條路徑）');
    });

    testWidgets('R1-1 en 整行', (tester) async {
      await _pump(
        tester,
        GapReportFound(
          _categories,
          pathDeclaration: _decl(declared: 5, count: 12),
        ),
        locale: const Locale('en'),
      );

      expect(
        _lineText(tester),
        'Path declarations incomplete: 5 of 8 domains declared '
        '(12 paths affected)',
      );
    });

    testWidgets('R1-2 8／8 宣告、清單缺 → detail 只含 NonDomainMissing', (tester) async {
      await _pump(
        tester,
        GapReportFound(
          _categories,
          pathDeclaration: _decl(side: NonDomainSideState.absent, count: 3),
        ),
      );

      final text = _lineText(tester)!;
      expect(
        text,
        _zh.pathDeclarationIncompleteLine(
          _zh.pathDeclarationNonDomainMissing,
          3,
        ),
      );
      expect(text, isNot(contains('已宣告')));
    });

    testWidgets('R1-3 5／8 且清單缺 → zh 以「、」、en 以「, 」連接兩片段', (tester) async {
      final state = GapReportFound(
        _categories,
        pathDeclaration: _decl(
          declared: 5,
          side: NonDomainSideState.absent,
          count: 4,
        ),
      );
      await _pump(tester, state);
      expect(
        _lineText(tester),
        _zh.pathDeclarationIncompleteLine(
          '${_zh.pathDeclarationBundlesPartial(5, 8)}、'
          '${_zh.pathDeclarationNonDomainMissing}',
          4,
        ),
      );

      await _pump(tester, state, locale: const Locale('en'));
      expect(
        _lineText(tester),
        _en.pathDeclarationIncompleteLine(
          '${_en.pathDeclarationBundlesPartial(5, 8)}, '
          '${_en.pathDeclarationNonDomainMissing}',
          4,
        ),
      );
    });

    testWidgets('R1-4 兩側皆無 → NoneLine，不含數字', (tester) async {
      await _pump(
        tester,
        GapReportFound(
          _categories,
          pathDeclaration: _decl(
            declared: 0,
            side: NonDomainSideState.absent,
            overall: true,
          ),
        ),
      );

      final text = _lineText(tester)!;
      expect(text, _zh.pathDeclarationNoneLine);
      expect(text, '本專案未宣告路徑');
      expect(RegExp(r'\d').hasMatch(text), isFalse);
    });

    testWidgets('R1-5（守衛）兩側完整宣告 → 不顯示；R1-1 為正向對照', (tester) async {
      await _pump(
        tester,
        GapReportFound(_categories, pathDeclaration: _decl()),
      );
      expect(find.byKey(_lineKey), findsNothing);

      await _pump(
        tester,
        GapReportFound(
          _categories,
          pathDeclaration: _decl(declared: 5, count: 1),
        ),
      );
      expect(find.byKey(_lineKey), findsOneWidget);
    });

    testWidgets('R1-9 8／8、清單格式錯誤 → detail 只含 Malformed 不含 Missing', (
      tester,
    ) async {
      final state = GapReportFound(
        _categories,
        pathDeclaration: _decl(side: NonDomainSideState.malformed, count: 2),
      );
      await _pump(tester, state);
      final zh = _lineText(tester)!;
      await _pump(tester, state, locale: const Locale('en'));
      final en = _lineText(tester)!;

      expect(zh, contains('非 domain 路徑清單格式錯誤'));
      expect(zh, isNot(contains(_zh.pathDeclarationNonDomainMissing)));
      expect(en, contains('non-domain path list is malformed'));
      expect(en, isNot(contains(_en.pathDeclarationNonDomainMissing)));
    });

    testWidgets('R1-11 5／8、清單格式錯誤 → 兩片段以「、」連接，第二片段為格式錯誤', (tester) async {
      await _pump(
        tester,
        GapReportFound(
          _categories,
          pathDeclaration: _decl(
            declared: 5,
            side: NonDomainSideState.malformed,
            count: 6,
          ),
        ),
      );

      expect(
        _lineText(tester),
        _zh.pathDeclarationIncompleteLine(
          '${_zh.pathDeclarationBundlesPartial(5, 8)}、'
          '${_zh.pathDeclarationNonDomainMalformed}',
          6,
        ),
      );
    });
  });

  group('R1 顯示列與元件', () {
    final gapDecl = _decl(declared: 5, count: 1);

    testWidgets('R1-6 無破洞、有破洞、無法判定破洞三列皆顯示', (tester) async {
      final states = <GapReportState>[
        GapReportNoGaps(pathDeclaration: gapDecl),
        GapReportFound(_categories, pathDeclaration: gapDecl),
        GapReportUndeterminable(
          reason: UndeterminedGapReason.noPathPattern,
          pathDeclaration: gapDecl,
        ),
      ];
      for (final s in states) {
        await _pump(tester, s);
        expect(
          find.byKey(_lineKey),
          findsOneWidget,
          reason: '${s.runtimeType}',
        );
      }
    });

    testWidgets('R1-6（E1）掃描中與專案未就緒不顯示', (tester) async {
      await _pump(tester, const GapReportScanning(), settle: false);
      expect(find.byKey(_lineKey), findsNothing);

      await _pump(
        tester,
        const GapReportProjectUnready(ProjectUnreadyReason.notSelected),
      );
      expect(find.byKey(_lineKey), findsNothing);
    });

    testWidgets('R1-8 元件為 AppText（內文變體），位於頁首說明區（內容之上）', (tester) async {
      await _pump(
        tester,
        GapReportFound(_categories, pathDeclaration: gapDecl),
      );

      final text = tester.widget<AppText>(find.byKey(_lineKey));
      expect(text.variant, AppTextVariant.body);
      final lineTop = tester.getTopLeft(find.byKey(_lineKey)).dy;
      final sectionTop = tester
          .getTopLeft(find.byKey(const Key('state-gaps-found')))
          .dy;
      expect(lineTop, lessThanOrEqualTo(sectionTop));
    });
  });

  group('R1 經真實比對器的彙整（輪次 → 狀態）', () {
    test('R1-6 輪次投影：三種結果狀態皆帶宣告彙整', () {
      final noGaps = _roundState(declared: 5, nonDomain: _listOk);
      final found = _roundState(
        declared: 5,
        nonDomain: _listOk,
        parse: [fakeCarrierEvent('docs/a.md')],
      );

      expect(noGaps, isA<GapReportNoGaps>());
      expect(found, isA<GapReportFound>());
      expect(_declOf(noGaps)!.declaredBundleCount, 5);
      expect(_declOf(found)!.totalBundleCount, 8);
    });

    test('R1-7（E1）宣告缺口有與無各算一次：破洞數與判定相同，缺口不入分節', () {
      final parse = [fakeCarrierEvent('docs/a.md')];
      final withGap = _roundState(
        declared: 5,
        nonDomain: _listAbsent,
        parse: parse,
        tickets: [
          _ticket('T1', ['docs/x.md']),
        ],
      );
      final noGap = _roundState(
        declared: 8,
        nonDomain: _listOk,
        parse: parse,
        tickets: [
          _ticket('T1', ['docs/x.md']),
        ],
      );

      expect(_declOf(withGap)!.hasGap, isTrue);
      expect(_declOf(noGap)!.hasGap, isFalse);
      expect(withGap, isA<GapReportFound>());
      expect(noGap, isA<GapReportFound>());
      List<String> ids(GapReportState s) => [
        for (final c in (s as GapReportFound).categories) c.id,
      ];
      expect(ids(withGap), ids(noGap));
      int itemCount(GapReportState s) => (s as GapReportFound).categories
          .fold<int>(0, (n, c) => n + c.items.length);
      expect(itemCount(withGap), itemCount(noGap));
    });

    test('R1-7（E1）parse 為空：宣告缺口有與無皆為無破洞、破洞數 0', () {
      final tickets = [
        _ticket('T1', ['docs/x.md']),
      ];
      final withGap = _roundState(
        declared: 5,
        nonDomain: _listAbsent,
        tickets: tickets,
      );
      final noGap = _roundState(
        declared: 8,
        nonDomain: _listOk,
        tickets: tickets,
      );

      expect(_declOf(withGap)!.hasGap, isTrue);
      expect(_declOf(noGap)!.hasGap, isFalse);
      expect(withGap, isA<GapReportNoGaps>());
      expect(noGap, isA<GapReportNoGaps>());
    });

    test('R1-1 受影響路徑數為各票加總（比對器結果，非 Diagnostics 計算）', () {
      final state = _roundState(
        declared: 8,
        nonDomain: _listAbsent,
        tickets: [
          _ticket('T1', ['docs/a.md', 'docs/b.md']),
          _ticket('T2', ['docs/c.md']),
        ],
      );

      expect(_declOf(state)!.affectedPathCount, 3);
    });

    testWidgets('R1-10（E1）格式錯誤對缺席：行文字不同、受影響路徑數相同', (tester) async {
      final tickets = [
        _ticket('T1', ['docs/a.md', 'docs/b.md']),
      ];
      final malformed = _roundState(
        declared: 8,
        nonDomain: _listMalformed,
        tickets: tickets,
      );
      final absent = _roundState(
        declared: 8,
        nonDomain: _listAbsent,
        tickets: tickets,
      );

      expect(
        _declOf(malformed)!.affectedPathCount,
        _declOf(absent)!.affectedPathCount,
      );
      await _pump(tester, malformed);
      final malformedText = _lineText(tester);
      await _pump(tester, absent);
      final absentText = _lineText(tester);
      expect(malformedText, isNotNull);
      expect(absentText, isNotNull);
      expect(malformedText, isNot(absentText));
      expect(malformedText, contains('格式錯誤'));
      expect(absentText, contains('缺非 domain 路徑清單'));
    });

    test('P3-4 兩側皆無 → 整體未宣告，路徑數為 null', () {
      final state = gapReportStateFromRound(
        fakeRound(
          nonDomainRead: _listAbsent,
          extraRawNodes: [
            _bundle('b0'),
            _ticket('T1', ['docs/a.md']),
          ],
        ),
        nonDomainPathsKey: _nonDomainKey,
      );

      final d = _declOf(state)!;
      expect(d.overallUndeclared, isTrue);
      expect(d.affectedPathCount, isNull);
    });
  });

  group('K4 pathDeclaration* 五 key 與 SPEC-004 §4.0.6 逐字一致', () {
    final zh = jsonDecode(
      File('lib/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final spec = File('docs/spec/ui/SPEC-004-component-library.md')
        .readAsStringSync();
    const keys = [
      'pathDeclarationIncompleteLine',
      'pathDeclarationBundlesPartial',
      'pathDeclarationNonDomainMissing',
      'pathDeclarationNoneLine',
      'pathDeclarationNonDomainMalformed',
    ];

    (String, String) specRow(String key) {
      final line = spec
          .split('\n')
          .firstWhere((l) => l.startsWith('| `$key` |'));
      final cells = line.split('|').map((c) => c.trim()).toList();
      return (cells[2], cells[3]);
    }

    test('K4-1／K4-2 五 key zh／en ARB 存在且值與規格表相同', () {
      for (final k in keys) {
        final (zhText, enText) = specRow(k);
        expect(zh.containsKey(k), isTrue, reason: 'zh 缺 $k');
        expect(en.containsKey(k), isTrue, reason: 'en 缺 $k');
        expect(zh[k], zhText, reason: 'zh $k');
        expect(en[k], enText, reason: 'en $k');
      }
    });

    test('K4-4 事件類四 key zh／en ARB 值與 SPEC-004 v1.94 表逐字一致', () {
      const eventKeys = [
        'gapOrphanEventEmittedNotConsumed',
        'gapOrphanEventConsumedNotEmitted',
        'gapEventConsumerUnmatched',
        'gapEventProducerUnmatched',
      ];
      for (final k in eventKeys) {
        final (zhText, enText) = specRow(k);
        expect(zh[k], zhText, reason: 'zh $k');
        expect(en[k], enText, reason: 'en $k');
      }
      for (final k in eventKeys.skip(2)) {
        final meta = (zh['@$k'] as Map<String, dynamic>)['placeholders'];
        expect((meta as Map<String, dynamic>).keys, ['domain']);
        expect(en[k], contains('{domain}'));
      }
    });

    test('K4（E2）規格表抽取器對不存在的 key 會失敗（正向對照）', () {
      expect(() => specRow('pathDeclarationNoSuchKey'), throwsStateError);
    });
  });

  group('acceptance 2：005 項目（gapNonDomainPaths*）可開原始檔', () {
    testWidgets('A2-1 005 項目 isOpenable、無指向；點擊以工作區根組絕對路徑開檔', (tester) async {
      final state = gapReportStateFromRound(
        fakeRound(
          nonDomainRead: _listMalformed,
          nonDomainPathsEvent: _listMalformed.malformedEvent,
        ),
        nonDomainPathsKey: _nonDomainKey,
      );
      final item = (state as GapReportFound).categories
          .expand((c) => c.items)
          .single;
      expect(item.isOpenable, isTrue);
      expect(item.pointerType, GapItemPointerType.none);
      expect(item.lineNumber, isNull);

      final opener = FakeExternalOpener();
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(() => _FixedNotifier(state)),
          externalOpenerProvider.overrideWithValue(opener),
          currentWorkspaceStateProvider.overrideWith(
            (ref) => const WorkspaceReady('/ws/proj'),
          ),
        ],
      );
      await tester.tap(find.byKey(Key('card-gaps-${item.id}')));
      await tester.pumpAndSettle();

      expect(opener.calls, ['/ws/proj/docs/non-domain.yaml']);
    });
  });

  group('acceptance 3：004 多行例外摘要以單行呈現', () {
    testWidgets('A3-1 reason 含換行：項目文字為固定說明、不含摘要原文、無換行', (tester) async {
      const multiline = 'flowBlockMalformed: 第一行\n第二行\n第三行';
      final state = gapReportStateFromRound(
        fakeRound(
          flowEvents: const [
            FlowParseFailedEvent(path: fakeUcPath, reason: multiline),
          ],
        ),
        nonDomainPathsKey: _nonDomainKey,
      );
      expect(state, isA<GapReportFound>());

      await _pump(tester, state);

      final texts = tester
          .widgetList<AppText>(
            find.descendant(
              of: find.byKey(const Key('state-gaps-found')),
              matching: find.byType(AppText),
            ),
          )
          .map((t) => t.text)
          .toList();
      expect(texts, contains(_zh.gapFlowBlockMalformed));
      expect(texts.where((t) => t.contains('\n')), isEmpty);
      expect(texts.any((t) => t.contains('第二行')), isFalse);
    });

    testWidgets('A3-1（E1）說明文字固定，與 reason 內容無關', (tester) async {
      GapReportState stateOf(String reason) => gapReportStateFromRound(
        fakeRound(
          flowEvents: [FlowParseFailedEvent(path: fakeUcPath, reason: reason)],
        ),
        nonDomainPathsKey: _nonDomainKey,
      );
      GapDescriptionKind kindOf(GapReportState s) => (s as GapReportFound)
          .categories
          .expand((c) => c.items)
          .single
          .description!
          .kind;

      expect(
        kindOf(stateOf('flowBlockMalformed')),
        kindOf(stateOf('flowBlockMalformed: a\nb')),
      );
    });
  });
}
