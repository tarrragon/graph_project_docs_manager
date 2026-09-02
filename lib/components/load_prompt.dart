/// LoadPrompt（SPEC-004 §4.25）。
///
/// 「載入 N 張 ticket」提示 + 開始載入動作，未載入態（SPEC-001 §4）唯一
/// 承載元件。單一變體；不顯示預估耗時（SPEC-003 §2.6 誠實性硬規則、
/// FR-07）；返回動作由頁面框架承載（SPEC-003 §2.4），不在本元件範圍。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'button_row.dart';

/// SPEC-004 §4.25：未載入態的「載入 N 張 ticket」提示 + 開始載入。
///
/// 填滿父容器（寬與高），內容置中（[Center] 在有界約束下的原生行為即
/// 落成此契約，無界時退化為內容本身大小）。
class LoadPrompt extends StatelessWidget {
  const LoadPrompt({
    super.key,
    required this.count,
    required this.onStart,
    required this.testKey,
    required this.startKey,
    this.message,
  });

  /// 待載入 ticket 數量，代入預設訊息 key（`ticketsLoadPrompt`）。
  final int count;

  /// 「開始載入」按下時呼叫恰一次的回呼。
  final VoidCallback onStart;

  /// 狀態根節點測試錨點（`state-tickets-unloaded`，SPEC-004 slot 契約）。
  final Key testKey;

  /// 開始載入按鈕測試錨點（`action-tickets-start-load`，SPEC-004 slot 契約）。
  final Key startKey;

  /// 覆蓋預設訊息文字；不傳則取 `ticketsLoadPrompt(count)`（SPEC-004 slot 契約）。
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedMessage = message ?? l10n.ticketsLoadPrompt(count);

    return Center(
      key: testKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 進入本狀態時訊息以 liveRegion 播報一次（SPEC-004 無障礙子節）。
          Semantics(
            liveRegion: true,
            child: AppText(
              resolvedMessage,
              variant: AppTextVariant.subtitle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: Space.lg.h),
          ButtonRow(
            alignment: ButtonRowAlignment.center,
            children: [
              AppButton(
                testKey: startKey,
                label: l10n.startLoadAction,
                onPressed: onStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
