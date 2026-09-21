/// UC Flow 視圖的固定假資料（設計約束：假資料驅動，不接真實圖建置，
/// `0.1.0-W1-003`／CLAUDE.md §6 同源；UC id 沿用 `domain_view_fixtures.dart`
/// 既有三個 UC，維持跨畫面一致）。
///
/// **本票（`0.1.0-W2-010`）擴充**：原檔僅 `id` + `hasFlowStep`，不足以
/// 渲染「正常」態的步驟表與事件流小表（SPEC-001 §2、SPEC-004 §3.6 §2）；
/// 新增 `title`（UC 選擇入口主文字）與 `steps`（步驟表來源，`hasFlowStep`
/// 為 `false` 者維持空清單）。標題取自 `docs/usecases/` 對應 UC 的
/// frontmatter `title`；步驟為本畫面專屬 fixture，domain 取自
/// `domain_view_fixtures.dart` 同 UC 步驟 `traverses` 的代表值（單一
/// domain 欄，非清單），事件配對刻意維持同 UC 內發出／消費皆有（不觸發
/// 「本 UC 外」分支，該分支依賴的 EVT 節點 frontmatter `consumers`／
/// `producers` 資料本畫面尚未接線，見本票 Solution）。
library;

/// 單一步驟：標籤 + 觸及的單一 domain + 發出／消費事件。
class UcFlowFixtureStep {
  const UcFlowFixtureStep({
    required this.label,
    required this.domain,
    this.emits = const [],
    this.consumes = const [],
  });

  final String label;
  final String domain;
  final List<String> emits;
  final List<String> consumes;
}

/// UC 清單項：id + 標題 + 是否含結構化 flow（`hasFlowStep`，決定選定後落
/// 「flow 未結構化」或「正常」）+ 步驟（`hasFlowStep` 為 `false` 時為空）。
class UcFlowFixtureUc {
  const UcFlowFixtureUc({
    required this.id,
    required this.title,
    required this.hasFlowStep,
    this.steps = const [],
  });

  final String id;
  final String title;
  final bool hasFlowStep;
  final List<UcFlowFixtureStep> steps;
}

/// UC Flow 視圖固定假資料入口。
abstract final class UcFlowFixtures {
  /// 專案內全部 UC 節點（決定「無 UC」與「尚未選定 UC」的分派）。
  static const List<UcFlowFixtureUc> ucList = [
    UcFlowFixtureUc(
      id: 'UC-02',
      title: '依 domain 盤點變更影響面', // i18n-exempt: fixture UC 標題，非 App UI 文案
      hasFlowStep: true,
      steps: [
        UcFlowFixtureStep(
          label: '選擇資料夾', // i18n-exempt: fixture 步驟標籤
          domain: 'workspace',
        ),
        UcFlowFixtureStep(
          label: '建立圖索引', // i18n-exempt: fixture 步驟標籤
          domain: 'graph',
          emits: ['graph.index.rebuilt'], // i18n-exempt: fixture 事件 ID
        ),
        UcFlowFixtureStep(
          label: '檢查對稱聯集', // i18n-exempt: fixture 步驟標籤
          domain: 'graph',
          consumes: ['graph.index.rebuilt'], // i18n-exempt: fixture 事件 ID
        ),
      ],
    ),
    UcFlowFixtureUc(
      id: 'UC-04',
      title: '追溯一項需求的實現鏈', // i18n-exempt: fixture UC 標題，非 App UI 文案
      hasFlowStep: true,
      steps: [
        UcFlowFixtureStep(
          label: '讀取 schema 定義', // i18n-exempt: fixture 步驟標籤
          domain: 'schema',
        ),
        UcFlowFixtureStep(
          label: '建立節點索引', // i18n-exempt: fixture 步驟標籤
          domain: 'graph',
        ),
        UcFlowFixtureStep(
          label: '掃描原始節點', // i18n-exempt: fixture 步驟標籤
          domain: 'corpus',
        ),
      ],
    ),
    UcFlowFixtureUc(
      id: 'UC-06',
      title: '找出並修復文件破洞', // i18n-exempt: fixture UC 標題，非 App UI 文案
      hasFlowStep: false,
    ),
  ];
}
