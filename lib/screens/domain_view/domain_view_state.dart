/// Domain 視圖（SPEC-001 §1）的畫面狀態模型。
///
/// 十一個 SPEC-001 §1 狀態列中，正常 · 矩陣／已選格（疊加）／正常 · 泳道／
/// 泳道 · 尚未選定 UC／泳道 · flow 未結構化五列共用同一份底層資料
/// （[DomainReady]，SPEC-003 §3.1「兩模式共用同一選中 domain」）；實際渲染
/// 哪一列由 [DomainReady.mode]、[DomainReady.selectedCell] 與 App 層共用值
/// `selectedUcProvider`（`app/selected_uc.dart`）三者組合決定，由畫面層
/// （`domain_view_screen.dart`）計算，本檔只定資料形狀。
library;

/// 矩陣／泳道兩模式（SPEC-004 §4.10 `SegmentedControl`）。
enum DomainMode {
  /// 正常 · 矩陣。
  matrix,

  /// 正常 · 泳道／泳道 · 尚未選定 UC／泳道 · flow 未結構化三列之一。
  swimlane,
}

/// domain × UC 的關係種類（SPEC-004 §4.15 `Relation`，本檔獨立宣告避免
/// 畫面層依賴元件內部 enum；兩者值集合一致，轉換見
/// `domain_view_screen.dart`）。
enum DomainRelation {
  /// 直接貫穿：至少一個 FlowStep 的 `traverses` 包含該 domain。
  direct,

  /// 間接依賴：判定式待決（`0.1.0-W3-376`），0.1 以 fixture 字面值標記。
  indirect,

  /// 無關。
  none,
}

/// 一個 domain × UC 交叉格的完整資料（矩陣格 + 已選格詳情卡兩用）。
class DomainCell {
  const DomainCell({
    required this.domainId,
    required this.ucId,
    required this.relation,
    this.explanation,
    this.steps = const [],
    this.events = const [],
  });

  /// 所在列 domain id。
  final String domainId;

  /// 所在欄 UC id。
  final String ucId;

  /// 關係種類（矩陣符號 + 詳情卡「關係種類」文字的依據）。
  final DomainRelation relation;

  /// 詳情卡「說明」slot，可缺（SPEC-003 §3.1〈格詳情卡的內容契約〉）。
  final String? explanation;

  /// 詳情卡「編號步驟」slot，依 flow 順序；可為空（不渲染該 slot）。
  final List<String> steps;

  /// 詳情卡「事件標籤」slot：`(事件名, 是否為 emits)`；可為空。
  final List<(String eventName, bool isEmit)> events;
}

/// 單一 domain 在矩陣中的一列：domain 名 + 該列各 UC 欄的格 + 小計。
class DomainRow {
  const DomainRow({
    required this.domainId,
    required this.domainName,
    required this.cells,
    required this.subtotal,
  });

  final String domainId;
  final String domainName;

  /// 長度須等於 [DomainViewFixtures.ucColumns] 長度，依欄序對齊。
  final List<DomainCell> cells;

  /// 被直接貫穿的 UC 數（SPEC-001 §1 註記：`relation == direct` 的格數）。
  final int subtotal;
}

/// 一條泳道內的一個節點：步驟標籤 + 所在步驟欄（0 起算）+ 該步驟直接
/// 觸及的 domain 清單（[stepTraverses]，供「選 domain」跨列 active／
/// inactive 判定使用，SPEC-003 §3.1「選 domain」列）。
class DomainLaneNode {
  const DomainLaneNode({
    required this.stepLabel,
    required this.column,
    required this.stepTraverses,
  });

  final String stepLabel;
  final int column;

  /// 本節點所屬步驟的完整 `traverses` 清單（可能含多個 domain）。
  final List<String> stepTraverses;
}

/// 一條泳道（一個 domain）：泳道名 + 該 domain 在選定 UC 的節點清單。
class DomainLane {
  const DomainLane({required this.domainId, required this.nodes});

  final String domainId;
  final List<DomainLaneNode> nodes;
}

/// UC 欄首資訊（矩陣欄首 `TableColumnHeader.twoLine`、泳道面板標題）。
class DomainUc {
  const DomainUc({
    required this.id,
    required this.title,
    required this.hasFlowStep,
  });

  final String id;
  final String title;

  /// `false` 時該 UC 對應「flow 未結構化」（SPEC-001 §1）。
  final bool hasFlowStep;
}

/// Domain 視圖的十一個畫面狀態（SPEC-001 §1）。
sealed class DomainViewState {
  const DomainViewState();
}

/// 未選專案：`EmptyState.page`。
class DomainUnset extends DomainViewState {
  const DomainUnset();
}

