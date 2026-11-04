// 偏好設定面板（SPEC-003 §3.8、SPEC-001 §9）：只列查得 handler 的編輯器、
// 預設系統預設、點選即持久化、已存值查無 handler 時標示落在系統預設且不改寫。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/preferences/preferences_panel.dart';
import 'package:graph_project_docs_manager/services/macos_preferences_channel.dart';
import 'package:graph_project_docs_manager/workspace/editor_preference.dart';

import '../../helpers/helpers.dart';

class _SchemeProbe implements EditorHandlerProbe {
  _SchemeProbe(this.installed);

  final Set<String> installed;

  @override
  Future<bool> hasHandler(String scheme) async => installed.contains(scheme);
}

class _MemoryStore implements EditorPreferenceStore {
  _MemoryStore(this.value);

  String value;
  final List<String> writes = [];

  @override
  Future<String> read() async => value;

  @override
  Future<void> write(String editorId) async {
    writes.add(editorId);
    value = editorId;
  }
}

Finder _option(String id) => find.byKey(Key('option-preferences-editor-$id'));

bool _isSelected(WidgetTester tester, String id) => tester
    .widget<ListRow>(
      find.ancestor(of: _option(id), matching: find.byType(ListRow)),
    )
    .isSelected;

Future<_MemoryStore> _pump(
  WidgetTester tester, {
  required Set<String> installed,
  String stored = systemEditorId,
}) async {
  final store = _MemoryStore(stored);
  await pumpHarness(
    tester,
    child: const PreferencesPanel(),
    overrides: [
      editorHandlerProbeProvider.overrideWithValue(_SchemeProbe(installed)),
      editorPreferenceStoreProvider.overrideWithValue(store),
    ],
  );
  return store;
}

void main() {
  testWidgets('只列查得 handler 的編輯器，系統預設恆排第一且預設選取', (tester) async {
    await _pump(tester, installed: {'cursor', 'vscode'});

    expect(find.byKey(const Key('state-preferences-editors')), findsOneWidget);
    expect(_option(systemEditorId), findsOneWidget);
    expect(_option('vscode'), findsOneWidget);
    expect(_option('cursor'), findsOneWidget);
    expect(_option('zed'), findsNothing);
    expect(_option('vscode-insiders'), findsNothing);
    expect(_isSelected(tester, systemEditorId), isTrue);
  });

  testWidgets('點選編輯器：選取改變並立即持久化', (tester) async {
    final store = await _pump(tester, installed: {'vscode'});

    await tester.tap(_option('vscode'));
    await tester.pump();

    expect(_isSelected(tester, 'vscode'), isTrue);
    expect(_isSelected(tester, systemEditorId), isFalse);
    expect(store.writes, ['vscode']);
  });

  testWidgets('已存編輯器仍可用：選取標示落在該編輯器', (tester) async {
    await _pump(tester, installed: {'zed'}, stored: 'zed');

    expect(_isSelected(tester, 'zed'), isTrue);
  });

  testWidgets('對照：已存編輯器查無 handler：標示落在系統預設，存值不改寫', (tester) async {
    final store = await _pump(tester, installed: {'zed'}, stored: 'vscode');

    expect(_option('vscode'), findsNothing);
    expect(_isSelected(tester, systemEditorId), isTrue);
    expect(store.writes, isEmpty);
    expect(store.value, 'vscode');
  });

  testWidgets('全部查無 handler：無可選編輯器狀態，只有系統預設且說明文字常駐', (tester) async {
    await _pump(tester, installed: {});

    expect(
      find.byKey(const Key('state-preferences-no-editors')),
      findsOneWidget,
    );
    expect(_option(systemEditorId), findsOneWidget);
    expect(_isSelected(tester, systemEditorId), isTrue);
    expect(find.textContaining('VS Code Insiders'), findsOneWidget);
  });

  testWidgets('關閉鈕把 preferencesOpenProvider 設回 false', (tester) async {
    final container = ProviderContainer.test(
      overrides: [
        editorHandlerProbeProvider.overrideWithValue(_SchemeProbe({})),
        editorPreferenceStoreProvider.overrideWithValue(_MemoryStore('system')),
      ],
    );
    container.read(preferencesOpenProvider.notifier).state = true;
    await pumpHarness(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const PreferencesPanel(),
      ),
    );

    await tester.tap(find.byKey(const Key('action-preferences-close')));
    await tester.pump();

    expect(container.read(preferencesOpenProvider), isFalse);
  });
}
