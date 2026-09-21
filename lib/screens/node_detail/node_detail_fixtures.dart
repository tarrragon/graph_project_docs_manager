/// 節點詳情（SPEC-001 §6）固定假資料（設計約束同 `trace_fixtures.dart`：
/// 節點 id／標題／路徑取材自 `test/fixtures/corpus/` 的真實樣本，內容非
/// 逐字複製全文）。
///
/// `e2e-contract` 的 markdown 為代表性長文樣本，行數比照
/// `test/fixtures/corpus/book_overview_v1/docs/spec/extraction/e2e-contract.md`
/// （1673 行）數量級，用於觸發節點詳情主欄 `Panel.scrollable` 捲動測試；
/// `csv-export-spec` 借用 `gap_report_provider.dart` 已驗證的缺
/// frontmatter 樣本（同一真實 repo 快照 `book_overview_v1`），模擬部分
/// 損壞態的欄位級遺失。兩節點的 `filePath` 皆不對應磁碟上任何檔案（0.1
/// 假資料，同 `domain_view_screen.dart` 泳道開啟原始檔慣例），開啟原始檔
/// 恆走 `notFound` 分支。
library;

/// 一個關聯節點分節：標題 + 節點 id 清單（`Section.static` 一節對應一個
/// 分類，`RelationItem` chip 逐項渲染，SPEC-004 §3.6 §6「正常」列）。
class NodeRelationCategory {
  const NodeRelationCategory({required this.label, required this.nodeIds});

  /// 分節標題（`AppText.caption`）。
  final String label;

  /// 關聯節點 id 清單（[NodeDetailFixtures.nodes] 鍵值）。
  final List<String> nodeIds;
}

/// 單一節點的完整假資料（`ListRow.meta` + `AppText.title` + `BadgeRow` +
/// `DocumentBody` + 右欄關聯分節，SPEC-004 §3.6 §6「正常」列）。
class NodeDetailFixture {
  const NodeDetailFixture({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.filePath,
    required this.markdown,
    this.damagedFields = const [],
    this.relations = const [],
  });

  final String id;

  /// 節點型別（PROP／SPEC／UC／Ticket），`ListRow.meta` leading
  /// `Badge.type`；[damagedFields] 含 `'type'` 時該欄改渲染
  /// `IssueMarker.damagedDetail`。
  final String type;

  /// 節點狀態（`Badge.status`，值需落在元件庫 `_statusToneMap` 對映內）。
  final String status;

  /// 節點標題（`AppText.title`）。
  final String title;

  /// 檔案路徑（`ListRow.meta` 主文字；「開啟原始檔」目標路徑）。
  final String filePath;

  /// 主欄 `DocumentBody` 的 markdown 原文。
  final String markdown;

  /// 因檔案損壞而無法讀取的欄位名（目前只示範 `'type'`）；0.1 fixture
  /// 只示範單一欄位損壞，多欄同時損壞的多實例錨點模式（SPEC-003 §3.6
  /// 「同一錨點多實例，斷言以祖先限定 finder」）留待真實資料整合後視
  /// 情況擴充。
  final List<String> damagedFields;

  /// 右欄關聯分節（`Section.static` × N）。
  final List<NodeRelationCategory> relations;
}

/// 節點詳情固定假資料庫。
abstract final class NodeDetailFixtures {
  /// 正常態節點 id（`e2e-contract`，長文樣本）。
  static const String normalNodeId = 'e2e-contract';

  /// 部分損壞態節點 id（`csv-export-spec`，缺 frontmatter 樣本）。
  static const String partialNodeId = 'csv-export-spec';

  /// 節點 id → 完整假資料。
  static final Map<String, NodeDetailFixture> nodes = {
    normalNodeId: NodeDetailFixture(
      id: normalNodeId,
      type: 'SPEC', // i18n-exempt: fixture 資料值，非 App UI 文案
      status: 'draft', // i18n-exempt: fixture 資料值
      title: 'E2E 提取流程契約規格', // i18n-exempt: fixture 節點標題，非 App UI 文案
      filePath:
          'docs/spec/extraction/e2e-contract.md', // i18n-exempt: fixture 路徑字面
      markdown: _longMarkdownSample,
      relations: const [
        NodeRelationCategory(
          label: '關聯節點', // i18n-exempt: fixture 分節標題，非 App UI 文案
          nodeIds: [partialNodeId],
        ),
      ],
    ),
    partialNodeId: NodeDetailFixture(
      id: partialNodeId,
      type: 'SPEC', // i18n-exempt: fixture 資料值
      status: 'draft', // i18n-exempt: fixture 資料值
      title: 'CSV 匯出規格', // i18n-exempt: fixture 節點標題，非 App UI 文案
      filePath: 'docs/spec/csv-export-spec.md', // i18n-exempt: fixture 路徑字面
      markdown:
          '# CSV 匯出規格\n\n本檔缺 frontmatter，型別欄位無法解析。', // i18n-exempt: fixture 內文
      damagedFields: const ['type'],
      relations: const [
        NodeRelationCategory(
          label: '關聯節點', // i18n-exempt: fixture 分節標題，非 App UI 文案
          nodeIds: [normalNodeId],
        ),
      ],
    ),
  };

  /// 代表性長文樣本：行數比照真實 corpus 樣本數量級（見檔頭說明），
  /// 觸發 `Panel.scrollable` 主欄捲動測試，非逐字複製全文。
  static String get _longMarkdownSample {
    final buffer = StringBuffer()
      ..writeln('# E2E 提取流程契約規格') // i18n-exempt: fixture 內文
      ..writeln();
    for (var i = 1; i <= 420; i++) {
      buffer
        ..writeln('## 第 $i 節') // i18n-exempt: fixture 內文
        ..writeln()
        ..writeln('本節示範內容，用於驗證節點詳情主欄可正確捲動長文件。') // i18n-exempt: fixture 內文
        ..writeln();
    }
    return buffer.toString();
  }
}
