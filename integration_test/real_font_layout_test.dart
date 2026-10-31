/// 實機字型版面斷言（0.5.0-W1-465.2）。
///
/// 以實機系統字型重跑 widget test 既有的 `expectNoOverflow` 與
/// `expectNoVerticalClip`，補上「容器高度介於測試字型與實機字型固有高度之間」
/// 的缺口。預期值出處：尺寸集合 SPEC-004 §1「測試尺寸集合」（`WindowSize`）、
/// 六畫面 SPEC-004 §3 AppShell「NavItem x 6」（`AppDestination.values`）、
/// 不溢位 SPEC-004 §1「縮放策略」。
///
/// 單獨執行：`fvm flutter test integration_test/real_font_layout_test.dart -d macos`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/pump_harness.dart';
import '../test/helpers/window_sizes.dart';
import 'research/ux_variants.dart';

/// 元件 -> 其固定高度容器內的內容節點 finder（對照 test/unit/components）。
final Map<String, Finder Function(Finder host)> _contentOf = {
  'NavItem': (h) => find.descendant(of: h, matching: find.byType(Row)),
  'SearchField': (h) => find.descendant(of: h, matching: find.byType(Row)),
  'FilterDropdown': (h) => find.descendant(of: h, matching: find.byType(Row)),
  'ProjectSwitcherEntry': (h) =>
      find.descendant(of: h, matching: find.byType(Row)),
  'SegmentedControl': (h) =>
      find.descendant(of: h, matching: find.byType(Text)),
};

Finder _hosts(String name) => switch (name) {
  'NavItem' => find.byType(NavItem),
  'SearchField' => find.byType(SearchField),
  'FilterDropdown' => find.byType(FilterDropdown),
  'ProjectSwitcherEntry' => find.byType(ProjectSwitcherEntry),
  _ => find.byType(SegmentedControl),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final destination in AppDestination.values) {
    for (final size in WindowSize.values) {
      testWidgets('實機字型 ${destination.name} @ ${size.label}', (tester) async {
        final fixture = UxFixture(
          snapshot: 'graph_project_docs_manager',
          locale: const Locale('zh'),
        );
        await fixture.materialize();
        addTearDown(fixture.dispose);
        setWindowSize(tester, size);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              ...await fixtureOverrides(),
              if (destination != AppDestination.domain)
                selectedDestinationProvider.overrideWith((ref) => destination),
            ],
            child: DocsManagerApp(
              locale: fixture.locale,
              repository: UxStubRepository(
                WorkspaceReady(fixture.workspace.path),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );

        expectNoOverflow(tester);
        final counts = <String, int>{};
        for (final name in _contentOf.keys) {
          final hosts = _hosts(name).evaluate().length;
          var checked = 0;
          for (var i = 0; i < hosts; i++) {
            final content = _contentOf[name]!(_hosts(name).at(i));
            for (var j = 0; j < content.evaluate().length; j++) {
              expectNoVerticalClip(tester, content.at(j));
              checked++;
            }
          }
          counts[name] = checked;
        }
        // ignore: avoid_print
        print('REAL_FONT_NODES ${destination.name} ${size.label} $counts');
        expect(counts['NavItem'], greaterThan(0), reason: '導覽殼必有 NavItem');
      });
    }
  }

  testWidgets('正向對照：固定高度小於內容固有高度時 expectNoVerticalClip 紅燈', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 4,
            child: Row(
              children: [Text('測試 Ag', style: TextStyle(fontSize: 40))],
            ),
          ),
        ),
      ),
    );
    tester.takeException();
    expect(
      () => expectNoVerticalClip(tester, find.byType(Text)),
      throwsA(isA<TestFailure>()),
    );
  });
}
