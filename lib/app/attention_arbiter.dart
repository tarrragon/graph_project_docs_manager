/// 注意力仲裁點（`0.1.0-W3-207`；SPEC-003〈跨 domain 的注意力協調〉）。
///
/// 本物件是通道之外的獨立物件，為新增的可用性單點——持有者記錄與
/// [ScaffoldMessenger] 內部佇列、系統通知送達狀態、關卡狀態機三者皆不共享
/// 記憶體。它與通道同在 UI isolate、非獨立行程，故不新增跨行程的可用性
/// 單點；但存在「仲裁器狀態壞而通道還能動」的失效路徑，四項失效模式與
/// 防線（Phase 1 第 8 節）：
///
/// 1. 持有者記錄未釋放（載體漏回報）：之後所有低級別請求被跳過或拒絕，
///    畫面本身正常。防線：有自然存活期者由懶檢查逾期清除；`expired`／
///    `releasedNonHolder` warning 使漏回報可被日誌發現。
/// 2. 關卡類持有者記錄未釋放：同上且無法自癒，無上界。消費機制為「關卡
///    狀態機每一條退出路徑皆有 `release`」的靜態檢查，落在承接關卡載體
///    的票，本票不承擔。
/// 3. 訊號無人訂閱時發出：被延後者永不重新請求。防線：自發型工作於下一
///    次排程時刻自行再請求，訊號只縮短等待、不是唯一恢復路徑。
/// 4. 對等待型 fail-closed：使用者操作的回饋被拒。防線：只在持有者為更
///    高級別時拒絕，且拒絕附 `retryAfter`；空通道與同級別一律接受。
///
/// 級別列舉不在本檔宣告，import [AttentionLevel]（`attention_level.dart`）
/// 為唯一權威落點；本檔**不** `export` 該列舉檔——轉出會使呼叫端可經本檔
/// 取得級別，兩條 import 路徑指向同一型別即是「宣告位置」再度模糊化的
/// 入口，這同樣不會讓任何測試變紅。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../components/attention_level.dart';

/// 到達類別（SPEC-003 §2.14 到達類別欄）。
///
/// 推送型刻意不存在：0.1 無接收緩衝，該類別在型別層即不可表達（第三類
/// 接收緩衝的範疇歸屬與 trigger 見 Phase 1 Solution 第 7 節）。
enum AttentionArrival {
  /// 等待型：能回溯到一個正在等待我方回覆的外部發起者。
  waiting,

  /// 自發型：開始的決定點在我方程式碼內。
  spontaneous,
}

/// 來源 domain。僅列 `docs/system-layer.md` §3.2 判「是」的三者；新增來源
/// 須先在該表改判，不得在此擴充。
enum AttentionSource { workspace, schema, diagnostics }

/// 一次請求。全部欄位在標定點（SPEC-003 §2.14「標定點」欄）由請求方填妥，
/// 仲裁器只讀取、不推導。
final class AttentionRequest {
  const AttentionRequest({
    required this.id,
    required this.level,
    required this.arrival,
    required this.source,
    this.parentLevel,
    this.deadline,
  });

  /// 請求識別。與 `0.1.0-W3-176` 的 shown／closed 配對識別同源，使仲裁事件
  /// 與載體事件可跨層配對。
  final String id;
  final AttentionLevel level;
  final AttentionArrival arrival;
  final AttentionSource source;

  /// 子呼叫時填父請求的級別（SPEC-003 §2.14「傳播規則」欄非空的列）。
  final AttentionLevel? parentLevel;

  /// 等待型由發起者攜帶的剩餘預算；自發型為下一次排程時刻前的餘量。
  /// 缺席時仲裁器不代填，只在事件記「指派」。
  final Duration? deadline;
}

/// 接受後交給請求方與載體的持有憑證；載體以它回報 `presented`／`release`。
final class AttentionHandle {
  const AttentionHandle({
    required this.requestId,
    required this.level,
    required this.arrival,
    required this.source,
    required this.acceptedAt,
    this.deadline,
  });

  final String requestId;
  final AttentionLevel level;
  final AttentionArrival arrival;
  final AttentionSource source;
  final DateTime acceptedAt;

  /// 接受時由 [AttentionRequest.deadline] 帶入的原始預算；離場型事件據此
  /// 記錄該持有者實際有沒有帶預算，取代對所有持有者一律回報「未指派」。
  final Duration? deadline;
}

