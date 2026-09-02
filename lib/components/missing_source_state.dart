/// MissingSourceState（SPEC-004 §4.22）。
///
/// 節點詳情原始檔已不存在時的顯示狀態：訊息 + 最後已知路徑 + 重新整理。
/// 退出留在畫面內（重新整理三分支由呼叫端處理，SPEC-003 §3.6）；返回鍵
/// 由頁面框架統一渲染於 `SplitRow.header`（SPEC-003 §2.4），本元件動作列
/// 只放重新整理（見 SPEC-004 §4.22「互動反應」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'button_row.dart';

/// 「原始檔已不存在」狀態（SPEC-004 §4.22）。單一變體。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [path] | 是 | 最後已知路徑（呼叫端資料值） |
/// | [onRefresh] | 是 | 重新整理回呼；三分支結果處置由呼叫端承擔 |
/// | [testKey] | 是 | 呼叫端定址 key（`state-nodeDetail-missing`） |
class MissingSourceState extends StatelessWidget {
  const MissingSourceState({
    super.key,
    required this.path,
    required this.onRefresh,
    required this.testKey,
  });

  /// 最後已知路徑（呼叫端資料值；標籤組字由本元件的
  /// `lastKnownPathLabel` 引用承擔）。
  final String path;

  /// 重新整理回呼；`Motion.cancelDeadline` 內抵達的三分支結果（仍不存在／
  /// 完整／斷點）由呼叫端處理，本元件只轉發點選。
  final VoidCallback onRefresh;

  /// 呼叫端定址 key。
  final Key testKey;

  static const Key _refreshKey = Key('action-nodeDetail-refresh');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: testKey,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: LayoutSize.detailPaneWidth * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              liveRegion: true,
              child: AppText(
                l10n.sourceFileMissingMessage,
                variant: AppTextVariant.subtitle,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: Space.xs.h),
            AppText(
              l10n.lastKnownPathLabel(path),
              variant: AppTextVariant.mono,
              secondary: true,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Space.lg.h),
            ButtonRow(
              alignment: ButtonRowAlignment.center,
              children: [
                AppButton(
                  label: l10n.refreshAction,
                  onPressed: onRefresh,
                  testKey: _refreshKey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
