/// 節點詳情（SPEC-001 §6）的畫面狀態模型。
///
/// 本檔只定義狀態模型；節點內容預設由共用掃描輪次的建圖結果投影
/// （`0.5.0-W1-114.25`，見 `node_detail_providers.dart`），
/// [NodeDetailFixtures]（`node_detail_fixtures.dart`）只供測試注入。
/// 「專案未就緒」為 SPEC-001 五個非 Domain 畫面共用定義
/// （`0.1.0-W3-335.37` R9），本票以獨立狀態列舉呈現，不 watch
/// `projectUnreadyReasonProvider`（同 `trace_state.dart`／`domain_view_state.dart`
/// 的簡單 `StateProvider` 慣例——`gap_report_provider.dart` 改用 Notifier
/// watch 該 provider 是因其自身有「首次可見自動掃描」的副作用需求，兩者
/// 皆為既有票已核可的合法設計選擇，本票選前者以維持與 trace／domain_view
/// 一致）。
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:graph_project_docs_manager/components/field_block.dart'
    show FieldWriteState;
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';

import '../../app/graph_status.dart';

/// 節點詳情的五個畫面狀態（SPEC-001 §6）。
sealed class NodeDetailState {
  const NodeDetailState();
}

/// 專案未就緒：`EmptyState.page`（SPEC-001 共用定義；優先於「未選節點」
/// 判定，SPEC-003 §3.6）。
class NodeDetailProjectUnready extends NodeDetailState {
  const NodeDetailProjectUnready(this.reason);

  /// Three-way reason (shared enum).
  final ProjectUnreadyReason reason;
}

/// 未選節點：經導覽列直接進入且無選定節點（SPEC-001 §6 v1.3 新增）。
class NodeDetailUnset extends NodeDetailState {
  const NodeDetailUnset();
}

/// 正常態：節點存在即渲染正常態（部分損壞在 0.x 不可達，恢復條件見
/// 1.1.0-W3-656）。
class NodeDetailReady extends NodeDetailState {
  const NodeDetailReady({required this.nodeId});

  /// 目前顯示的節點 id（[NodeDetailFixtures] 鍵值）。
  final String nodeId;
}

/// 圖不可用：最後完成輪次建圖不可用（SPEC-001 §6 判定順序 2）。
class NodeDetailGraphUnavailable extends NodeDetailState {
  const NodeDetailGraphUnavailable();
}

/// 節點不在目前的圖上：選定 id 不在最後完成輪次的圖上（SPEC-001 §6 判定順序 4）。
class NodeDetailNodeAbsent extends NodeDetailState {
  const NodeDetailNodeAbsent({required this.nodeId});

  /// 選定但不在圖上的節點 id。
  final String nodeId;
}

/// 原始檔已消失：訊息 + 最後已知路徑 + 重新整理／返回。
class NodeDetailMissing extends NodeDetailState {
  const NodeDetailMissing({required this.nodeId, required this.lastKnownPath});

  /// 消失前顯示的節點 id（重新整理成功後據此決定顯示哪個節點）。
  final String nodeId;

  /// 最後已知路徑（`MissingSourceState` 訊息 slot）。
  final String lastKnownPath;
}

/// 編輯模式的三個子狀態（SPEC-001 §6〈編輯模式〉）：編輯中、外部已改預警、
/// 外部已改阻擋。
enum NodeDetailEditPhase { editing, warning, blocked }

/// 編輯模式的畫面狀態；`null`（無此物件）代表不在編輯模式。
///
/// 需求：[SPEC-003 §3.6 / §4 #58–#60] 持有 Edit domain 的 [session]（M 在其
/// 內）、各欄目前值（磁碟上的值，不做樂觀更新）與各欄寫入呈現資料。
@immutable
class NodeDetailEditState {
  const NodeDetailEditState({
    required this.nodeId,
    required this.nodeType,
    required this.session,
    required this.path,
    required this.fieldKeys,
    required this.values,
    this.phase = NodeDetailEditPhase.editing,
    this.writeStates = const {},
    this.requiredEmpty = const {},
    this.dirty = const {},
    this.writingField,
    this.generation = 0,
  });

  final String nodeId;
  final String nodeType;
  final EditSession session;

  /// 正在編輯的檔案（供重讀比較 M 與磁碟）。
  final WorkspaceRelativePath path;

  /// 可編輯欄位鍵，依 SPEC-009 FR-09 表列序。
  final List<String> fieldKeys;

  /// 欄位目前值（磁碟上的值；空值為空字串）。
  final Map<String, String> values;

  final NodeDetailEditPhase phase;

  /// 各欄最近一次寫入的呈現資料。
  final Map<String, FieldWriteState> writeStates;

  /// 必填欄位送出空白、未發出寫入者。
  final Set<String> requiredEmpty;

  /// 有未送出草稿的欄位。
  final Set<String> dirty;

  /// 寫入進行中的欄位；非 null 時全部欄位鎖定。
  final String? writingField;

  /// 草稿捨棄計數：變動時各欄輸入元件重建，草稿清空。
  final int generation;

  bool get writeInProgress => writingField != null;

  NodeDetailEditState copyWith({
    NodeDetailEditPhase? phase,
    Map<String, String>? values,
    Map<String, FieldWriteState>? writeStates,
    Set<String>? requiredEmpty,
    Set<String>? dirty,
    String? writingField,
    bool clearWriting = false,
    int? generation,
  }) => NodeDetailEditState(
    nodeId: nodeId,
    nodeType: nodeType,
    session: session,
    path: path,
    fieldKeys: fieldKeys,
    values: values ?? this.values,
    phase: phase ?? this.phase,
    writeStates: writeStates ?? this.writeStates,
    requiredEmpty: requiredEmpty ?? this.requiredEmpty,
    dirty: dirty ?? this.dirty,
    writingField: clearWriting ? null : (writingField ?? this.writingField),
    generation: generation ?? this.generation,
  );
}

/// 開始編輯的結果（供畫面層決定後續）。
enum NodeDetailEditBeginResult { started, missing, readFailed, unavailable }
