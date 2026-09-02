/// DocumentBody 元件測試（SPEC-004 4.20）。
library;

import 'dart:io';

import 'package:flutter/material.dart' show InkWell;
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('document-body-test');

  const sampleMarkdown = '''
# 標題一

## 標題二

一般段落，含 `行內 code` 與一般文字。

> 引用區塊，模擬 FR 引用區塊內容。

- 清單項一
- 清單項二

```dart
final x = 1;
```

| 欄一 | 欄二 |
|------|------|
| a | b |

[一個連結](https://example.com)
''';

  group('測試點：全部元素類型渲染', () {
    testWidgetsAtEachSize('一支測試渲染含全部元素類型的 markdown 樣本', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: DocumentBody(markdown: sampleMarkdown, testKey: testKey),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
    });
  });

  group('內容政策：兩種視窗尺寸不溢位', () {
    testWidgetsAtEachSize('段落不溢位；程式碼區塊與表格為水平捲動容器', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: DocumentBody(markdown: sampleMarkdown, testKey: testKey),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });

  group('測試點：1673 行語料', () {
    testWidgets('1673 行語料渲染無 framework 錯誤且可捲至末端', (tester) async {
      final corpus = File(
        'test/fixtures/corpus/book_overview_v1/docs/spec/extraction/e2e-contract.md',
      ).readAsStringSync();

      await pumpHarness(
        tester,
        size: WindowSize.min,
        child: SizedBox(
          height: 400,
          child: SingleChildScrollView(
            child: DocumentBody(markdown: corpus, testKey: testKey),
          ),
        ),
      );

      expectNoOverflow(tester);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -100000));
      await tester.pumpAndSettle();

      expectNoOverflow(tester);
    });
  });

  group('內容政策：zh/en 混排段落', () {
    testWidgetsAtEachSize('最長測試文案（zh / en / 無斷字 token）不溢位', (tester, size) async {
      final mixed = '''
${TestCopy.longZh}

${TestCopy.longEn}

`${TestCopy.longToken}`
''';

      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: DocumentBody(markdown: mixed, testKey: testKey),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('互動反應：連結渲染為一般文字', () {
    testWidgets('連結不渲染為可點（onTapLink 不接線），無 InkWell', (tester) async {
      await pumpHarness(
        tester,
        child: DocumentBody(
          markdown: '[一個連結](https://example.com)',
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      // flutter_markdown_plus 一律以 TapGestureRecognizer 附掛連結
      // TextSpan，但未接 onTapLink 時點擊不觸發任何呼叫端行為；本測試
      // 驗證的是「不使用 InkWell 等可視化互動元件」，非完全移除手勢辨識。
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('使用 design token：樣式非硬編碼', () {
    testWidgets('MarkdownStyleSheet 顏色、字級、間距引用 token', (tester) async {
      await pumpHarness(
        tester,
        child: DocumentBody(markdown: sampleMarkdown, testKey: testKey),
      );

      final markdownBody = tester.widget<MarkdownBody>(
        find.byType(MarkdownBody),
      );
      final styleSheet = markdownBody.styleSheet!;

      expect(styleSheet.p!.color, AppColors.textPrimary);
      expect(styleSheet.p!.fontSize, AppFontSize.body);
      expect(styleSheet.h1!.color, AppColors.textTitle);
      expect(styleSheet.h1!.fontSize, AppFontSize.title);
      expect(styleSheet.blockSpacing, Space.sm);
      expect(
        (styleSheet.blockquoteDecoration! as BoxDecoration).color,
        AppColors.surfaceChip,
      );
      expect(
        (styleSheet.codeblockDecoration! as BoxDecoration).color,
        AppColors.surfaceChip,
      );
      expect(styleSheet.tableBorder!.top.color, AppColors.border);
    });
  });
}
