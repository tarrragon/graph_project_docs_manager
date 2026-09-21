/// Domain 視圖矩陣／泳道兩模式的固定假資料（設計約束：以假資料驅動格
/// 詳情卡與泳道節點，非真實 repo 解析，`0.1.0-W1-003`／CLAUDE.md §6
/// 「Domain 視圖的列無來源」現行待決同源）。
///
/// domain id 取自 `docs/domain-map.md` §3 Bundle 界定表既有四個
/// domain（workspace／schema／corpus／graph），UC id 沿用
/// `docs/usecases/`（UC-02／UC-04／UC-06）；步驟標籤為 fixture 資料本身，
/// 非 App UI 文案，故標 `i18n-exempt`（同 `trace_fixtures.dart` 慣例）。
/// 單一 [_FlowStepFixture] 清單是矩陣格詳情、矩陣關係符號、列小計、泳道
/// 節點四者的共同來源——`traverses` 包含即為該格「直接貫穿」，
/// 與 SPEC-001 §1〈矩陣格與泳道列的判定依據 FlowStep.traverses〉一致。
library;

import 'domain_view_state.dart';

/// 單一步驟的 fixture：標籤 + 直接觸及的 domain 清單 + 發出／消費事件。
class _FlowStepFixture {
  const _FlowStepFixture({
    required this.label,
    required this.traverses,
    this.emits = const [],
    this.consumes = const [],
  });

  final String label;
  final List<String> traverses;
  final List<String> emits;
  final List<String> consumes;
}

/// domain 與 UC 的固定順序（列序／欄序，SPEC-001 §1 acceptance 第四項）。
abstract final class DomainViewFixtures {
  static const List<String> domainIds = [
    'workspace',
    'schema',
    'corpus',
    'graph',
  ];

  static const Map<String, String> domainNames = {
    'workspace': 'Workspace', // i18n-exempt: fixture domain 名，非 App UI 文案
    'schema': 'Schema', // i18n-exempt: fixture domain 名，非 App UI 文案
    'corpus': 'Corpus', // i18n-exempt: fixture domain 名，非 App UI 文案
    'graph': 'Graph', // i18n-exempt: fixture domain 名，非 App UI 文案
  };

  static const List<DomainUc> ucColumns = [
    DomainUc(
      id: 'UC-02',
      title: '選擇並載入工作資料夾', // i18n-exempt: fixture UC 標題，非 App UI 文案
      hasFlowStep: true,
    ),
    DomainUc(
      id: 'UC-04',
      title: '解析圖譜節點與邊', // i18n-exempt: fixture UC 標題，非 App UI 文案
      hasFlowStep: true,
    ),
    DomainUc(
      id: 'UC-06',
      title: '檢視節點詳情', // i18n-exempt: fixture UC 標題，非 App UI 文案
      hasFlowStep: false,
    ),
  ];

  /// UC-02：8 個步驟，`workspace` 全數含括（觸發右欄捲動 + 三區塊皆有的
  /// 假資料要求，SPEC-003 §3.1〈格詳情卡的內容契約〉段末假資料約束）；
  /// 第 5、6 步驟另觸及 `graph`。
  static const List<_FlowStepFixture> _uc02Steps = [
    _FlowStepFixture(
      label: 'Step 1: 選擇資料夾', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace'],
    ),
    _FlowStepFixture(
      label: 'Step 2: 讀取已存路徑', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace'],
    ),
    _FlowStepFixture(
      label: 'Step 3: 探測資料夾可用性', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace'],
    ),
    _FlowStepFixture(
      label: 'Step 4: 記住已選路徑', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace'],
    ),
    _FlowStepFixture(
      label: 'Step 5: 建立圖索引', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace', 'graph'],
      emits: ['graph.index.rebuilt'],
    ),
    _FlowStepFixture(
      label: 'Step 6: 檢查對稱聯集', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace', 'graph'],
      consumes: ['graph.index.rebuilt'],
      emits: ['graph.sync.done'],
    ),
    _FlowStepFixture(
      label: 'Step 7: 快取解析結果', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace'],
    ),
    _FlowStepFixture(
      label: 'Step 8: 通知載入完成', // i18n-exempt: fixture 步驟標籤
      traverses: ['workspace'],
    ),
  ];

