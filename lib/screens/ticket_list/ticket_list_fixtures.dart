/// Ticket 清單固定假資料（設計約束同 `domain_view_fixtures.dart`：以假
/// 資料驅動列表／主題兩模式，非真實 repo 解析，`0.1.0-W1-023`／CLAUDE.md
/// §6「Domain 視圖的列無來源」同源決策——本票延伸至 Ticket 清單）。
///
/// 損壞樣本取自 `0.1.0-W1-023` 版本切片語料
/// （`test/fixtures/corpus/book_overview_app/docs/work-logs/README.md`
/// 〈缺 frontmatter 樣本清單〉）的真實檔名，非虛構——這些檔案在該語料
/// 目錄下確實存在且 `parse_frontmatter_text` 回傳 `None`（缺 frontmatter
/// carrier），與 SPEC-001 §4 註記的「解析失敗票，ID 取檔名，其餘欄顯示
/// 『—』」處理一致。
library;

import 'ticket_list_state.dart';

/// Ticket 清單的固定資料集合。
abstract final class TicketListFixtures {
  /// 正常票（狀態／優先／主題皆有值），依載入序排列（S3「未排序」的
  /// 定義：列序等於載入完成當下的列序）。
  static const List<TicketFixtureItem> _normal = [
    TicketFixtureItem(
      id: '0.1.0-W1-002', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '建立六項導覽的路由殼', // i18n-exempt: fixture 資料值
      status: 'completed', // i18n-exempt: fixture 資料值
      priority: 'P1', // i18n-exempt: fixture 資料值
      topic: 'shell', // i18n-exempt: fixture 主題名
    ),
    TicketFixtureItem(
      id: '0.1.0-W1-005', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '定義畫面狀態機共用約定', // i18n-exempt: fixture 資料值
      status: 'completed', // i18n-exempt: fixture 資料值
      priority: 'P1', // i18n-exempt: fixture 資料值
      topic: 'shell', // i18n-exempt: fixture 主題名
    ),
    TicketFixtureItem(
      id: '0.1.0-W1-023', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '抽取 Ticket 節點檔為測試 fixture（版本切片策略）', // i18n-exempt: fixture 資料值
      status: 'completed', // i18n-exempt: fixture 資料值
      priority: 'P2', // i18n-exempt: fixture 資料值
      topic: 'fixture', // i18n-exempt: fixture 主題名
    ),
    TicketFixtureItem(
      id: '0.1.0-W2-002', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '實作破洞報告畫面', // i18n-exempt: fixture 資料值
      status: 'in_progress', // i18n-exempt: fixture 資料值
      priority: 'P1', // i18n-exempt: fixture 資料值
      blockedBy: [
        '0.1.0-W1-002',
      ], // i18n-exempt: fixture 資料值（ticket ID 清單）
      topic: 'screens', // i18n-exempt: fixture 主題名
    ),
    TicketFixtureItem(
      id: '0.1.0-W2-004', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '實作 Domain 視圖畫面', // i18n-exempt: fixture 資料值
      status: 'completed', // i18n-exempt: fixture 資料值
      priority: 'P0', // i18n-exempt: fixture 資料值
      topic: 'screens', // i18n-exempt: fixture 主題名
    ),
    TicketFixtureItem(
      id: '0.1.0-W2-006', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '實作追溯視圖畫面', // i18n-exempt: fixture 資料值
      status: 'completed', // i18n-exempt: fixture 資料值
      priority: 'P2', // i18n-exempt: fixture 資料值
      topic: 'screens', // i18n-exempt: fixture 主題名
    ),
    TicketFixtureItem(
      id: '0.1.0-W3-076', // i18n-exempt: fixture ticket ID，非 App UI 文案
      title: '回填四軸追溯矩陣現況', // i18n-exempt: fixture 資料值
      status: 'pending', // i18n-exempt: fixture 資料值
      priority: 'P2', // i18n-exempt: fixture 資料值
    ),
  ];

  /// 解析失敗票：ID 取真實語料檔名、其餘欄顯示「—」（`status`／`priority`
  /// 皆為 `null`），依 `0.1.0-W1-023` README〈缺 frontmatter 樣本清單〉
  /// 節錄。
  static const List<TicketFixtureItem> _corrupted = [
    TicketFixtureItem(
      id: '0.25.0-W1-010', // i18n-exempt: 真實語料檔名（缺 frontmatter carrier）
      title: '0.25.0-W1-010.md', // i18n-exempt: 真實語料檔名
      corrupted: true,
    ),
    TicketFixtureItem(
      id: 'W2-003-KEY-FINDINGS', // i18n-exempt: 真實語料檔名（缺 frontmatter carrier）
      title: 'W2-003-KEY-FINDINGS.md', // i18n-exempt: 真實語料檔名
      corrupted: true,
    ),
    TicketFixtureItem(
      id: '0.31.0-W4-054', // i18n-exempt: 真實語料檔名（缺 frontmatter carrier）
      title: '0.31.0-W4-054.md', // i18n-exempt: 真實語料檔名
      corrupted: true,
    ),
  ];

  /// 全部已載入票（正常 + 解析失敗），依載入序排列。
  static const List<TicketFixtureItem> all = [..._normal, ..._corrupted];
}