/// 仲裁決策。動作集取自方法論〈讓步與卸載順序〉卸載順序表，本專案只用到
/// 四種。
sealed class AttentionDecision {
  const AttentionDecision();
}

/// 接受：立即呈現。`preempted` 非空時載體必須先截斷該持有者再呈現。
final class AttentionAccepted extends AttentionDecision {
  const AttentionAccepted({
    required this.handle,
    required this.preempted,
    required this.sameLevelReplace,
  });

  final AttentionHandle handle;
  final AttentionHandle? preempted;

  /// 同級別取代（`0.1.0-W3-239` 具名例外）時為 true，載體依 SPEC-003
  /// §2.13〈截斷事件的日誌等級〉留痕；跨級別搶佔時為 false。
  final bool sameLevelReplace;
}

/// 跳過：自發型／可棄在通道被高級別持有時的動作（「跳過，不補跑」）。
final class AttentionSkipped extends AttentionDecision {
  const AttentionSkipped({required this.blockedBy});

  final AttentionHandle blockedBy;
}

/// 拒絕：等待型在通道被高級別持有時的動作，附可重試資訊。
///
/// 診斷日誌對應 [AttentionArbiterLogEvent.rejected]，僅用於本類別建構時
/// 經過裁決表判定的仲裁結局；請求識別為空或協定違規（持有期間再次請求）
/// 雖然也回傳本類別，日誌事件另記 [AttentionArbiterLogEvent.invalidRequest]
/// ——兩者不對應任何裁決表結果，是請求本身不合法而非在通道競爭中落敗
/// （SPEC-003 §2.17，`0.1.0-W3-277`）。
final class AttentionRejected extends AttentionDecision {
  const AttentionRejected({required this.blockedBy, required this.retryAfter});

  final AttentionHandle? blockedBy;

  /// 可重試資訊：訂閱後於持有者被消費時收到一次通知。
  final Stream<AttentionConsumed> retryAfter;
}

/// 延後：自發型／須留痕在通道被更高級別持有時的動作。仲裁器不保存此
/// 請求；請求方訂閱 `signal`，收到後重驗前提再重新 `request`。
final class AttentionDeferred extends AttentionDecision {
  const AttentionDeferred({required this.blockedBy, required this.signal});

  final AttentionHandle blockedBy;
  final Stream<AttentionConsumed> signal;
}

/// 持有者離開通道的原因（消費三形態 + 非消費的三種離開）。
enum AttentionReleaseReason {
  /// 使用者回應（按下動作、關卡決策、授權對話框回答）。
  responded,

  /// 使用者主動關閉。
  dismissed,

  /// 載體自然過期（SnackBar timeout）；或仲裁器懶檢查判定逾期。
  expired,

  /// 被高級別搶佔、或同級別取代而截斷（由仲裁器於接受當下記錄）。
  preempted,

  /// 接受後載體未呈現（如 context 已卸載）。
  notPresented,

  /// 我方撤回（`ScanNotifier.withdraw`）。
  withdrawn,
}

/// 「已消費」訊號的內容。
final class AttentionConsumed {
  const AttentionConsumed({
    required this.handle,
    required this.reason,
    required this.at,
  });

  final AttentionHandle handle;
  final AttentionReleaseReason reason;
  final DateTime at;
}

/// 目前持有者的快照（讀取用）。
final class AttentionHolder {
  const AttentionHolder({
    required this.handle,
    required this.presentedAt,
    required this.naturalLifespan,
  });

  final AttentionHandle handle;

  /// `presented` 尚未回報時為 `null`。
  final DateTime? presentedAt;

  /// 載體回報；關卡類為 `null`（無自然存活期）。
  final Duration? naturalLifespan;

  /// 最老未消費請求年齡（本專案恆等於持有者年齡）。年齡基準為
  /// [handle.acceptedAt]，不是 [presentedAt]——未 `presented` 時年齡自接受
  /// 起算，逾期判定的基準才是 `presentedAt`（兩者回答不同問題）。
  Duration ageAt(DateTime now) => now.difference(handle.acceptedAt);

