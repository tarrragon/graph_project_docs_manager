/// SPEC-004 §4.11 `PageTitle`：頁首左側元件，畫面名 + 可選一行副標。
///
/// 契約來源：`docs/spec/ui/SPEC-004-component-library.md` §4.11。文字經
/// `AppText`（§4.1）語意角色渲染：畫面名經 `AppText.subtitle`，副標經
/// `AppText.body`（`secondary`，`maxLines: 1`）。
library;

import 'package:flutter/widgets.dart';

import 'app_text.dart';
import '../tokens/spacing.dart';

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
        AppText(title, variant: AppTextVariant.subtitle),
        if (subtitleText != null) ...[
          SizedBox(height: Space.xxs),
          AppText(
            subtitleText,
            variant: AppTextVariant.body,
            secondary: true,
            maxLines: 1,
          ),
        ],
      ],
    );
  }
}
