// SPEC-008 測試設計 §3.1 P-10：二進位條目與大寫副檔名 `.MD` 不建立狀態
// （FR-01 規則 4，小寫 `.md` 限定）。以正向對照證明「不建立」具鑑別力。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';

import '../../../helpers/history/synthetic_git_log.dart';

List<ScanCommitResult> _scan(SyntheticLogBuilder b) {
  final parser = ScanStreamParser();
  return [...parser.addChunk(b.toBytes()), ...parser.close()];
}

void main() {
  group('P-10 非小寫 .md 與二進位條目不建立狀態', () {
    final fmLines = frontmatterLines({'id': 'A', 'parent_id': 'P'});

    test('二進位條目與 README.MD 不出現在變更中', () {
      final results = _scan(
        SyntheticLogBuilder().commit(
          'a',
          files: [
            LogFileEntry.binary('docs/img.png'),
            LogFileEntry.added('docs/README.MD', fmLines),
          ],
        ),
      );
      expect(results.single.changes, isEmpty);
    });

    test('正向對照：同內容的小寫 .md 建立狀態並帶出 frontmatter', () {
      final parser = ScanStreamParser();
      final results = [
        ...parser.addChunk(
          SyntheticLogBuilder()
              .commit(
                'a',
                files: [
                  LogFileEntry.binary('docs/img.png'),
                  LogFileEntry.added('docs/README.MD', fmLines),
                  LogFileEntry.added('docs/readme.md', fmLines),
                ],
              )
              .toBytes(),
        ),
        ...parser.close(),
      ];
      expect(results.single.changes.map((c) => c.path), ['docs/readme.md']);
      expect(parser.fileLines('docs/README.MD'), isNull);
      expect(parser.fileLines('docs/img.png'), isNull);
      expect(parser.fileLines('docs/readme.md'), isNotNull);
    });
  });
}
