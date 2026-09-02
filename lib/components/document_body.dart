/// 文件內文（SPEC-004 4.20）。
///
/// 節點詳情主欄的 markdown 渲染內容，由 `flutter_markdown_plus` 承載。
/// 渲染器內部輸出的原生 `Text` / `RichText` / `Table` 等 widget 依
/// SPEC-004 §7 第 7 項豁免（第三方渲染器輸出樹結構性無法改為元件庫元件），
/// 樣式全部經 [MarkdownStyleSheet] 映射 token（本檔唯一樣式定義處）。
/// 連結不接 `onTapLink`，依契約渲染為一般文字（SPEC-003 FR-06 合法形態 a）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../tokens/tokens.dart';

/// 文件內文。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [markdown] | 是 | 呼叫端傳入的檔案內容（字串） |
/// | [testKey] | 是 | 呼叫端定址 key |
///
/// 尺寸模式為填滿寬、高固有（`shrinkWrap: true`），捲動由所在容器
/// （`Panel.scrollable`）承載，本元件不建立自身捲動容器。
class DocumentBody extends StatelessWidget {
  const DocumentBody({
    super.key,
    required this.markdown,
    required this.testKey,
  });

  /// markdown 原文，來源為呼叫端讀取的檔案內容，不經 i18n。
  final String markdown;

  /// 呼叫端定址 key。
  final Key testKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: testKey,
      padding: EdgeInsets.all(Space.xs),
      child: MarkdownBody(
        data: markdown,
        selectable: false,
        styleSheet: _buildStyleSheet(context),
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final monoFamily = DefaultTextStyle.of(context).style.fontFamily;
    final body = TextStyle(
      fontSize: AppFontSize.body,
      color: AppColors.textPrimary,
    );
    final heading = TextStyle(
      fontSize: AppFontSize.subtitle,
      fontWeight: FontWeight.w600,
      color: AppColors.textTitle,
    );
    final code = TextStyle(
      fontSize: AppFontSize.body,
      fontFamily: monoFamily,
      color: AppColors.textPrimary,
    );
    final chipDecoration = BoxDecoration(
      color: AppColors.surfaceChip,
      borderRadius: BorderRadius.circular(Radius.md),
    );

    return MarkdownStyleSheet(
      p: body,
      listBullet: body,
      a: body,
      code: code,
      h1: TextStyle(
        fontSize: AppFontSize.title,
        fontWeight: FontWeight.bold,
        color: AppColors.textTitle,
      ),
      h2: heading,
      h3: heading,
      h4: heading,
      h5: heading,
      h6: heading,
      em: body.copyWith(fontStyle: FontStyle.italic),
      strong: body.copyWith(fontWeight: FontWeight.bold),
      blockquote: body,
      blockSpacing: Space.sm,
      blockquotePadding: EdgeInsets.all(Space.md),
      blockquoteDecoration: chipDecoration,
      codeblockPadding: EdgeInsets.all(Space.md),
      codeblockDecoration: chipDecoration,
      tableHead: body.copyWith(fontWeight: FontWeight.w600),
      tableBody: body,
      tableBorder: TableBorder.all(color: AppColors.border),
      tableCellsPadding: EdgeInsets.all(Space.sm),
      tablePadding: EdgeInsets.zero,
    );
  }
}
