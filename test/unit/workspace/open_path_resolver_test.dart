import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/workspace/open_path_resolver.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

void main() {
  group('resolveOpenPath', () {
    final logs = <String>[];
    void capture(String message, {int level = 0}) =>
        logs.add('$level|$message');

    setUp(logs.clear);

    test('規則 1：絕對路徑原樣回傳，不論 workspace 狀態', () {
      for (final ws in <WorkspaceState>[
        const WorkspaceUnset(),
        const WorkspaceReady('/ws/proj'),
      ]) {
        expect(resolveOpenPath(ws, '/tmp/a.md', log: capture), '/tmp/a.md');
      }
      expect(logs, isEmpty);
    });

    test('規則 2：相對路徑且 Ready，以專案根目錄組合', () {
      expect(
        resolveOpenPath(
          const WorkspaceReady('/ws/proj'),
          'docs/usecases/UC-02.md',
          log: capture,
        ),
        '/ws/proj/docs/usecases/UC-02.md',
      );
      expect(logs, isEmpty);
    });

    test('規則 3：相對路徑且非 Ready，回傳 null 並記 warning（含型別與原始路徑）', () {
      final result = resolveOpenPath(
        const WorkspaceUnset(),
        'docs/a.md',
        log: capture,
      );
      expect(result, isNull);
      expect(logs, hasLength(1));
      expect(logs.single, startsWith('900|'));
      expect(logs.single, contains('WorkspaceUnset'));
      expect(logs.single, contains('docs/a.md'));
    });
  });
}
