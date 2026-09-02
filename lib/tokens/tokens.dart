/// Design token barrel 匯出（SPEC-002）。
///
/// 集中匯出 `lib/tokens/` 下所有語意層 token，供畫面與元件單一入口引用，
/// 避免逐檔各自 import。
library;

export 'colors.dart';
export 'layout.dart';
export 'spacing.dart';
export 'typography.dart';