  // 唯一呼叫點（presented()）恆無條件覆寫 naturalLifespan（含覆寫為
  // null，即清除自然存活期），不與既有值合併；不設可選旗標，因為從未
  // 有第二種呼法（F-5：原 clearNaturalLifespan 參數恆為 true 且命名與
  // 「已指派 true 卻讀作清除」互相矛盾，故直接移除）。
  AttentionHolder _copyWith({
    DateTime? presentedAt,
    required Duration? naturalLifespan,
  }) {
    return AttentionHolder(
      handle: handle,
      presentedAt: presentedAt ?? this.presentedAt,
      naturalLifespan: naturalLifespan,
    );
  }
}

/// 仲裁器診斷日誌的事件類別（PM 裁決缺口 3：新增 `presented`，共 12 值）。
///
/// `rejected` 與 `invalidRequest` 皆是「拒絕」大類，兩者在 `fields` 中
/// 皆帶 `outcome: 'rejected'`，故消費端可用單一條件
/// `fields['outcome'] == 'rejected'` 取得全部拒絕，不需同時比對兩個事件名
/// （`0.1.0-W3-277`）。`invalidRequest` 統一原本互斥的兩組欄位（請求識別
/// 為空、持有期間再次請求），兩者皆非仲裁結局，故不帶 `decision` 欄；
/// `rejected` 專用於裁決表判定的仲裁結局，帶 `decision` 而不帶 `reason`，
/// 藉此與 `invalidRequest`（帶 `reason` 不帶 `decision`）互斥區分「仲裁
/// 結局」與「請求不合法」兩條語意線。
enum AttentionArbiterLogEvent {
  accepted,
  preempted,
  sameLevelReplaced,
  skipped,
  rejected,
  deferred,
  presented,
  released,
  expired,
  releasedNonHolder,
  invalidRequest,
  levelClamped,
}

/// 通道（0.1 單通道，唯一值）。
enum AttentionLogChannel { userFocus }

/// 裁決結局類欄位值（`decision`）。
enum AttentionLogDecision { accepted, skipped, deferred, rejected }

/// 請求不合法或其他非仲裁結局的原因碼（`reason`）；離開類事件的原因碼
/// 改用 [AttentionReleaseReason]。
enum AttentionLogReason {
  emptyId,
  heldAndRequested,
  levelClamped,
  preempted,
  releasedNonHolder,
  presented,
}

/// 拒絕大類標記（`outcome`），消費端以單一條件取得全部拒絕。
enum AttentionLogOutcome { rejected }

/// 非持有者回報時的操作別（`op`）。
enum AttentionLogOp { presented, release }

/// 日誌負載鍵（具名常數，測試以常數比對）。時間量一律為毫秒整數。
abstract final class AttentionLogKeys {
  static const requestId = 'requestId';
  static const arrival = 'arrival';
  static const level = 'level';
  static const channel = 'channel';
  static const decision = 'decision';
  static const reason = 'reason';
  static const outcome = 'outcome';
  static const op = 'op';
  static const occupancyInFlight = 'occupancyInFlight';
  static const occupancyQueueDepth = 'occupancyQueueDepth';
  static const occupancyOldestAgeMs = 'occupancyOldestAgeMs';
  static const deadlineRemainingMs = 'deadlineRemainingMs';
  static const deadlineAssigned = 'deadlineAssigned';
  static const naturalLifespanRawMs = 'naturalLifespanRawMs';
  static const carrierEventId = 'carrierEventId';
  static const requestedLevel = 'requestedLevel';
  static const parentLevel = 'parentLevel';
}

/// 生產預設：經共用 writer 輸出，App 層 domain 為 `presentation`（FR-01）。
final LogSink<AttentionArbiterLogEvent> defaultAttentionArbiterLogSink =
    defaultLogSink<AttentionArbiterLogEvent>('presentation');

// 開發期不可達狀態錯誤訊息，非 user-facing 文案。
const String _unreachableSpontaneousUndroppableMessage = // i18n-exempt: 開發期斷言訊息
    'unreachable: spontaneous/undroppable cannot be preempted by a higher holder';

LogValue _intValue(int value) => LogValue.integer(value);

/// occupancy 攤平為整數欄位；空通道無 oldestAge 欄位。
Map<String, LogValue> _occupancyFields(int inFlight, Duration? oldestAge) => {
  AttentionLogKeys.occupancyInFlight: _intValue(inFlight),
  AttentionLogKeys.occupancyQueueDepth: _intValue(0),
  if (oldestAge != null)
    AttentionLogKeys.occupancyOldestAgeMs: _intValue(oldestAge.inMilliseconds),
};

