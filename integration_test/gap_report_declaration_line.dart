/// 外圈 IT-D4 破洞報告宣告狀態行（SPEC-001-test-design §2.4；0.5.0-W1-114.13）。
///
/// 同 `domain_view_v050.dart`：不帶 `_test` 後綴，由 `app_test.dart` 的 `main()`
/// 呼叫 [registerGapReportDeclarationLineTests] 註冊。工作區由凍結快照實體化，
/// 宣告狀態變體以檔案轉換構造（`path_patterns` 補入各 domain map frontmatter、
/// 非 domain 路徑清單檔新增或改壞）；受影響路徑數與破洞數的期望值以公開
/// API（Corpus 掃描＋Graph 專案層宣告彙整）對同一工作區計算，不寫死數字。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/graph/project_path_declaration.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_projection.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';

import '../test/helpers/spec001/corpus_snapshot.dart';
import 'domain_view_v050.dart'
    show OpenWorkspace, itWidgets, pumpFramesGuarded, settleGuarded;

const _projectSnapshot = 'graph_project_docs_manager';
const _balanceSnapshot = 'flutter_balance';
const _schemaPath = '.claude/skills/doc/doc_system/core/tracking_schema.json';
const _nonDomainFile = 'docs/non-domain-paths.yaml';
const _lineKey = Key('text-gaps-declaration-line');
const _domains = [
  'schema',
  'workspace',
  'corpus',
  'history',
  'diagnostics',
  'graph',
  'ticketdetail',
  'layout',
];

void registerGapReportDeclarationLineTests(OpenWorkspace open) {
  group('IT-D4 破洞報告宣告狀態行', () {
    itWidgets('ITD4-A1 兩側皆無宣告：本專案未宣告路徑，不含路徑數', (tester) async {
      final workspace = await materializeSnapshotWorkspace(_balanceSnapshot);
      await open(tester, workspace);

      await _openGapReport(tester);

      expect(_lineText(tester), _l10n(tester).pathDeclarationNoneLine);
      await workspace.delete(recursive: true);
    });

    for (final locale in const [Locale('zh'), Locale('en')]) {
      itWidgets(
        'ITD4-A2 部分宣告：5／8 個 domain、缺非 domain 清單（${locale.languageCode}）',
        (tester) async {
          final workspace = await _partialWorkspace();
          final expected = await _declarationOf(workspace);
          await open(tester, workspace, locale: locale);

          await _openGapReport(tester);

          final l10n = _l10n(tester);
          expect(
            expected.affectedPathCount,
            greaterThan(0),
            reason: '快照無 ticket 時 count 恆為 0；本案補了 ticket 才有鑑別力',
          );
          final detail = [
            l10n.pathDeclarationBundlesPartial(5, 8),
            l10n.pathDeclarationNonDomainMissing,
          ].join(_listSeparator(l10n));
          expect(
            _lineText(tester),
            l10n.pathDeclarationIncompleteLine(
              detail,
              expected.affectedPathCount ?? 0,
            ),
          );
          await workspace.delete(recursive: true);
        },
      );
    }

    itWidgets('ITD4-A3 補齊宣告後行消失，破洞數與 A2 相同（E1 對照）', (tester) async {
      final partial = await _partialWorkspace();
      await open(tester, partial);
      await _openGapReport(tester);
      final partialGaps = _gapCount(tester);
      final full = await _fullWorkspace();

      await open(tester, full);
      await _openGapReport(tester);

      expect(find.byKey(_lineKey), findsNothing);
      expect(_gapCount(tester), partialGaps, reason: '宣告缺口不計入破洞數');
      await partial.delete(recursive: true);
      await full.delete(recursive: true);
    });

    itWidgets('ITD4-A4 掃描中宣告狀態行不出現', (tester) async {
      final workspace = await materializeSnapshotWorkspace(_balanceSnapshot);
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });

      await open(
        tester,
        workspace,
        settle: false,
        overrides: [
          scanCorpusFnProvider.overrideWithValue(({
            required fileSystem,
            required table,
            required builtinTable,
          }) async {
            await gate.future;
            return scanCorpus(
              fileSystem: fileSystem,
              table: table,
              builtinTable: builtinTable,
            );
          }),
        ],
      );
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('nav-item-gaps')));
      await _pumpFrames(tester);

      expect(find.byKey(const Key('state-gaps-scanning')), findsOneWidget);
      expect(find.byKey(_lineKey), findsNothing);
      gate.complete();
      await settleGuarded(tester, 'pumpAndSettle');
      expect(find.byKey(_lineKey), findsOneWidget, reason: '掃描完成後（兩側皆無宣告）行出現');
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD4-A5 非 domain 清單格式錯誤與缺席的對照（E1 對照）', (tester) async {
      final full = await _fullWorkspace();
      await open(tester, full);
      await _openGapReport(tester);
      final fullGaps = _gapCount(tester);
      final malformed = await _fullWorkspace(
        nonDomainContent: 'non_domain_path_patterns: [unclosed',
      );
      final missing = await _fullWorkspace(nonDomainContent: null);

      await open(tester, malformed);
      await _openGapReport(tester);
      final l10n = _l10n(tester);
      final malformedLine = _lineText(tester);
      expect(malformedLine, contains(l10n.pathDeclarationNonDomainMalformed));
      expect(
        malformedLine,
        isNot(contains(l10n.pathDeclarationNonDomainMissing)),
      );
      expect(_gapCount(tester), fullGaps + 1);
      expect(
        _itemsOf(tester, gapCategoryIdNonDomainPathsMalformed),
        hasLength(1),
      );

      await open(tester, missing);
      await _openGapReport(tester);
      final missingLine = _lineText(tester);
      expect(missingLine, contains(l10n.pathDeclarationNonDomainMissing));
      expect(
        missingLine,
        isNot(contains(l10n.pathDeclarationNonDomainMalformed)),
      );
      expect(_gapCount(tester), fullGaps, reason: '刪除清單檔只是缺席，不新增破洞');
      for (final dir in [full, malformed, missing]) {
        await dir.delete(recursive: true);
      }
    });
  });
}

