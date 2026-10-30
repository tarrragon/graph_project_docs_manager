import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_loader.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../../helpers/gap_round_fakes.dart';

/// 測試用 [FrameworkSignalProbePort]：三項訊號由建構子固定值直接回傳，
/// 不接觸真實檔案系統。
class _FakeProbe implements FrameworkSignalProbePort {
  _FakeProbe({this.version, this.jsonExists = false, this.jsonVersion});

  final String? version;
  final bool jsonExists;
  final String? jsonVersion;

  @override
  Future<String?> readVersion(String workspacePath) async => version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => jsonExists;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async =>
      jsonVersion;
}

/// 第一次 ensureRound 卡在 [gate]，其後依 FakeScanRound 預設行為。
class _GatedScanRound extends FakeScanRound {
  _GatedScanRound(this.gate) : super(produce: _unavailableRound);

  final Completer<ScanRoundResult?> gate;
  bool _first = true;

  @override
  Future<ScanRoundResult?> ensureRound() {
    if (_first) {
      _first = false;
      return gate.future;
    }
    return super.ensureRound();
  }
}

ScanRoundResult _unavailableRound() =>
    fakeRound(graphUnavailable: EdgeTypeUnavailableReason.values.first);

ProviderContainer _buildContainer(FrameworkSignalProbePort probe) {
  final container = ProviderContainer(
    overrides: [
      frameworkSignalProbeProvider.overrideWithValue(probe),
      builtinSchemaVersionProvider.overrideWith((ref) async => '2.40.3'),
      // gate 通過後經共用輪次載入（0.5.0-W1-114.14）。
      scanRoundProvider.overrideWith(
        () => FakeScanRound(produce: () => fakeRound()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('GateDetectionNotifier', () {
    test('兩訊號皆缺 → DomainNotFramework', () async {
      final container = _buildContainer(_FakeProbe());

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      expect(
        container.read(domainViewStateProvider),
        isA<DomainNotFramework>(),
      );
      expect(container.read(inferredVersionProvider), isNull);
    });

    test('VERSION 有、JSON 缺 → DomainSchemaUnconsumable 帶 VERSION 值', () async {
      final container = _buildContainer(_FakeProbe(version: '2.22.1'));

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      final state = container.read(domainViewStateProvider);
      expect(state, isA<DomainSchemaUnconsumable>());
      expect((state as DomainSchemaUnconsumable).version, '2.22.1');
    });

    test('JSON 有、版本在範圍內 → DomainReady（非推定）', () async {
      final container = _buildContainer(
        _FakeProbe(version: '2.60.3', jsonExists: true, jsonVersion: '2.40.3'),
      );

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      final state = container.read(domainViewStateProvider);
      expect(state, isA<DomainReady>());
      expect((state as DomainReady).inferredVersion, isNull);
      expect(container.read(inferredVersionProvider), isNull);
    });

    test('JSON 有、版本超出範圍 → DomainSchemaIncompatible（非推定）', () async {
      final container = _buildContainer(
        _FakeProbe(version: '2.10.0', jsonExists: true, jsonVersion: '2.90.0'),
      );

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      final state = container.read(domainViewStateProvider);
      expect(state, isA<DomainSchemaIncompatible>());
      final incompatible = state as DomainSchemaIncompatible;
      expect(incompatible.appVersion, '2.40.3');
      expect(incompatible.projectVersion, '2.10.0');
      expect(incompatible.isVersionInferred, isFalse);
    });

    test('VERSION 缺、JSON 有、推定版本在範圍內 → DomainReady 帶推定版本', () async {
      final container = _buildContainer(
        _FakeProbe(jsonExists: true, jsonVersion: '2.40.3'),
      );

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      final state = container.read(domainViewStateProvider);
      expect(state, isA<DomainReady>());
      expect((state as DomainReady).inferredVersion, '2.40.3');
      expect(container.read(inferredVersionProvider), '2.40.3');
    });

    test(
      'VERSION 缺、JSON 有、推定版本超出範圍 → DomainSchemaIncompatible 帶推定旗標',
      () async {
        final container = _buildContainer(
          _FakeProbe(jsonExists: true, jsonVersion: '2.90.0'),
        );

        await container
            .read(gateDetectionNotifierProvider.notifier)
            .detect('/fake');

        final state = container.read(domainViewStateProvider);
        expect(state, isA<DomainSchemaIncompatible>());
        final incompatible = state as DomainSchemaIncompatible;
        expect(incompatible.projectVersion, '2.90.0');
        expect(incompatible.isVersionInferred, isTrue);
        expect(container.read(inferredVersionProvider), isNull);
      },
    );

    test('JSON 有但版本無法解析（回傳 null）→ 安全預設拒絕（不相容）', () async {
      final container = _buildContainer(
        _FakeProbe(version: '2.10.0', jsonExists: true),
      );

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      expect(
        container.read(domainViewStateProvider),
        isA<DomainSchemaIncompatible>(),
      );
    });

    test(
      'JSON 版本無法判讀（null）且 VERSION 缺 → projectVersion 為 null（0.3.0-W3-542）',
      () async {
        final container = _buildContainer(_FakeProbe(jsonExists: true));

        await container
            .read(gateDetectionNotifierProvider.notifier)
            .detect('/fake');

        final state = container.read(domainViewStateProvider);
        expect(state, isA<DomainSchemaIncompatible>());
        expect((state as DomainSchemaIncompatible).projectVersion, isNull);
      },
    );

    test('JSON 版本無法判讀（null）且 VERSION 存在 → 不以 VERSION 代位，projectVersion 仍為 null'
        '（0.3.0-W3-542）', () async {
      final container = _buildContainer(
        _FakeProbe(version: '2.10.0', jsonExists: true),
      );

      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/fake');

      final state = container.read(domainViewStateProvider);
      expect(state, isA<DomainSchemaIncompatible>());
      expect((state as DomainSchemaIncompatible).projectVersion, isNull);
    });
  });

  group('0.5.0-W1-206.3 gate 阻擋結果遞增載入世代', () {
    test('載入進行中切專案並被 gate 阻擋，舊載入完成後不覆蓋阻擋態', () async {
      final gate = Completer<ScanRoundResult?>();
      final logs = <(String, int)>[];
      final container = ProviderContainer(
        overrides: [
          frameworkSignalProbeProvider.overrideWithValue(_FakeProbe()),
          builtinSchemaVersionProvider.overrideWith((ref) async => '2.40.3'),
          scanRoundProvider.overrideWith(() => _GatedScanRound(gate)),
          domainViewLogSinkProvider.overrideWithValue(
            (message, {level = 500}) => logs.add((message, level)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ws = container.read(currentWorkspaceStateProvider.notifier);
      ws.state = const WorkspaceReady('/ws/a');
      container.read(scanRoundProvider);

      final loading = container.read(domainViewLoaderProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      ws.state = const WorkspaceReady('/ws/b');
      await container
          .read(gateDetectionNotifierProvider.notifier)
          .detect('/ws/b');
      expect(
        container.read(domainViewStateProvider),
        isA<DomainNotFramework>(),
      );

      gate.complete(null);
      await loading;

      expect(
        container.read(domainViewStateProvider),
        isA<DomainNotFramework>(),
      );
      expect(logs.where((l) => l.$2 == 900), isEmpty);
    });
  });
}