// 呼叫端一律傳入該事件對應主體（請求或持有者）實際攜帶的 deadline；
// null 代表該主體確實未帶預算（0.1.0-W3-262），以 deadlineAssigned 標示。
Map<String, LogValue> _deadlineFields(Duration? deadline) => {
  if (deadline == null)
    AttentionLogKeys.deadlineAssigned: const LogValue.boolean(true)
  else
    AttentionLogKeys.deadlineRemainingMs: _intValue(deadline.inMilliseconds),
};

LogFields _payload({
  required String requestId,
  required AttentionArrival arrival,
  required AttentionLevel level,
  required Map<String, LogValue> occupancy,
  required Duration? deadline,
  AttentionLogDecision? decision,
  Enum? reason,
  AttentionLogOutcome? outcome,
  Map<String, LogValue> extra = const {},
}) => LogFields({
  AttentionLogKeys.requestId: LogValue.nodeId(requestId),
  AttentionLogKeys.arrival: LogValue.enumValue(arrival),
  AttentionLogKeys.level: LogValue.enumValue(level),
  AttentionLogKeys.channel: const LogValue.enumValue(
    AttentionLogChannel.userFocus,
  ),
  if (decision != null) AttentionLogKeys.decision: LogValue.enumValue(decision),
  if (reason != null) AttentionLogKeys.reason: LogValue.enumValue(reason),
  if (outcome != null) AttentionLogKeys.outcome: LogValue.enumValue(outcome),
  ...occupancy,
  ...extra,
  ..._deadlineFields(deadline),
});

/// 仲裁器介面。
abstract class AttentionArbiter {
  /// 請求佔用通道。同步、常數時間、不阻塞、不保存請求。
  AttentionDecision request(AttentionRequest request);

  /// 載體開始呈現時回報；`naturalLifespan` 為該載體的自然存活期。
  void presented(
    AttentionHandle handle, {
    required Duration? naturalLifespan,
    String? carrierEventId,
  });

  /// 持有者離開通道。非當前持有者的 handle 只留痕不改狀態。
  void release(AttentionHandle handle, AttentionReleaseReason reason);

  /// 目前持有者；空通道為 `null`。
  AttentionHolder? get holder;

  /// 「已消費」廣播。每次當前持有者離開即發出一則；無訂閱者時不緩衝。
  Stream<AttentionConsumed> get consumed;
}

/// [AttentionArbiter] 的唯一實作。
///
/// 狀態為恰一個可空的持有者槽，不是容量 1 的集合——容量 1 的佇列能通過
/// 每一條行為測試，卻把「第二筆」放回型別層；因此本類別內無任何
/// `List`／`Queue`／`Map`／`Set` 以 [AttentionRequest]／[AttentionHandle]
/// 為元素。
class AttentionArbiterImpl implements AttentionArbiter {
  AttentionArbiterImpl({
    DateTime Function()? now,
    LogSink<AttentionArbiterLogEvent>? logSink,
  }) : _now = now ?? DateTime.now,
       _logSink = logSink ?? defaultAttentionArbiterLogSink;

  final DateTime Function() _now;
  final LogSink<AttentionArbiterLogEvent> _logSink;

  AttentionHolder? _holder;

  final StreamController<AttentionConsumed> _consumedController =
      StreamController<AttentionConsumed>.broadcast();

  @override
  AttentionHolder? get holder => _holder;

  @override
  Stream<AttentionConsumed> get consumed => _consumedController.stream;

  /// 釋放廣播通道（provider 於容器銷毀時呼叫）。
  void dispose() {
    unawaited(_consumedController.close());
  }

