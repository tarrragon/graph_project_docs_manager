/// 測試文案常數（SPEC-004 §4.0.4）。
///
/// 每個文字 slot 的「最長文案」在此具名，元件票的 widget test 以
/// `TestCopy.<slot>` 引用，不在各測試檔內各自造長字串——文案來源
/// （語料檔、設計稿、人工）與值一併固定於此，SPEC-004 §4.0.4 表為權威，
/// 本檔只是它的 Dart 形式，值有出入以該表為準。
///
/// 三條人工文案的用途區分：
///
/// | 常數 | 用途 |
/// |------|------|
/// | [TestCopy.longZh] | 中文長句，句號外無斷行機會，驗證截斷／換行處置 |
/// | [TestCopy.longEn] | 英文長句，有空白（可換行），驗證換行行為 |
/// | [TestCopy.longToken] | 無任何斷字機會的單一 token，驗證省略號 |
library;

/// 供元件測試引用的最長文案集合。值對應 SPEC-004 §4.0.4 表。
abstract final class TestCopy {
  /// 人工中文長文案：除句號外不含空白或斷行機會。
  static const String longZh =
      '這是一段用於溢位測試的人工長文案，長度刻意超過任何畫面可容納的單行寬度，'
      '且除句號外不含任何空白或斷行機會，用來驗證截斷與換行處置是否依契約執行。';

  /// 人工英文長文案：含空白，可換行。
  static const String longEn =
      'This is an artificially long test copy whose length deliberately '
      'exceeds any single-line width the layout can hold, used to verify '
      'that truncation and wrapping behave exactly as the content policy '
      'states.';

  /// 無斷字機會的單一 token，用於省略號斷言。
  static const String longToken =
      'Pneumonoultramicroscopicsilicovolcanoconiosis-'
      'supercalifragilisticexpialidocious-longest-unbreakable-token-for-ellipsis';

  /// 節點標題（`test/fixtures/corpus/book_overview_app` PROP-016 title）。
  static const String nodeTitle =
      '元件庫統一化（Extension 端）——ui-factory 升級為核心元件庫並對齊 APP 命名契約';

  /// 節點 id（同上語料最長 id）。
  static const String nodeId = 'DOMAIN-MAP-version-management';

  /// 檔案路徑（同上語料最長路徑，專案相對）。
  static const String filePath =
      'docs/spec/version-management/SPEC-016-version-management-data-contract.md';

  /// 狀態值（語料 status 值中最長）。
  static const String status = 'implemented';

  /// domain 名（語料 DOMAIN-MAP id 的 domain 段）。
  static const String domainName = 'version-management';

  /// UC 標題（`book_overview_app` 語料）。
  static const String ucName = 'UC-09: Error Fingerprint 分群與調查';

  /// flow 步驟名（`docs/usecases/` 本專案最長）。
  static const String stepName = '版本不符拒絕渲染';

  /// 事件標籤（本專案事件 ID 最長 + 前綴）。
  static const String eventLabel = 'consumes EVT-DIAGNOSTICS-001';

  /// 專案名（`design/ProjectPickerD.dc.html`）。
  static const String projectName = 'book_overview_app';

  /// 專案摘要（`design/ProjectPickerD.dc.html`）。
  static const String projectSummary = '237 節點 · 2419 票';

  /// 主題名（`docs/work-logs/topics-registry.txt` 最長）。
  static const String topicName = 'markdown 顯示與編輯';

  /// 破洞標題（`design/GapReportA.dc.html`）。
  static const String gapTitle = '130 張 ticket 的 frontmatter 未閉合引號';

  /// 破洞說明（`design/GapReportA.dc.html`）。
  static const String gapDescription = 'acceptance 欄位全數無法讀取';

  /// 三條人工長文案的集合，供「每個文字 slot × 每條長文案」矩陣展開。
  static const List<String> longCopies = [longZh, longEn, longToken];
}