/// 載入中：`LoadingState.skeleton`。
class DomainLoading extends DomainViewState {
  const DomainLoading({this.isCancelling = false});

  final bool isCancelling;
}

/// 正常 · 矩陣／已選格／正常 · 泳道／泳道 · 尚未選定 UC／泳道 ·
/// flow 未結構化五列的共用底層資料（節點已解析成功且有節點）。
class DomainReady extends DomainViewState {
  const DomainReady({
    required this.mode,
    this.selectedDomainId,
    this.selectedCell,
    this.isDegraded = false,
    this.inferredVersion,
  });

  /// 目前檢視模式（矩陣／泳道，SPEC-004 §4.10）。
  final DomainMode mode;

  /// 選中列（矩陣列首、泳道列高亮共用，SPEC-003 §3.1「選 domain」）。
  final String? selectedDomainId;

  /// 已選格（僅矩陣模式使用；`null` 代表「未選格」，右欄呈常駐提示）。
  final (String domainId, String ucId)? selectedCell;

  /// 降級型別表旗標（`0.1.0-W1-035`，疊加旗標非新狀態）。
  final bool isDegraded;

  /// 推定版本旗標（`0.2.0-W1-038` 方案 A）：`.claude/VERSION` 缺失時，
  /// 由 gate 偵測 notifier 以 `tracking_schema.json` 的
  /// `schema_generated_at_framework_version` 推定並寫入此欄；`null`
  /// 代表版本為 VERSION 真實值（非推定）。
  final String? inferredVersion;

  DomainReady copyWith({
    DomainMode? mode,
    (String, String)? Function()? selectedCell,
    String? Function()? selectedDomainId,
    bool? isDegraded,
    String? Function()? inferredVersion,
  }) {
    return DomainReady(
      mode: mode ?? this.mode,
      selectedDomainId: selectedDomainId != null
          ? selectedDomainId()
          : this.selectedDomainId,
      selectedCell: selectedCell != null ? selectedCell() : this.selectedCell,
      isDegraded: isDegraded ?? this.isDegraded,
      inferredVersion: inferredVersion != null
          ? inferredVersion()
          : this.inferredVersion,
    );
  }
}

/// 空圖：節點數為 0。
class DomainEmpty extends DomainViewState {
  const DomainEmpty({
    this.docsDirExists = true,
    this.isDegraded = false,
    this.inferredVersion,
  });

  /// `docs/` 目錄是否存在（僅在存在時提供「開啟 docs 目錄」動作）。
  final bool docsDirExists;

  final bool isDegraded;

  /// 推定版本旗標，語意同 [DomainReady.inferredVersion]（`0.2.0-W1-038`
  /// 方案 A）。
  final String? inferredVersion;
}

/// 不是框架專案：`.claude/VERSION` 與 `tracking_schema.json` 皆缺。
class DomainNotFramework extends DomainViewState {
  const DomainNotFramework();
}

/// 無可消費的型別表：`.claude/VERSION` 存在但 `tracking_schema.json` 不存在。
class DomainSchemaUnconsumable extends DomainViewState {
  const DomainSchemaUnconsumable({required this.version});

  /// 專案 `.claude/VERSION` 值（訊息 slot 與獨立版本值 slot 顯示同一值，
  /// SPEC-001 §1 註記「有意冗餘」）。
  final String version;
}

/// schema 不相容：`tracking_schema.json` 存在但框架版本超出 App 已知範圍。
class DomainSchemaIncompatible extends DomainViewState {
  const DomainSchemaIncompatible({
    required this.appVersion,
    required this.projectVersion,
    this.isDetailExpanded = false,
    this.isVersionInferred = false,
  });

  final String appVersion;

  /// 專案框架版本（真實 `.claude/VERSION` 值，或 [isVersionInferred] 為
  /// `true` 時的推定值，`0.2.0-W1-038` 方案 A）。`null` 代表型別表版本
  /// 無法判讀（`classifySchemaVersion` 回傳 `Unreadable`）：不以
  /// `.claude/VERSION` 值代位，避免出現「專案版本低於內建卻判不相容」的
  /// 自相矛盾說明（`0.3.0-W3-542`，WRAP 方案 D；SPEC-001 v1.23 §1）。
  final String? projectVersion;

  /// 「檢視詳情」面板展開態，狀態存於呼叫端（`BlockedState.withDetail`）。
  final bool isDetailExpanded;

  /// [projectVersion] 是否為推定值（`.claude/VERSION` 缺失時以
  /// `tracking_schema.json` 版本推定，`0.2.0-W1-038` 方案 A）。
  final bool isVersionInferred;
}