  @override
  AttentionDecision request(AttentionRequest r) {
    // 步驟 0：輸入驗證（純輸入檢查，無副作用）。先於步驟 1，故無效請求不會
    // 觸發任何狀態變更（含逾期清除）。設計選擇，無測試覆蓋此順序
    // （Phase 3a 3a.8 第 6 列）。
    if (r.id.isEmpty) {
      _logSink(
        AttentionArbiterLogEvent.invalidRequest,
        _payload(
          requestId: '',
          arrival: r.arrival,
          level: r.level,
          reason: AttentionLogReason.emptyId,
          outcome: AttentionLogOutcome.rejected,
          occupancy: _occupancySnapshot(),
          deadline: r.deadline,
        ),
        level: LogLevel.warning,
      );
      // blockedBy 為 null（純輸入驗證失敗，非被任何持有者阻擋），
      // retryAfter 因此不對應任何特定持有者的消費事件；回傳空串流而非
      // 未過濾的 consumed 全量廣播，避免呼叫端誤把無關的釋放事件當成
      // 「可以重試了」的訊號（F-9）。
      return AttentionRejected(
        blockedBy: null,
        retryAfter: const Stream<AttentionConsumed>.empty(),
      );
    }

    // 步驟 1：逾期懶檢查（唯一會改狀態的前置步驟）。
    final currentHolder = _holder;
    if (currentHolder != null &&
        currentHolder.presentedAt != null &&
        currentHolder.naturalLifespan != null &&
        _now().difference(currentHolder.presentedAt!) >
            currentHolder.naturalLifespan!) {
      _expireHolderLazily();
    }

    // 步驟 2：禁止持有並等待（先於任何級別比較）。
    final holderAfterExpiry = _holder;
    if (holderAfterExpiry != null &&
        holderAfterExpiry.handle.requestId == r.id) {
      _logSink(
        AttentionArbiterLogEvent.invalidRequest,
        _payload(
          requestId: r.id,
          arrival: r.arrival,
          level: r.level,
          reason: AttentionLogReason.heldAndRequested,
          outcome: AttentionLogOutcome.rejected,
          occupancy: _occupancySnapshot(),
          deadline: r.deadline,
        ),
        level: LogLevel.warning,
      );
      return AttentionRejected(
        blockedBy: holderAfterExpiry.handle,
        retryAfter: consumed.where(
          (c) => c.handle.requestId == holderAfterExpiry.handle.requestId,
        ),
      );
    }

    // 步驟 3：級別傳播單調不升（先於裁決表）。
    var effectiveLevel = r.level;
    if (r.parentLevel != null && _isHigher(r.level, r.parentLevel!)) {
      effectiveLevel = r.parentLevel!;
      _logSink(
        AttentionArbiterLogEvent.levelClamped,
        _payload(
          requestId: r.id,
          arrival: r.arrival,
          level: effectiveLevel,
          reason: AttentionLogReason.levelClamped,
          occupancy: _occupancySnapshot(),
          deadline: r.deadline,
          extra: {
            AttentionLogKeys.requestedLevel: LogValue.enumValue(r.level),
            AttentionLogKeys.parentLevel: LogValue.enumValue(r.parentLevel!),
          },
        ),
        level: LogLevel.warning,
      );
    }

    // 步驟 4：裁決表（Phase 1 §2.4，唯一比較級別之處）。
    final holderForDecision = _holder;
    if (holderForDecision == null) {
      return _accept(
        r,
        effectiveLevel,
        preemptedHolder: null,
        sameLevelReplace: false,
      );
    }

    final holderLevel = holderForDecision.handle.level;

    if (_isHigher(effectiveLevel, holderLevel)) {
      return _accept(
        r,
        effectiveLevel,
        preemptedHolder: holderForDecision,
        sameLevelReplace: false,
      );
    }
    if (holderLevel == effectiveLevel) {
      return _accept(
        r,
        effectiveLevel,
        preemptedHolder: holderForDecision,
        sameLevelReplace: true,
      );
    }

    // holderLevel 較高（_isHigher(holderLevel, effectiveLevel)）
    switch (r.arrival) {
      case AttentionArrival.spontaneous:
        if (effectiveLevel == AttentionLevel.discardable) {
          _logSink(
            AttentionArbiterLogEvent.skipped,
            _payload(
              requestId: r.id,
              arrival: r.arrival,
              level: effectiveLevel,
              decision: AttentionLogDecision.skipped,
              occupancy: _occupancySnapshot(),
              deadline: r.deadline,
            ),
            level: LogLevel.warning,
          );
          return AttentionSkipped(blockedBy: holderForDecision.handle);
        }
        if (effectiveLevel == AttentionLevel.mustLeaveTrace) {
          final signal = consumed.where(
            (c) => c.handle.requestId == holderForDecision.handle.requestId,
          );
          _logSink(
            AttentionArbiterLogEvent.deferred,
            _payload(
              requestId: r.id,
              arrival: r.arrival,
              level: effectiveLevel,
              decision: AttentionLogDecision.deferred,
              occupancy: _occupancySnapshot(),
              deadline: r.deadline,
            ),
            level: LogLevel.warning,
          );
          return AttentionDeferred(
            blockedBy: holderForDecision.handle,
            signal: signal,
          );
        }
        // effectiveLevel == undroppable：不可達（不可棄已是最高級別，不存
        // 在更高的持有者）。以表達式窮舉承接，拋出狀態錯誤而非充數。
        throw StateError(_unreachableSpontaneousUndroppableMessage);
      case AttentionArrival.waiting:
        final level = _levelForOrigin(r.arrival);
        _logSink(
          AttentionArbiterLogEvent.rejected,
          _payload(
            requestId: r.id,
            arrival: r.arrival,
            level: effectiveLevel,
            decision: AttentionLogDecision.rejected,
            outcome: AttentionLogOutcome.rejected,
            occupancy: _occupancySnapshot(),
            deadline: r.deadline,
          ),
          level: level,
        );
        return AttentionRejected(
          blockedBy: holderForDecision.handle,
          retryAfter: consumed.where(
            (c) => c.handle.requestId == holderForDecision.handle.requestId,
          ),
        );
    }
  }

