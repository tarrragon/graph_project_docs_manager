/// gate 偵測：讀取目標專案的三個 filesystem 訊號，依 SPEC-001 v1.18
/// 〈Gate 三問對照〉判定順序路由至 [DomainViewState] 子類別
/// （`0.2.0-W1-033`）。
///
/// 判定順序：
/// 1. `.claude/VERSION` 與 `tracking_schema.json` 皆缺 → [DomainNotFramework]
/// 2. JSON 缺（此處只看 JSON 存在性，不看 VERSION 值）→
///    [DomainSchemaUnconsumable]
/// 3. JSON 存在 → 依版本範圍判定分 [DomainReady]／[DomainSchemaIncompatible]。
///    範圍判定恆以 JSON 的 `schema_generated_at_framework_version` 與 App
///    內建版本比較（`0.2.0-W1-024` 定案：`!isHigherThanBuiltinSchemaVersion
///    (jsonVersion, builtinVersion)`），`.claude/VERSION` 是否存在只決定
///    「顯示版本是否為推定值」（`0.2.0-W1-038` 方案 A），不參與範圍比較——
///    兩個「兩訊號皆有」的凍結 manifest 案例（`VERSION` 遠高於 builtin）
///    因 JSON 版本等於 builtin 而正常載入，即為此設計的直接驗證。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/framework_signal_probe.dart';
import 'domain_view_providers.dart';
import 'domain_view_schema_version.dart';
import 'domain_view_state.dart';

/// [FrameworkSignalProbePort] 的 Riverpod 掛點；測試以 `overrideWithValue`
/// 注入 mock，不接觸真實檔案系統。
final frameworkSignalProbeProvider = Provider<FrameworkSignalProbePort>(
  (ref) => const DefaultFrameworkSignalProbe(),
);

/// 推定版本旗標（`0.2.0-W1-038` 方案 A）：`.claude/VERSION` 缺失、JSON
/// 存在時，由 [GateDetectionNotifier] 寫入 JSON 版本值；切換專案時應由
/// 呼叫端重置為 `null`（比照 `app/degraded_schema.dart` 的
/// `degradedSchemaProvider` 先例）。
final inferredVersionProvider = StateProvider<String?>((ref) => null);

/// gate 偵測邏輯的唯一入口。本 notifier 不持有自身狀態（`build()` 不做
/// 事）——[detect] 是每次呼叫皆完整重算的動作，副作用寫入
/// [domainViewStateProvider] 與 [inferredVersionProvider]。呼叫時機由
/// 呼叫端決定（WorkspaceReady 後的畫面層接線非本票範圍）。
class GateDetectionNotifier extends Notifier<void> {
  @override
  void build() {}

  /// 對 [workspacePath] 執行 gate 偵測。
  Future<void> detect(String workspacePath) async {
    final probe = ref.read(frameworkSignalProbeProvider);
    final version = await probe.readVersion(workspacePath);
    final jsonExists = await probe.schemaJsonExists(workspacePath);

    if (version == null && !jsonExists) {
      _apply(const DomainNotFramework(), inferredVersion: null);
      return;
    }
    if (!jsonExists) {
      _apply(
        DomainSchemaUnconsumable(version: version!),
        inferredVersion: null,
      );
      return;
    }

    final builtinVersion = await ref.read(
      builtinSchemaVersionProvider.future,
    );
    final jsonVersion = await probe.readSchemaJsonVersion(workspacePath);
    final isInferred = version == null;
    final displayVersion = version ?? jsonVersion;

    final inRange =
        jsonVersion != null &&
        !isHigherThanBuiltinSchemaVersion(jsonVersion, builtinVersion);

    if (inRange) {
      final inferred = isInferred ? jsonVersion : null;
      _apply(
        DomainReady(mode: DomainMode.matrix, inferredVersion: inferred),
        inferredVersion: inferred,
      );
      return;
    }

    _apply(
      DomainSchemaIncompatible(
        appVersion: builtinVersion,
        projectVersion: displayVersion ?? '',
        isVersionInferred: isInferred,
      ),
      inferredVersion: null,
    );
  }

  void _apply(DomainViewState state, {required String? inferredVersion}) {
    ref.read(domainViewStateProvider.notifier).state = state;
    ref.read(inferredVersionProvider.notifier).state = inferredVersion;
  }
}

/// [GateDetectionNotifier] 的 Riverpod 掛點。
final gateDetectionNotifierProvider =
    NotifierProvider<GateDetectionNotifier, void>(GateDetectionNotifier.new);
