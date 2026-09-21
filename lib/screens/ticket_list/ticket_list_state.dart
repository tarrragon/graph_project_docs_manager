/// Ticket 清單（SPEC-001 §4；SPEC-003 §3.4；SPEC-004 §3.6）的畫面狀態模型。
///
/// 本票決策：只交狀態渲染與退出路徑，不接真實資料——票列資料來自
/// [TicketListFixtures]（`ticket_list_fixtures.dart`），非解析
/// `test/fixtures/corpus/` 或使用者工作資料夾；「含損壞」為疊加於
/// [TicketsReady] 之上的計算結果（[TicketsReady.corruptedCount]），不是
/// 獨立的第七種狀態（SPEC-001 §4 表下段落）。
library;

/// 列表／主題雙模式（SPEC-004 §4.10 `SegmentedControl`）。
enum TicketListMode {
  /// 正常 · 列表：密集表格 + 虛擬捲動。
  list,

  /// 正常 · 主題：主題節 + 未歸屬節。
  topic,
}

/// 「專案未就緒」的三個原因（SPEC-001 §4 共用定義，`0.1.0-W3-335.37`
/// R9）。與 `trace_state.dart` 的同名列舉語意相同，各畫面獨立宣告以維持
/// 每個畫面只依賴自己的狀態檔（既有專案慣例）。
enum ProjectUnreadyReason {
  /// Domain 視圖尚未選擇專案。
  notSelected,

  /// Domain 視圖圖譜載入中。
  loading,

  /// Domain 視圖處於三個阻擋狀態之一。
  incompatible,
}

/// 可排序欄（SPEC-003 §3.4〈篩選與排序的 key 值域〉：id／title／status／
/// priority 四欄，損壞標記欄與 blockedBy 欄皆不可排序）。
enum TicketSortKey { id, title, status, priority }

/// 排序方向（SPEC-003 §3.4 S1–S2：`none → asc → desc → none` 三態循環）。
enum TicketSortOrder { none, asc, desc }

/// 單張票的固定假資料（SPEC-001 §4 票列欄位：ID／標題／狀態／優先／
/// blockedBy／損壞標記）。
class TicketFixtureItem {
  const TicketFixtureItem({
    required this.id,
    required this.title,
    this.status,
    this.priority,
    this.blockedBy = const [],
    this.topic,
    this.corrupted = false,
  });

  /// 穩定識別碼，供 `card-tickets-<ticketId>` 錨點使用。
  final String id;

  /// 標題；解析失敗票以檔名頂替（[corrupted] 為 `true` 時）。
  final String title;

  /// 狀態值；解析失敗票為 `null`（欄位顯示「—」）。
  final String? status;

  /// 優先值；解析失敗票為 `null`（欄位顯示「—」）。
  final String? priority;

  /// 被本票阻擋的 ticket ID 清單（`blockedBy`），無則顯示「—」（本票
  /// 因 SPEC-004 §3.6 元件契約尚無對應欄位 slot，資料保留但不渲染，
  /// 詳見畫面票 NeedsContext）。
  final List<String> blockedBy;

  /// 主題節歸屬；`null` 代表未歸屬節。
  final String? topic;

  /// 是否為解析失敗票（SPEC-001 §4「含損壞」疊加態的計入依據）。
  final bool corrupted;
}

/// Ticket 清單的畫面狀態（SPEC-001 §4）。
sealed class TicketListState {
  const TicketListState();
}

/// 專案未就緒：SPEC-001 §4 共用定義。
class TicketsProjectUnready extends TicketListState {
  const TicketsProjectUnready(this.reason);

  final ProjectUnreadyReason reason;
}

/// 未載入：`LoadPrompt`（SPEC-004 §4.25）。
class TicketsUnloaded extends TicketListState {
  const TicketsUnloaded({required this.count});

  /// 待載入 ticket 檔案數（列舉不解析，含之後解析失敗者）。
  final int count;
}

/// 載入中：`LoadingState.progressBar`（已解析筆數 + 取消）。
class TicketsLoading extends TicketListState {
  const TicketsLoading({
    this.total = 0,
    this.processedCount = 0,
    this.isCancelling = false,
  });

