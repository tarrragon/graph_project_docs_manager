/// SPEC-006 FR-11 規則 3：事件過濾（0.6.0-W1-080 Phase 2 紅燈）。
///
/// Phase 3b 待補 stub：`lib/corpus/corpus_watch.dart` 的 [isScanInputPath]。
/// 每組丟棄案例皆與保留案例並列（E2 正向對照）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';

void main() {
  group('FR-11 規則 3 事件過濾', () {
    test('保留：docs/ 下小寫 .md（含巢狀）', () {
      expect(isScanInputPath('docs/a.md'), isTrue);
      expect(isScanInputPath('docs/spec/ui/SPEC-003.md'), isTrue);
    });

    test('保留：FR-12 兩個主題檔與 FR-10 非 domain 路徑清單檔', () {
      expect(isScanInputPath('docs/work-logs/topic-assignments.txt'), isTrue);
      expect(isScanInputPath('docs/work-logs/topics-registry.txt'), isTrue);
      expect(
        isScanInputPath(
          'docs/non-domain.yaml',
          nonDomainPathsLocation: 'docs/non-domain.yaml',
        ),
        isTrue,
      );
      // 對照：未宣告位置時同一路徑不是掃描輸入。
      expect(isScanInputPath('docs/non-domain.yaml'), isFalse);
    });

    test('丟棄：.swp／~／.DS_Store／大寫 .MD，同目錄 .md 對照保留', () {
      expect(isScanInputPath('docs/a.md'), isTrue);
      expect(isScanInputPath('docs/a.swp'), isFalse);
      expect(isScanInputPath('docs/a.md~'), isFalse);
      expect(isScanInputPath('docs/.DS_Store'), isFalse);
      expect(isScanInputPath('docs/a.MD'), isFalse);
    });

    test('丟棄：docs/ 外的 .md 與版本控制目錄、專案型別表', () {
      expect(isScanInputPath('README.md'), isFalse);
      expect(isScanInputPath('.git/HEAD'), isFalse);
      expect(isScanInputPath('docs/.git/index'), isFalse);
      expect(
        isScanInputPath(
          '.claude/skills/doc/doc_system/core/tracking_schema.json',
        ),
        isFalse,
      );
    });
  });
}