/// 本專案快照，8 個 bundle 中前 5 個補 `path_patterns`，無非 domain 清單。
/// 帶一張 `where.files` 落在任何 bundle 與非 domain 清單之外的 ticket，使
/// 受影響路徑數大於 0（否則 `{count}` 恆為 0，斷言恆真）。
const _ticketFile = {
  'docs/work-logs/v0.0.1/tickets/0.0.1-W1-001.md': '---\nid: 0.0.1-W1-001\nwhere:\n  files:\n    - outside/undeclared/a.txt\n    - outside/undeclared/b.txt\n---\n',
};

Future<Directory> _partialWorkspace() => materializeSnapshotWorkspace(
  _projectSnapshot,
  extraFiles: _ticketFile,
  transforms: _pathPatternTransforms(_domains.take(5)),
);

/// 8 個 bundle 皆宣告；非 domain 清單預設為合法清單，傳 `null` 為不放該檔。
Future<Directory> _fullWorkspace({
  String? nonDomainContent = 'non_domain_path_patterns: ["docs/**"]\n',
}) => materializeSnapshotWorkspace(
  _projectSnapshot,
  transforms: _pathPatternTransforms(_domains),
  extraFiles: {..._ticketFile, _nonDomainFile: ?nonDomainContent},
);

Map<String, SnapshotTransform> _pathPatternTransforms(
  Iterable<String> domains,
) => {
  for (final domain in domains)
    'docs/spec/$domain/domain-map.md': (original) => original.replaceFirst(
      '\n---\n',
      '\npath_patterns: ["lib/$domain/**"]\n---\n',
    ),
};

Future<ProjectPathDeclaration> _declarationOf(Directory workspace) async {
  final schemaJson = jsonDecode(
    File('${workspace.path}/$_schemaPath').readAsStringSync(),
  ) as Map<String, dynamic>;
  final table = typeTableFromJson(schemaJson);
  final scan = await scanCorpus(
    fileSystem: DefaultDocsFileSystem(workspace.path),
    table: table,
    builtinTable: table,
  );
  return summarizeProjectPathDeclaration(
    rawNodes: scan.rawNodes,
    nonDomain: scan.nonDomainPathsRead,
  );
}

Future<void> _openGapReport(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-item-gaps')));
  await settleGuarded(tester, 'pumpAndSettle');
}

Future<void> _pumpFrames(WidgetTester tester) =>
    pumpFramesGuarded(tester, 'gap-report pump 5 幀');

/// 期望分隔符的獨立語系對照（不複製 lib 判斷式；新增語系時須補項）。
String _listSeparator(AppLocalizations l10n) =>
    const {'zh': '、', 'en': ', '}[l10n.localeName.split('_').first]!;

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(const Key('nav-page-gaps'))));

String _lineText(WidgetTester tester) {
  expect(find.byKey(_lineKey), findsOneWidget, reason: '宣告狀態行應出現');
  final text = find.descendant(
    of: find.byKey(_lineKey),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(text.first).data ?? '';
}

List<GapReportCategory> _categories(WidgetTester tester) {
  final state = ProviderScope.containerOf(
    tester.element(find.byType(DocsManagerApp)),
  ).read(gapReportProvider);
  return switch (state) {
    GapReportFound(:final categories) => categories,
    GapReportUndeterminable(:final categories) => categories,
    GapReportNoGaps() => const <GapReportCategory>[],
    _ => throw StateError('報告頁未進入結果狀態：$state'), // i18n-exempt: 測試診斷訊息
  };
}

int _gapCount(WidgetTester tester) =>
    _categories(tester).fold<int>(0, (sum, c) => sum + c.items.length);

List<GapReportItem> _itemsOf(WidgetTester tester, String categoryId) => [
  for (final c in _categories(tester))
    if (c.id == categoryId) ...c.items,
];
