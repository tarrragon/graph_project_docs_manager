import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/services/directory_watch_source.dart';
import 'package:watcher/watcher.dart';

WatchChange _convert(String root, ChangeType type, String path) =>
    DirectoryWatchSource.toWatchChange(root, WatchEvent(type, path));

void main() {
  group('toWatchChange', () {
    test('一般路徑轉為相對 / 形式並對應三種 kind', () {
      final add = _convert('/w', ChangeType.ADD, '/w/docs/a.md');
      expect(add.relativePath, 'docs/a.md');
      expect(add.kind, WatchChangeKind.created);
      expect(
        _convert('/w', ChangeType.MODIFY, '/w/docs/a.md').kind,
        WatchChangeKind.modified,
      );
      expect(
        _convert('/w', ChangeType.REMOVE, '/w/docs/a.md').kind,
        WatchChangeKind.deleted,
      );
    });

    test('子目錄路徑', () {
      final c = _convert('/w', ChangeType.MODIFY, '/w/docs/spec/ui/x.md');
      expect(c.relativePath, 'docs/spec/ui/x.md');
    });

    test('event.path 帶 /private 前綴而 root 沒有：現況產生 ../ 開頭（B10 定位用）', () {
      final c = _convert(
        '/var/folders/w',
        ChangeType.MODIFY,
        '/private/var/folders/w/docs/a.md',
      );
      expect(c.relativePath, '../../../private/var/folders/w/docs/a.md');
      expect(c.relativePath.startsWith('docs/'), isFalse);
    });
  });
}
