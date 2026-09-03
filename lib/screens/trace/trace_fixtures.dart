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

  /// 鏈路斷裂態：在正常態的樹之外，另有 PROP-005 的 `outputs.spec_refs`
  /// 為空清單——真實存在於 `test/fixtures/corpus/monitor/` 的缺口形態。
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
  ];
}
