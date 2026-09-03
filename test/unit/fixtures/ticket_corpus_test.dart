// 需求：Ticket 節點檔版本切片 fixture 存在性驗證
//
// 本測試不解析 tracking_schema，只驗證 fixture 本身的完整性：
// README 登記的缺 frontmatter 樣本檔案確實存在、且正常（含
// frontmatter）票數達到 README 記錄的規模門檻。真正的 frontmatter
// 語意解析由框架 doc_system.core.frontmatter_parser 負責（見
// test/fixtures/corpus/book_overview_app/docs/work-logs/README.md
// 的驗證方式段落），本測試只守護 fixture 檔案本身不被意外刪減。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workLogsDir = Directory(
    'test/fixtures/corpus/book_overview_app/docs/work-logs',
  );

  // README 記錄的 14 個缺 frontmatter 樣本相對路徑（見同目錄
  // README.md「缺 frontmatter 樣本清單」章節）。清單中的檔名為來源
  // 語料專案 book_overview_app 內部既有 ticket 檔名，非本框架 ticket。
  // rule8-exempt: testdata:以下常數清單為 fixture 測資檔名，來自來源語料專案 book_overview_app 既有 ticket，非本框架 ticket 引用
  const knownMissingFrontmatterFiles = [
    'v0/v0.25/v0.25.0/tickets/0.25.0-W1-010.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.25/v0.25.0/tickets/W2-003-KEY-FINDINGS.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.25/v0.25.0/tickets/W2-003-unit-test-failure-analysis.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.25/v0.25.0/tickets/W3-003-DESIGN-DECISIONS-NEEDED.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W22-001.1-phase2-summary.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W27-001-integration-eval-catalog.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W3-002.2-completion-summary.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W4-036-FEASIBILITY-REPORT.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W4-036.9-COMPLETION.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W4-037.4-SUMMARY.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W4-054.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W8-003-phase3a-strategy.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/0.31.0-W8-003-test-design.md', // rule8-exempt: testdata:fixture 測資檔名
    'v0/v0.31/v0.31.0/tickets/phase4-refactor-assessment.md',
  ];

  group('Ticket 節點檔版本切片 fixture', () {
    test('版本切片目錄存在', () {
      expect(
        workLogsDir.existsSync(),
        isTrue,
        reason: '${workLogsDir.path} 應存在（版本切片入庫）',
      );
    });

    test('README 登記的缺 frontmatter 樣本檔案皆存在', () {
      for (final relativePath in knownMissingFrontmatterFiles) {
        final file = File('${workLogsDir.path}/$relativePath');
        expect(
          file.existsSync(),
          isTrue,
          reason: '缺 frontmatter 樣本應存在：$relativePath',
        );
      }
    });

    test('正常（含 frontmatter）票數達到 README 記錄的規模門檻', () {
      final ticketFiles = workLogsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.md') && f.path.contains('/tickets/'),
          )
          .toList();

      final missingFrontmatterPaths = knownMissingFrontmatterFiles
          .map((p) => '${workLogsDir.path}/$p')
          .toSet();

      final normalTicketCount = ticketFiles
          .where((f) => !missingFrontmatterPaths.contains(f.path))
          .length;

      // README 記錄可解析票數為 759（58 + 715 - 14）。門檻取 30，
      // 對應 acceptance 對「正常票數」的最低要求。
      expect(
        normalTicketCount,
        greaterThanOrEqualTo(30),
        reason: '正常票數應 >= 30，實際 $normalTicketCount',
      );
    });

    test('正常票的 frontmatter 皆以 --- 定界符起始（結構完整性）', () {
      final ticketFiles = workLogsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.md') && f.path.contains('/tickets/'),
          )
          .toList();

      final missingFrontmatterPaths = knownMissingFrontmatterFiles
          .map((p) => '${workLogsDir.path}/$p')
          .toSet();

      for (final file in ticketFiles) {
        if (missingFrontmatterPaths.contains(file.path)) {
          continue;
        }
        final firstLine = file.readAsLinesSync().firstOrNull;
        expect(
          firstLine?.trim(),
          '---',
          reason: '${file.path} 應以 --- frontmatter 定界符起始',
        );
      }
    });
  });
}
