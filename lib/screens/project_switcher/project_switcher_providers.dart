/// 專案切換浮層狀態（SPEC-001 §7）。
///
/// 最近專案清單以 fixture provider 驅動——多最近專案的 key 版本化定案前
/// 不接 shared_preferences；本檔只負責浮層開合旗標與 fixture 資料的
/// provider 供給，實際資料夾探測與持久化留給 workspace domain 後續票承接。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 最近專案項的 fixture 資料（SPEC-004 §4.9 slot 契約的資料來源）。
class RecentProjectFixture {
  const RecentProjectFixture({
    required this.name,
    required this.nodeCount,
    required this.ticketCount,
    this.healthIssueCount = 0,
    this.enabled = true,
  });

  /// 專案名稱（`RecentProjectItem.name`）。
  final String name;

  /// 節點數（`projectSummaryLabel` 第一參數）。
  final int nodeCount;

  /// 票數（`projectSummaryLabel` 第二參數）。
  final int ticketCount;

  /// 健康問題數；0 時 `RecentProjectItem.health` 不傳（SPEC-004 §4.9）。
  final int healthIssueCount;

  /// 可用性；`false` 時常駐顯示不可用原因（探測逾時，SPEC-003 §3.7）。
  final bool enabled;
}

/// 浮層展開態；`true` 對應 SPEC-001 §7「展開」或「無最近專案」（依
/// [recentProjectsProvider] 是否為空清單區分），`false` 對應「收合」。
final switcherOpenProvider = StateProvider<bool>((ref) => false);

/// 目前選取的最近專案索引；`null` 表示尚無目前專案。與「無最近專案」狀態
/// 的判定無關——該判定依 [recentProjectsProvider] 是否為空清單。
final currentProjectIndexProvider = StateProvider<int?>((ref) => 0);

/// 最近專案清單，fixture 驅動（多最近專案的 key 版本化定案前不接
/// shared_preferences）。清單為空即對應 SPEC-001 §7「無最近專案」。
final recentProjectsProvider = Provider<List<RecentProjectFixture>>((ref) {
  return const [
    RecentProjectFixture(
      name: 'graph_project_docs_manager',
      nodeCount: 237,
      ticketCount: 2419,
    ),
    RecentProjectFixture(
      name: 'unipos',
      nodeCount: 58,
      ticketCount: 12,
      healthIssueCount: 3,
    ),
    RecentProjectFixture(
      name: 'blog',
      nodeCount: 0,
      ticketCount: 0,
      enabled: false,
    ),
  ];
});

/// 側欄入口顯示的目前專案名；取 [currentProjectIndexProvider] 指向的項目，
/// 索引越界或清單為空時回傳 `null`（`ProjectSwitcherEntry` 顯示元件預設
/// `projectSwitcherEntryLabel`）。
final currentProjectNameProvider = Provider<String?>((ref) {
  final projects = ref.watch(recentProjectsProvider);
  final index = ref.watch(currentProjectIndexProvider);
  if (index == null || index < 0 || index >= projects.length) return null;
  return projects[index].name;
});
