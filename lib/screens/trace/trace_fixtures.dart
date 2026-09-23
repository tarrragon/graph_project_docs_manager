/// 追溯視圖三個狀態的固定樹狀資料（設計約束：真實 repo 快照而非生成器，
/// `test/fixtures/corpus/` 收錄理由同源）。
///
/// 本檔的節點 id／標題／狀態取材自 `test/fixtures/corpus/monitor/` 的真實
/// 節點檔（PROP-001、SPEC-001、UC-01、PROP-005），非隨機或想像資料——與
/// `tool/snapshot_corpus.dart` 的設計約束一致：損壞形態必須是實際存在過的
/// 形態。本票範圍只交狀態渲染，故以字面值內嵌，不在執行期解析 corpus
/// 檔案。節點標題為 fixture 資料本身（未來由真實 repo 解析取得），非
/// App 自身的 UI 文案，故不進 i18n（`// i18n-exempt` 逐行標示）。
library;

import 'trace_state.dart';

/// 追溯視圖三個狀態各自的固定樹狀資料。
abstract final class TraceabilityFixtures {
  /// 正常態：PROP-001 → SPEC-001 → UC-01，皆有下游節點。
  ///
  /// 樹狀資料填至 UC 層（CLAUDE.md §6：UC → Ticket 無對應邊，全域結構性
  /// 缺口，非本節點的個別鏈路斷裂，故正常態不對 UC 層標示缺口）。
  static const List<TraceNode> normal = [
    TraceNode(
      id: 'PROP-001',
      label:
          'PROP-001 Monitor MVP — 端到端事件收集與查詢', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      children: [
        TraceNode(
          id: 'SPEC-001',
          label:
              'SPEC-001 事件格式契約（Event Schema）', // i18n-exempt: fixture 節點標題，非 App UI 文案
          status: 'draft',
          children: [
            TraceNode(
              id: 'UC-01',
              label:
                  'UC-01 端到端事件流', // i18n-exempt: fixture 節點標題，非 App UI 文案
              status: 'draft',
            ),
          ],
        ),
      ],
    ),
  ];

  /// 鏈路斷裂態：在正常態的樹之外，另有 PROP-005、PROP-006 的
  /// `outputs.spec_refs` 皆為空清單——真實存在於
  /// `test/fixtures/corpus/monitor/` 的缺口形態，兩個各自獨立的缺下游父
  /// 節點用以驗證 key 以 nodeId 產生時彼此不衝突（本票 acceptance 第一項）。
  static const List<TraceNode> broken = [
    ...normal,
    TraceNode(
      id: 'PROP-005',
      label:
          'PROP-005 JSONL 匯出與備份', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      hasGap: true,
      gapLayer: 'spec',
    ),
    TraceNode(
      id: 'PROP-006',
      label:
          'PROP-006 容器化部署', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      hasGap: true,
      gapLayer: 'spec',
    ),
    TraceNode(
      id: 'PROP-007',
      label:
          'PROP-007 稽核軌跡匯出', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      children: [
        TraceNode(
          id: 'SPEC-007',
          label:
              'SPEC-007 稽核事件格式', // i18n-exempt: fixture 節點標題，非 App UI 文案
          status: 'draft',
          hasGap: true,
          gapLayer: 'uc',
        ),
      ],
    ),
  ];

  /// 共用子樹：SPEC-008（含子節點 UC-08），供 [multiParent] 於兩個父節點
  /// （PROP-008、PROP-009）下重複使用——驗證同一 [TraceNode.id] 於多個
  /// 出現位置共用展開狀態（SPEC-003 §3.3〈多父節點〉，`0.1.0-W3-383`）。
  static const TraceNode _sharedSpec008 = TraceNode(
    id: 'SPEC-008',
    label:
        'SPEC-008 共用契約（多父節點示例）', // i18n-exempt: fixture 節點標題，非 App UI 文案
    status: 'draft',
    children: [
      TraceNode(
        id: 'UC-08',
        label:
            'UC-08 共用流程（多父節點示例）', // i18n-exempt: fixture 節點標題，非 App UI 文案
        status: 'draft',
      ),
    ],
  );

  /// 共用缺口節點：SPEC-009（`hasGap`），供 [multiParent] 於兩個父節點
  /// （PROP-010、PROP-011）下重複使用——驗證同一缺口 [TraceNode.id] 於多個
  /// 出現位置各自渲染一個 `badge-traceability-broken-<id>`
  /// （SPEC-003 §3.3〈多父節點〉，`0.1.0-W3-383`）。
  static const TraceNode _sharedGapSpec009 = TraceNode(
    id: 'SPEC-009',
    label:
        'SPEC-009 缺口示例（多父節點示例）', // i18n-exempt: fixture 節點標題，非 App UI 文案
    status: 'draft',
    hasGap: true,
    gapLayer: 'uc',
  );

  /// 多父節點態：同一 [TraceNode.id] 於不同父節點下各出現一次
  /// （SPEC-003 §3.3〈多父節點〉，`0.1.0-W3-383` acceptance）。
  ///
  /// - PROP-008 / PROP-009 各掛一份 [_sharedSpec008]（非缺口，驗證展開
  ///   狀態共用）。
  /// - PROP-010 / PROP-011 各掛一份 [_sharedGapSpec009]（缺口，驗證缺口
  ///   標示按出現位置各自渲染）。
  static const List<TraceNode> multiParent = [
    TraceNode(
      id: 'PROP-008',
      label:
          'PROP-008 多父節點示例 A', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      children: [_sharedSpec008],
    ),
    TraceNode(
      id: 'PROP-009',
      label:
          'PROP-009 多父節點示例 B', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      children: [_sharedSpec008],
    ),
    TraceNode(
      id: 'PROP-010',
      label:
          'PROP-010 多父節點缺口示例 A', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      children: [_sharedGapSpec009],
    ),
    TraceNode(
      id: 'PROP-011',
      label:
          'PROP-011 多父節點缺口示例 B', // i18n-exempt: fixture 節點標題，非 App UI 文案
      status: 'draft',
      children: [_sharedGapSpec009],
    ),
  ];
}
