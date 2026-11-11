// 需求：1.0.0-W3-661；SPEC-001 §1 後「專案未就緒」共用定義。
// wiring test：不 override projectUnreadyReasonProvider，原因由
// domainViewStateProvider（真實來源）推導；含正向對照（每種原因進入未就緒）
// 與反向對照（Empty 為 null）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_screen.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../helpers/helpers.dart';

const _expected = <DomainViewState, ProjectUnreadyReason?>{
  DomainUnset(): ProjectUnreadyReason.notSelected,
  DomainLoading(): ProjectUnreadyReason.loading,
  DomainNotFramework(): ProjectUnreadyReason.incompatible,
  DomainSchemaUnconsumable(version: '1.0.0'): ProjectUnreadyReason.incompatible,
  DomainSchemaIncompatible(appVersion: '1.0.0', projectVersion: '9.0.0'):
      ProjectUnreadyReason.incompatible,
  DomainLoadFailed(): ProjectUnreadyReason.loadFailed,
  DomainEmpty(): null,
};

void main() {
  group('原因取自 Domain 視圖狀態（真實 provider 圖）', () {
    _expected.forEach((state, reason) {
      test('${state.runtimeType} -> $reason', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(domainViewStateProvider.notifier).state = state;
        expect(container.read(projectUnreadyReasonProvider), reason);
      });
    });

    test('狀態變更時原因跟著更新（E2）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reasons = <ProjectUnreadyReason?>[];
      container.listen(
        projectUnreadyReasonProvider,
        (_, next) => reasons.add(next),
      );
      final holder = container.read(domainViewStateProvider.notifier);
      holder.state = const DomainUnset();
      await Future<void>.delayed(Duration.zero);
      holder.state = const DomainEmpty();
      await Future<void>.delayed(Duration.zero);
      expect(reasons, [ProjectUnreadyReason.notSelected, null]);
    });
  });

  group('讀取者進入未就緒（不 override 原因）', () {
    for (final entry in _expected.entries.where((e) => e.value != null)) {
      testWidgets('gap_report：${entry.key.runtimeType}', (tester) async {
        await pumpHarness(
          tester,
          child: const GapReportScreen(),
          overrides: [
            domainViewStateProvider.overrideWithInitial((_) => entry.key),
          ],
        );
        expect(
          AnchorFinder.state(Screen.gaps, 'project-unready'),
          findsOneWidget,
        );
      });
    }
  });
}