  /// 分母（與 [TicketsUnloaded.count] 相同）。
  final int total;

  /// 已解析筆數。
  final int processedCount;

  /// 取消契約 C2：按下取消後 `Motion.feedback` 內轉為 `true`。
  final bool isCancelling;
}

/// 無 ticket：載入完成且 ticket 檔案數為 0。
class TicketsEmpty extends TicketListState {
  const TicketsEmpty();
}

/// 正常 · 列表／正常 · 主題共用的載入完成態（含損壞為其上的計算疊加）。
class TicketsReady extends TicketListState {
  const TicketsReady({
    required this.tickets,
    this.mode = TicketListMode.list,
    this.searchQuery = '',
    this.statusFilter,
    this.priorityFilter,
    this.sortKey,
    this.sortOrder = TicketSortOrder.none,
    this.expandedTopics = const {},
    this.targetTicketId,
    this.targetFiltersAutoCleared = false,
  });

  /// 全部已載入票（未經搜尋／篩選／排序）。
  final List<TicketFixtureItem> tickets;

  /// 目前檢視模式。
  final TicketListMode mode;

  /// 搜尋詞（僅列表模式套用，SPEC-003 §3.4 S6／R1）。
  final String searchQuery;

  /// 狀態篩選值；`null` 代表「全部」。
  final String? statusFilter;

  /// 優先篩選值；`null` 代表「全部」。
  final String? priorityFilter;

  /// 目前排序欄；`null` 代表未排序（S1：至多一欄非 `none`）。
  final TicketSortKey? sortKey;

  /// 目前排序方向；[sortKey] 為 `null` 時恆為 [TicketSortOrder.none]。
  final TicketSortOrder sortOrder;

  /// 已展開的主題節名稱集合；未歸屬節以固定字面 `'unassigned'` 表示
  /// （避免與同名主題撞名，`0.1.0-W3-335.38` S-08 同慣例）。
  final Set<String> expandedTopics;

  /// 帶目標跳入（SPEC-003 §3.4〈帶目標跳入〉）的目標 ticket ID；`null`
  /// 代表非帶目標進入。定位完成後仍保留（供 [targetTicketId] 對應列持續
  /// 高亮判定），不因清除搜尋／篩選而重置。
  final String? targetTicketId;

  /// 是否已因帶目標跳入自動清除過一次搜尋與篩選（SPEC-003 §3.4〈帶目標
  /// 跳入〉：清除為進入時的一次性動作，非持續性不變式——按「復原」還原
  /// 舊篩選後即使目標因此再次被隱藏，亦不得重新觸發自動清除，否則會與
  /// 「不撤銷定位」的復原語意互相抵銷）。
  final bool targetFiltersAutoCleared;

  /// 解析失敗票數（SPEC-001 §4「含損壞」疊加態的計入依據）。
  int get corruptedCount => tickets.where((t) => t.corrupted).length;

  TicketsReady copyWith({
    List<TicketFixtureItem>? tickets,
    TicketListMode? mode,
    String? searchQuery,
    String? Function()? statusFilter,
    String? Function()? priorityFilter,
    TicketSortKey? Function()? sortKey,
    TicketSortOrder? sortOrder,
    Set<String>? expandedTopics,
    String? Function()? targetTicketId,
    bool? targetFiltersAutoCleared,
  }) {
    return TicketsReady(
      tickets: tickets ?? this.tickets,
      mode: mode ?? this.mode,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      priorityFilter: priorityFilter != null
          ? priorityFilter()
          : this.priorityFilter,
      sortKey: sortKey != null ? sortKey() : this.sortKey,
      sortOrder: sortOrder ?? this.sortOrder,
      expandedTopics: expandedTopics ?? this.expandedTopics,
      targetTicketId: targetTicketId != null
          ? targetTicketId()
          : this.targetTicketId,
      targetFiltersAutoCleared:
          targetFiltersAutoCleared ?? this.targetFiltersAutoCleared,
    );
  }
}
