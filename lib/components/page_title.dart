/// SPEC-004 §4.11 `PageTitle`：頁首左側元件，畫面名 + 可選一行副標。
///
/// 契約來源：`docs/spec/ui/SPEC-004-component-library.md` §4.11。文字經
/// `AppText` 語意角色渲染（`subtitle` 承載畫面名、`body` + `secondary`
/// 承載副標）。`AppText`（4.1）由並行票實作，尚未併入本分支；本檔以
/// 4.1 契約的公開介面為準，內部以最小相容的私有 `_PageTitleText` 頂替，
/// 待該並行票併入後改為直接引用 `AppText`。
library;

import 'package:flutter/widgets.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// 頁首左側：畫面名（必填）+ 一行副標（可選）。
///
/// 依 §4.11 尺寸契約，本元件填滿父格位寬（置於 `SplitRow.header` 左格），
/// 高固有；兩個文字 slot 皆單行截斷，不換行。
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});

  /// 畫面名。呼叫端傳入既有 `nav*` i18n key 取值。
  final String title;

  /// 副標（模式說明或選中摘要）。為 `null` 時只渲染一行。
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTitleText(
          text: title,
          fontSize: AppFontSize.subtitle,
          color: AppColors.textTitle,
          isHeader: true,
        ),
        if (subtitleText != null) ...[
          SizedBox(height: Space.xxs),
          _PageTitleText(
            text: subtitleText,
            fontSize: AppFontSize.body,
            color: AppColors.textSecondary,
            isHeader: false,
          ),
        ],
      ],
    );
  }
}

/// 最小相容的私有文字實作，行為對齊 SPEC-004 §4.1 `AppText` 的
/// `subtitle` / `body`（`secondary`）變體：單行、截斷、`title`/`subtitle`
/// 標記為 `Semantics.header`。待並行票併入後由 `AppText` 取代。
class _PageTitleText extends StatelessWidget {
  const _PageTitleText({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.isHeader,
  });

  final String text;
  final double fontSize;
  final Color color;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: isHeader,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
    );
  }
}
