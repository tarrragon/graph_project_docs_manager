// 編輯器偏好的持久化與對照表契約（SPEC-003 §2.2〈編輯器對照表〉、SPEC-001 §9）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/workspace/editor_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = SharedPreferencesEditorStore();

  group('持久化', () {
    test('從未寫入：預設為系統預設（不定位）', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await store.read(), systemEditorId);
    });

    test('寫入後讀回同值，且使用 App 層鍵名', () async {
      SharedPreferences.setMockInitialValues({});

      final ok = await store.write('zed');

      expect(ok, isTrue);
      expect(await store.read(), 'zed');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(editorPreferenceKey), 'zed');
    });
  });

  group('對照表', () {
    test('首批四個，順序依規格', () {
      expect(editorTable.map((s) => s.id), [
        'vscode',
        'vscode-insiders',
        'cursor',
        'zed',
      ]);
      expect(editorTable.map((s) => s.scheme), [
        'vscode',
        'vscode-insiders',
        'cursor',
        'zed',
      ]);
    });

    test('editorById：系統預設與未知 id 為 null', () {
      expect(editorById('cursor')?.scheme, 'cursor');
      expect(editorById(systemEditorId), isNull);
      expect(editorById('emacs'), isNull);
    });

    test('editorUrlFor 組成 <scheme>://file/<路徑>:<line>', () {
      final url = editorUrlFor(editorById('vscode')!, '/p/a.md', 12);

      expect(url, 'vscode://file/p/a.md:12');
    });
  });
}
