/// UC Flow 視圖的固定假資料（0.5.0-W1-114.18 起僅供測試注入，畫面與
/// providers 不讀取；UC id 取自下方 `ucList` 的三個 UC）。
///
/// 事件配對刻意維持同 UC 內發出／消費皆有（不觸發「本 UC 外」分支）。
library;

import 'uc_flow_state.dart';

/// UC Flow 視圖固定假資料入口（測試以 `ucFlowUcListProvider` 注入）。
abstract final class UcFlowFixtures {
  /// 三個 UC：兩個含結構化 flow、一個無步驟。
  static const List<UcFlowUcItem> ucList = [
    UcFlowUcItem(
      id: 'UC-02',
      title: '依 domain 盤點變更影響面', // i18n-exempt: fixture UC 標題，非 App UI 文案
      filePath: 'docs/usecases/UC-02-assess-change-impact-by-domain.md', // i18n-exempt: fixture 路徑字面
      steps: [
        UcFlowStepItem(
          id: 'pick-folder', // i18n-exempt: fixture 步驟 id
          label: '選擇資料夾', // i18n-exempt: fixture 步驟標籤
          domain: 'workspace',
        ),
        UcFlowStepItem(
          id: 'build-index', // i18n-exempt: fixture 步驟 id
          label: '建立圖索引', // i18n-exempt: fixture 步驟標籤
          domain: 'graph',
          emits: ['graph.index.rebuilt'], // i18n-exempt: fixture 事件 ID
        ),
        UcFlowStepItem(
          id: 'check-symmetric', // i18n-exempt: fixture 步驟 id
          label: '檢查對稱聯集', // i18n-exempt: fixture 步驟標籤
          domain: 'graph',
          consumes: ['graph.index.rebuilt'], // i18n-exempt: fixture 事件 ID
        ),
      ],
    ),
    UcFlowUcItem(
      id: 'UC-04',
      title: '追溯一項需求的實現鏈', // i18n-exempt: fixture UC 標題，非 App UI 文案
      filePath: 'docs/usecases/UC-04-trace-a-requirement-implementation-chain.md', // i18n-exempt: fixture 路徑字面
      steps: [
        UcFlowStepItem(
          label: '讀取 schema 定義', // i18n-exempt: fixture 步驟標籤
          domain: 'schema',
        ),
        UcFlowStepItem(
          label: '建立節點索引', // i18n-exempt: fixture 步驟標籤
          domain: 'graph',
        ),
        UcFlowStepItem(
          label: '掃描原始節點', // i18n-exempt: fixture 步驟標籤
          domain: 'corpus',
        ),
      ],
    ),
    UcFlowUcItem(
      id: 'UC-06',
      title: '找出並修復文件破洞', // i18n-exempt: fixture UC 標題，非 App UI 文案
      filePath: 'docs/usecases/UC-06-find-and-fix-document-gaps.md', // i18n-exempt: fixture 路徑字面
    ),
  ];
}
