import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';

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

ProviderContainer _buildContainer(FrameworkSignalProbePort probe) {
  final container = ProviderContainer(
    overrides: [
      frameworkSignalProbeProvider.overrideWithValue(probe),
      builtinSchemaVersionProvider.overrideWith((ref) async => '2.40.3'),
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
        _FakeProbe(
          version: '2.60.3',
          jsonExists: true,
          jsonVersion: '2.40.3',
        ),
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
        _FakeProbe(
          version: '2.10.0',
          jsonExists: true,
          jsonVersion: '2.90.0',
        ),
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

    test('VERSION 缺、JSON 有、推定版本超出範圍 → DomainSchemaIncompatible 帶推定旗標', () async {
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
    });

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
        final container = _buildContainer(
          _FakeProbe(jsonExists: true),
        );

        await container
            .read(gateDetectionNotifierProvider.notifier)
            .detect('/fake');

        final state = container.read(domainViewStateProvider);
        expect(state, isA<DomainSchemaIncompatible>());
        expect((state as DomainSchemaIncompatible).projectVersion, isNull);
      },
    );

    test(
      'JSON 版本無法判讀（null）且 VERSION 存在 → 不以 VERSION 代位，projectVersion 仍為 null'
      '（0.3.0-W3-542）',
      () async {
        final container = _buildContainer(
          _FakeProbe(version: '2.10.0', jsonExists: true),
        );

        await container
            .read(gateDetectionNotifierProvider.notifier)
            .detect('/fake');

        final state = container.read(domainViewStateProvider);
        expect(state, isA<DomainSchemaIncompatible>());
        expect((state as DomainSchemaIncompatible).projectVersion, isNull);
      },
    );
  });
}
