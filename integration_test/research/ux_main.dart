/// 路徑 (a) 的研究入口：`fvm flutter run -t integration_test/research/ux_main.dart -d macos`
/// 之後以 `fvm flutter screenshot` 擷取（0.5.0-W1-466.2 試跑用，放在 lib/ 以外）。
///
/// 以 fixture 工作區啟動真實 App；視窗尺寸由 macOS 端決定（預設 1280x800）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import 'ux_variants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = UxFixture(
    snapshot: 'graph_project_docs_manager',
    locale: const Locale('zh'),
  );
  await fixture.materialize();
  runApp(
    ProviderScope(
      overrides: await fixtureOverrides(),
      child: DocsManagerApp(
        locale: fixture.locale,
        repository: UxStubRepository(WorkspaceReady(fixture.workspace.path)),
      ),
    ),
  );
}