  /// UC-04：3 個步驟，分別觸及 `schema`／`graph`／`corpus`＋`graph`。
  static const List<_FlowStepFixture> _uc04Steps = [
    _FlowStepFixture(
      label: 'Step 1: 讀取 schema 定義', // i18n-exempt: fixture 步驟標籤
      traverses: ['schema'],
    ),
    _FlowStepFixture(
      label: 'Step 2: 建立節點索引', // i18n-exempt: fixture 步驟標籤
      traverses: ['graph'],
    ),
    _FlowStepFixture(
      label: 'Step 3: 掃描原始節點', // i18n-exempt: fixture 步驟標籤
      traverses: ['corpus', 'graph'],
    ),
  ];

  static const Map<String, List<_FlowStepFixture>> _stepsByUc = {
    'UC-02': _uc02Steps,
    'UC-04': _uc04Steps,
    'UC-06': [],
  };

  /// `workspace × UC-04` 為刻意留白的「僅標題與關係種類」格
  /// （間接依賴，判定式待決見 `0.1.0-W3-376`，此處為 fixture 直接標記值，
  /// 不涉推導公式）。
  static const Map<String, DomainRelation> _indirectOverrides = {
    'workspace|UC-04': DomainRelation.indirect,
  };

  /// `workspace × UC-02` 的說明文字（「三區塊皆有」的假資料要求）。
  static const Map<String, String> _explanations = {
    'workspace|UC-02':
        '本步驟序列於本地已解析資料上執行，無外部服務等待。', // i18n-exempt: fixture 說明文字，非 App UI 文案
  };

  /// 矩陣列（SPEC-001 §1 acceptance 第四項：列序由假資料給定）。
  static List<DomainRow> get rows => [
    for (final domainId in domainIds) _buildRow(domainId),
  ];

  static DomainRow _buildRow(String domainId) {
    final cells = [for (final uc in ucColumns) _buildCell(domainId, uc.id)];
    final subtotal = cells
        .where((c) => c.relation == DomainRelation.direct)
        .length;
    return DomainRow(
      domainId: domainId,
      domainName: domainNames[domainId]!,
      cells: cells,
      subtotal: subtotal,
    );
  }

  static DomainCell _buildCell(String domainId, String ucId) {
    final steps = _stepsByUc[ucId]!
        .where((s) => s.traverses.contains(domainId))
        .toList(growable: false);
    final relation = steps.isNotEmpty
        ? DomainRelation.direct
        : (_indirectOverrides['$domainId|$ucId'] ?? DomainRelation.none);
    if (relation != DomainRelation.direct) {
      return DomainCell(domainId: domainId, ucId: ucId, relation: relation);
    }
    final events = <(String, bool)>[];
    for (final step in steps) {
      for (final e in step.emits) {
        events.add((e, true));
      }
      for (final c in step.consumes) {
        events.add((c, false));
      }
    }
    return DomainCell(
      domainId: domainId,
      ucId: ucId,
      relation: relation,
      explanation: _explanations['$domainId|$ucId'],
      steps: [for (final s in steps) s.label],
      events: events,
    );
  }

  /// 泳道列（SPEC-001 §1 acceptance 第四項：泳道節點所屬列依
  /// `FlowStep.traverses`，欄序即步驟在該 UC 內的原始順序索引）。
  /// [ucId] 須為 `hasFlowStep == true` 的 UC，呼叫端保證（`UC-06` 不應
  /// 呼叫本函式）。
  static List<DomainLane> lanesForUc(String ucId) {
    final steps = _stepsByUc[ucId] ?? const [];
    return [
      for (final domainId in domainIds)
        DomainLane(
          domainId: domainId,
          nodes: [
            for (var i = 0; i < steps.length; i++)
              if (steps[i].traverses.contains(domainId))
                DomainLaneNode(
                  stepLabel: steps[i].label,
                  column: i,
                  stepTraverses: steps[i].traverses,
                ),
          ],
        ),
    ];
  }
}
