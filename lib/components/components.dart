/// 元件庫 barrel 匯出（SPEC-004）。
///
/// 集中匯出 `lib/components/` 下所有元件，供畫面單一入口引用，
/// 避免逐檔各自 import。逐票新增自己的 export 行，不重排既有行。
library;

export 'app_icon.dart';
export 'app_text.dart';
export 'divider.dart';
export 'page_title.dart';
