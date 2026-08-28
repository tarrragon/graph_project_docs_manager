/// 字級 token（SPEC-002 FR-04）。
///
/// artboard 實測字級為 9.5、10、10.5、11、11.5、12、12.5、13、14、15、19
/// （`grep -ohE 'font-size: *[0-9.]+px' design/*.dc.html | grep -oE
/// '[0-9.]+' | sort -n | uniq -c` 可重跑），同屬產生器輸出而非設計過的
/// 尺度，歸納為 4 階：
///
/// | 階 | 值 | 吸收的 artboard 原始值 | 觀察到的用途 |
/// |----|----|------------------------|--------------|
/// | [AppFontSize.caption] | 10 | 9.5、10、10.5 | 輔助說明、次要標籤（徽章、狀態 chip、欄位標籤、表格欄首） |
/// | [AppFontSize.body] | 12 | 11、11.5、12、12.5、13 | 內文、清單項、步驟說明、等寬值顯示（實測最大宗） |
/// | [AppFontSize.subtitle] | 14 | 14、15 | 小標題、強調文字 |
/// | [AppFontSize.title] | 19 | 19（僅 1 次，未歸併） | 頁面標題 |
///
/// `10.5` 與 `11.5` 數值上分別與 `10`／`12` 等距，歸階依實際用途而非
/// 就近湊整：
///
/// - `10.5`（58 次，全設計最高頻）於 artboard 中只用於徽章／狀態文字
///   （如 `SPEC`、`draft`、`completed`、`pending`）、欄位標籤（如
///   `source_proposal`）與表格欄首（如 `ID`、`標題`、`狀態`），與既有
///   `caption`（10）用途一致，歸入 `caption`。
/// - `11.5`（55 次）於 artboard 中用於段落說明（`line-height:1.7` 的
///   內文）、等寬值顯示（如 `PROP-002`、`UC-02`）、泳道節點動作標籤
///   （如「掃描」「解析」「建圖」）與步驟說明（如「掃描專案目錄」），
///   與既有 `body`（12）用途一致，歸入 `body`。
library;

/// 字級離散尺度。畫面只引用具名階，不接受任意數字。
abstract final class AppFontSize {
  static const double caption = 10; // magic-exempt token 定義本身
  static const double body = 12; // magic-exempt token 定義本身
  static const double subtitle = 14; // magic-exempt token 定義本身
  static const double title = 19; // magic-exempt token 定義本身
}