  AttentionAccepted _accept(
    AttentionRequest r,
    AttentionLevel effectiveLevel, {
    required AttentionHolder? preemptedHolder,
    required bool sameLevelReplace,
  }) {
    // occupancy 快照取「裁決前」（PM 裁決缺口 2）：必須在任何狀態變更之前
    // 讀取，否則空通道接受會誤讀成已寫入的新持有者。
    final occupancyBeforeDecision = preemptedHolder != null
        ? _occupancySnapshotFor(preemptedHolder)
        : _occupancySnapshot();

    AttentionHandle? preemptedHandle;
    if (preemptedHolder != null) {
      preemptedHandle = preemptedHolder.handle;
      _logSink(
        sameLevelReplace
            ? AttentionArbiterLogEvent.sameLevelReplaced
            : AttentionArbiterLogEvent.preempted,
        _payload(
          requestId: preemptedHandle.requestId,
          arrival: preemptedHandle.arrival,
          level: preemptedHandle.level,
          reason: AttentionLogReason.preempted,
          occupancy: occupancyBeforeDecision,
          deadline: preemptedHandle.deadline,
        ),
      );
      _holder = null;
      _broadcastConsumed(preemptedHandle, AttentionReleaseReason.preempted);
    }

    final handle = AttentionHandle(
      requestId: r.id,
      level: effectiveLevel,
      arrival: r.arrival,
      source: r.source,
      acceptedAt: _now(),
      deadline: r.deadline,
    );
    _holder = AttentionHolder(
      handle: handle,
      presentedAt: null,
      naturalLifespan: null,
    );
    _logSink(
      AttentionArbiterLogEvent.accepted,
      _payload(
        requestId: r.id,
        arrival: r.arrival,
        level: effectiveLevel,
        decision: AttentionLogDecision.accepted,
        occupancy: occupancyBeforeDecision,
        deadline: r.deadline,
      ),
    );
    return AttentionAccepted(
      handle: handle,
      preempted: preemptedHandle,
      sameLevelReplace: sameLevelReplace,
    );
  }

  @override
  void presented(
    AttentionHandle handle, {
    required Duration? naturalLifespan,
    String? carrierEventId,
  }) {
    final currentHolder = _holder;
    if (currentHolder == null ||
        currentHolder.handle.requestId != handle.requestId) {
      _logSink(
        AttentionArbiterLogEvent.releasedNonHolder,
        _payload(
          requestId: handle.requestId,
          arrival: handle.arrival,
          level: handle.level,
          reason: AttentionLogReason.releasedNonHolder,
          occupancy: _occupancySnapshot(),
          deadline: handle.deadline,
          extra: {
            AttentionLogKeys.op: const LogValue.enumValue(
              AttentionLogOp.presented,
            ),
          },
        ),
        level: LogLevel.warning,
      );
      return;
    }
    final effectiveLifespan =
        (naturalLifespan == null || naturalLifespan <= Duration.zero)
        ? null
        : naturalLifespan;
    _holder = currentHolder._copyWith(
      presentedAt: _now(),
      naturalLifespan: effectiveLifespan,
    );
    _logSink(
      AttentionArbiterLogEvent.presented,
      _payload(
        requestId: handle.requestId,
        arrival: handle.arrival,
        level: handle.level,
        reason: AttentionLogReason.presented,
        occupancy: _occupancySnapshot(),
        deadline: handle.deadline,
        extra: {
          if (naturalLifespan != null)
            AttentionLogKeys.naturalLifespanRawMs: _intValue(
              naturalLifespan.inMilliseconds,
            ),
          if (carrierEventId != null)
            AttentionLogKeys.carrierEventId: LogValue.nodeId(carrierEventId),
        },
      ),
    );
  }

