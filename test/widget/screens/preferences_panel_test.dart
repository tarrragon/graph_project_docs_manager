// 偏好設定面板（SPEC-003 §3.8、SPEC-001 §9）：只列查得 handler 的編輯器、
// 預設系統預設、點選即持久化、已存值查無 handler 時標示落在系統預設且不改寫。
library;

import 'dart:async';

import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';
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

  /// `true` 時 [write] 回報失敗且不改變 [value]。
  bool failWrites = false;

  /// 非 null 時 [write] 等它完成才回報（控制完成時機）。
  Completer<bool>? gate;

  @override
  Future<String> read() async => value;

  @override
  Future<bool> write(String editorId) async {
    writes.add(editorId);
    final pending = gate;
    if (pending != null) return pending.future;
    if (failWrites) return false;
    value = editorId;
    return true;
  }
}

/// 面板的宿主：依 [preferencesOpenProvider] 掛載／卸載面板，與組裝根同構。
class _PanelHost extends ConsumerWidget {
  const _PanelHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(preferencesOpenProvider);
    return open ? const PreferencesPanel() : const SizedBox.shrink();
  }
}

final _l10n = AppLocalizationsZh();

/// 以面板開啟為初值掛載宿主；回傳記憶體替身與容器。
Future<(_MemoryStore, ProviderContainer)> _pumpHost(
  WidgetTester tester, {
  required Set<String> installed,
  String stored = systemEditorId,
}) async {
  final store = _MemoryStore(stored);
  final container = await pumpHarness(
    tester,
    child: const _PanelHost(),
    overrides: [
      editorHandlerProbeProvider.overrideWithValue(_SchemeProbe(installed)),
      editorPreferenceStoreProvider.overrideWithValue(store),
      preferencesOpenProvider.overrideWithInitial((_) => true),
    ],
  );
  return (store, container);
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

  testWidgets('不同值且寫入成功：寫入、面板消失、顯示套用提示並於 Motion.snackBar 後消失', (tester) async {
    final (store, container) = await _pumpHost(tester, installed: {'vscode'});

    await tester.tap(_option('vscode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.writes, ['vscode']);
    expect(container.read(preferencesOpenProvider), isFalse);
    expect(_option('vscode'), findsNothing);
    expect(
      find.text(_l10n.preferencesEditorAppliedMessage('VS Code')),
      findsOneWidget,
    );
    await tester.pump(Motion.snackBar);
    await tester.pumpAndSettle();
    expect(
      find.text(_l10n.preferencesEditorAppliedMessage('VS Code')),
      findsNothing,
    );
  });

  testWidgets('相同值：面板消失、不寫入、不提示', (tester) async {
    final (store, container) = await _pumpHost(
      tester,
      installed: {'zed'},
      stored: 'zed',
    );

    await tester.tap(_option('zed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.writes, isEmpty);
    expect(container.read(preferencesOpenProvider), isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('無可選編輯器且存值為已移除編輯器：點選系統預設會寫入並提示', (tester) async {
    final (store, container) = await _pumpHost(
      tester,
      installed: {},
      stored: 'vscode',
    );

    await tester.tap(_option(systemEditorId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.writes, [systemEditorId]);
    expect(store.value, systemEditorId);
    expect(container.read(preferencesOpenProvider), isFalse);
    expect(
      find.text(
        _l10n.preferencesEditorAppliedMessage(
          _l10n.preferencesEditorSystemOption,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('寫入未完成時按 Esc：不拋錯，寫入完成後面板已關閉', (tester) async {
    final gate = Completer<bool>();
    final store = _MemoryStore(systemEditorId)..gate = gate;
    final container = await pumpHarness(
      tester,
      child: const _PanelHost(),
      overrides: [
        editorHandlerProbeProvider.overrideWithValue(_SchemeProbe({'vscode'})),
        editorPreferenceStoreProvider.overrideWithValue(store),
        preferencesOpenProvider.overrideWithInitial((_) => true),
      ],
    );

    await tester.tap(_option('vscode'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_option('vscode'), findsNothing);

    gate.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(container.read(preferencesOpenProvider), isFalse);
  });

  testWidgets('寫入失敗：面板消失、顯示失敗提示、存值不變', (tester) async {
    final (store, container) = await _pumpHost(tester, installed: {'vscode'});
    store.failWrites = true;

    await tester.tap(_option('vscode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.writes, ['vscode']);
    expect(store.value, systemEditorId);
    expect(container.read(preferencesOpenProvider), isFalse);
    expect(find.text(_l10n.preferencesEditorSaveFailedMessage), findsOneWidget);
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
