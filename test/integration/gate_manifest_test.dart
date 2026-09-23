/// gate 偵測整合測試：17 列凍結 manifest（來源 `0.2.0-W1-032` Solution
/// §1，SPEC-001 v1.18〈Gate 三問對照〉判定順序）+ 2 個邊界案例
/// （`0.2.0-W1-033` acceptance）。
///
/// 每列以 mock [FrameworkSignalProbePort] 驅動 [GateDetectionNotifier]，
/// 斷言最終 [DomainViewState]，不依賴 `~/project`（`0.2.0-W1-032` Solution
/// §6 方案 A：CI 環境無 `~/project`，凍結 fixture 才可行）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';

/// App 內建版本（`assets/schema/builtin_schema_version.json`，同
/// `0.2.0-W1-032` manifest 量測當下值），測試以固定值覆寫
/// [builtinSchemaVersionProvider] 避免依賴 asset bundle 讀取。
const _kBuiltinVersion = '2.40.3';

/// gate 判定分支枚舉，供斷言比對用（不使用字串比對 [DomainViewState]
/// runtimeType 以外的細節，manifest 表的「預期分支」欄直接對應）。
enum _ExpectedBranch { notFramework, unconsumable, ready, incompatible }

class _ManifestRow {
  const _ManifestRow({
    required this.projectName,
    required this.version,
    required this.jsonExists,
    required this.expected,
    this.jsonVersion,
  });

  final String projectName;
  final String? version;
  final bool jsonExists;

  /// JSON 存在時的 `schema_generated_at_framework_version`；本 manifest
  /// 中「兩訊號皆有」的列一律等於 [_kBuiltinVersion]（`0.2.0-W1-032` §1
  /// 實測值），與該列的 VERSION 值（可能遠高於 builtin）無關——範圍判定
  /// 恆以 JSON 版本比較（`0.2.0-W1-024` 定案）。
  final String? jsonVersion;

  final _ExpectedBranch expected;
}

class _FixtureProbe implements FrameworkSignalProbePort {
  const _FixtureProbe(this.row);

  final _ManifestRow row;

  @override
  Future<String?> readVersion(String workspacePath) async => row.version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async =>
      row.jsonExists;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async =>
      row.jsonVersion;
}

/// `0.2.0-W1-032` Solution §1 的 17 列凍結 manifest。
const _kManifest = <_ManifestRow>[
  _ManifestRow(
    projectName: 'adb_install',
    version: null,
    jsonExists: false,
    expected: _ExpectedBranch.notFramework,
  ),
  _ManifestRow(
    projectName: 'blog',
    version: null,
    jsonExists: false,
    expected: _ExpectedBranch.notFramework,
  ),
  _ManifestRow(
    projectName: 'cc-statusline',
    version: null,
    jsonExists: false,
    expected: _ExpectedBranch.notFramework,
  ),
  _ManifestRow(
    projectName: 'japanese_learning_blog',
    version: null,
    jsonExists: false,
    expected: _ExpectedBranch.notFramework,
  ),
  _ManifestRow(
    projectName: 'translate',
    version: null,
    jsonExists: false,
    expected: _ExpectedBranch.notFramework,
  ),
  _ManifestRow(
    projectName: 'unipos',
    version: null,
    jsonExists: false,
    expected: _ExpectedBranch.notFramework,
  ),
  _ManifestRow(
    projectName: 'app_tunnel',
    version: '2.22.1',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'book_overview_app',
    version: '2.27.8',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'book_overview_v1',
    version: '2.27.8',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'c2c_website',
    version: '1.1.46',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'ccsession-0.2.0-W7-002',
    version: '1.4.0',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'ccsession-0.2.0-W7-004',
    version: '1.4.0',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'ccsession',
    version: '1.23.1',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'monitor',
    version: '2.22.1',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'screen_clock',
    version: '2.24.0',
    jsonExists: false,
    expected: _ExpectedBranch.unconsumable,
  ),
  _ManifestRow(
    projectName: 'flutter_balance',
    version: '2.59.9',
    jsonExists: true,
    jsonVersion: _kBuiltinVersion,
    expected: _ExpectedBranch.ready,
  ),
  _ManifestRow(
    projectName: 'graph_project_docs_manager',
    version: '2.60.3',
    jsonExists: true,
    jsonVersion: _kBuiltinVersion,
    expected: _ExpectedBranch.ready,
  ),
];

/// 邊界案例：VERSION 缺 + JSON 有，推定版本在範圍內（`0.2.0-W1-038`
/// 方案 A）。
const _kVersionMissingJsonPresentInRange = _ManifestRow(
  projectName: '(邊界) VERSION 缺 + JSON 有，推定版本在範圍內',
  version: null,
  jsonExists: true,
  jsonVersion: _kBuiltinVersion,
  expected: _ExpectedBranch.ready,
);

/// 邊界案例：JSON 版本高於內建版本（不論 VERSION 是否存在，範圍判定
/// 恆以 JSON 版本為準，`0.2.0-W1-024` 定案）。
const _kJsonVersionHigherThanBuiltin = _ManifestRow(
  projectName: '(邊界) JSON 版本高於內建版本',
  version: '2.60.3',
  jsonExists: true,
  jsonVersion: '99.0.0',
  expected: _ExpectedBranch.incompatible,
);

_ExpectedBranch _branchOf(DomainViewState state) {
  return switch (state) {
    DomainNotFramework() => _ExpectedBranch.notFramework,
    DomainSchemaUnconsumable() => _ExpectedBranch.unconsumable,
    DomainReady() => _ExpectedBranch.ready,
    DomainSchemaIncompatible() => _ExpectedBranch.incompatible,
    _ => throw StateError('未預期的 gate 偵測結果：$state'),
  };
}

Future<void> _runRow(_ManifestRow row) async {
  final container = ProviderContainer(
    overrides: [
      frameworkSignalProbeProvider.overrideWithValue(_FixtureProbe(row)),
      builtinSchemaVersionProvider.overrideWith(
        (ref) async => _kBuiltinVersion,
      ),
    ],
  );
  addTearDown(container.dispose);

  await container
      .read(gateDetectionNotifierProvider.notifier)
      .detect('/fixture/${row.projectName}');

  final state = container.read(domainViewStateProvider);
  expect(
    _branchOf(state),
    row.expected,
    reason:
        '${row.projectName}: version=${row.version} jsonExists='
        '${row.jsonExists} jsonVersion=${row.jsonVersion} → 得到 $state',
  );
}

void main() {
  group('gate 偵測整合測試：17 列凍結 manifest（0.2.0-W1-032 §1）', () {
    for (final row in _kManifest) {
      test(row.projectName, () => _runRow(row));
    }

    final byBranch = <_ExpectedBranch, int>{};
    for (final row in _kManifest) {
      byBranch[row.expected] = (byBranch[row.expected] ?? 0) + 1;
    }

    test('分佈守恆：不是框架專案 6 / 無可消費的型別表 9 / 正常 2', () {
      expect(byBranch[_ExpectedBranch.notFramework], 6);
      expect(byBranch[_ExpectedBranch.unconsumable], 9);
      expect(byBranch[_ExpectedBranch.ready], 2);
      expect(byBranch[_ExpectedBranch.incompatible], isNull);
    });
  });

  group('gate 偵測整合測試：邊界案例', () {
    test(
      _kVersionMissingJsonPresentInRange.projectName,
      () => _runRow(_kVersionMissingJsonPresentInRange),
    );
    test(
      _kJsonVersionHigherThanBuiltin.projectName,
      () => _runRow(_kJsonVersionHigherThanBuiltin),
    );
  });
}