  @override
  void release(AttentionHandle handle, AttentionReleaseReason reason) {
    final currentHolder = _holder;
    if (currentHolder == null ||
        currentHolder.handle.requestId != handle.requestId) {
      _logSink(
        AttentionArbiterLogEvent.releasedNonHolder,
        _payload(
          requestId: handle.requestId,
          arrival: handle.arrival,
          level: handle.level,
          reason: AttentionLogReason.releasedNonHolder,
          occupancy: _occupancySnapshot(),
          deadline: handle.deadline,
          extra: {
            AttentionLogKeys.op: const LogValue.enumValue(
              AttentionLogOp.release,
            ),
          },
        ),
        level: LogLevel.warning,
      );
      return;
    }
    // 顯式呼叫一律記為 released——「expired」日誌事件類別保留給步驟 1
    // 的懶檢查自動觸發（見 _expireHolderLazily），區分「載體主動回報」與
    // 「仲裁器自行判定逾期」兩種不同的可觀測路徑。
    _releaseHolder(reason, event: AttentionArbiterLogEvent.released);
  }

  /// 步驟 1 逾期懶檢查專用：持有者已逾期，仲裁器自行清除並留痕 `expired`。
  void _expireHolderLazily() {
    _releaseHolder(
      AttentionReleaseReason.expired,
      event: AttentionArbiterLogEvent.expired,
    );
  }

  void _releaseHolder(
    AttentionReleaseReason reason, {
    required AttentionArbiterLogEvent event,
  }) {
    final currentHolder = _holder;
    if (currentHolder == null) {
      return;
    }
    final leaving = currentHolder.handle;
    // 等級僅在 expired（步驟 1 懶檢查自動觸發）依發起者判定；released
    // 是持有者生命的正常終點，不論發起者一律 info（PM 裁決 F-1）。
    final level = event == AttentionArbiterLogEvent.expired
        ? _levelForOrigin(leaving.arrival)
        : LogLevel.info;
    _logSink(
      event,
      _payload(
        requestId: leaving.requestId,
        arrival: leaving.arrival,
        level: leaving.level,
        reason: reason,
        occupancy: _occupancySnapshotFor(currentHolder),
        deadline: leaving.deadline,
      ),
      level: level,
    );
    // 先清空再廣播（3a.4：即使日後改為同步投遞，訂閱者看到的也是「通道
    // 已空」而非中間態）。
    _holder = null;
    _broadcastConsumed(leaving, reason);
  }

  void _broadcastConsumed(
    AttentionHandle handle,
    AttentionReleaseReason reason,
  ) {
    if (!_consumedController.hasListener) {
      return;
    }
    scheduleMicrotask(() {
      if (_consumedController.isClosed) {
        return;
      }
      _consumedController.add(
        AttentionConsumed(handle: handle, reason: reason, at: _now()),
      );
    });
  }

  Map<String, LogValue> _occupancySnapshot() {
    final currentHolder = _holder;
    if (currentHolder == null) {
      return _occupancyFields(0, null);
    }
    return _occupancySnapshotFor(currentHolder);
  }

  Map<String, LogValue> _occupancySnapshotFor(AttentionHolder holderSnapshot) {
    return _occupancyFields(1, holderSnapshot.ageAt(_now()));
  }

  LogLevel _levelForOrigin(AttentionArrival arrival) {
    return arrival == AttentionArrival.spontaneous
        ? LogLevel.warning
        : LogLevel.info;
  }

  /// 級別比較恰在此一處（V-4），比較鍵為列舉序值。
  bool _isHigher(AttentionLevel a, AttentionLevel b) => a.index > b.index;
}

/// 單一實例暴露（T-30 只驗單例契約）。
final attentionArbiterProvider = Provider<AttentionArbiter>((ref) {
  final arbiter = AttentionArbiterImpl();
  ref.onDispose(arbiter.dispose);
  return arbiter;
});
