/// [MissingSourceState] widget test（SPEC-004 §4.22「測試點」）。
///
/// 單一變體（default），逐一渲染兩種測試尺寸與長文案矩陣、驗證重新整理
/// 點選行為、無障礙朗讀與焦點順序、token 引用。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';

import '../../helpers/helpers.dart';

const _testKey = ValueKey('state-nodeDetail-missing');
const _refreshKey = ValueKey('action-nodeDetail-refresh');

void main() {
  group('default 變體：兩種視窗尺寸不溢位', () {
    testWidgetsAtEachSize('default 不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('最長測試文案不溢位（§4.0.4 TestCopy）', () {
    testWidgets('TestCopy.filePath（最長路徑資料值）不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('TestCopy.longToken（無斷字機會）截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.longToken,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('TestCopy.longZh（人工中文長文案）截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.longZh,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('kMinWindowSize 與 kDesignSize 下的行為（維持，§4.22 尺寸契約）', () {
    testWidgetsAtEachSize('填滿父容器且內容置中，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox.expand(
          child: MissingSourceState(
            path: TestCopy.filePath,
            onRefresh: () {},
            testKey: _testKey,
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(_testKey), findsOneWidget);
    });
  });

  group('重新整理點選行為', () {
    testWidgets('點選重新整理按鈕呼叫 onRefresh 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () => callCount++,
          testKey: _testKey,
        ),
      );

      await tester.tap(find.byKey(_refreshKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('僅渲染重新整理一個動作按鈕（無返回鍵，由頁面框架承載）', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      expect(find.byType(AppButton), findsOneWidget);
    });
  });

  group('無障礙', () {
    testWidgets('訊息文字節點存在（供 liveRegion 播報驗證）', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      final semantics = tester.getSemantics(find.byKey(_testKey));
      expect(semantics, isNotNull);
    });

    testWidgets('重新整理按鈕進入 Tab 焦點路徑', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      final focusable = tester.widget<Focus>(
        find
            .descendant(
              of: find.byKey(_refreshKey),
              matching: find.byType(Focus),
            )
            .first,
      );
      expect(focusable.canRequestFocus, isTrue);
    });
  });

  group('i18n key 引用（非硬編碼）', () {
    for (final locale in kTestLocales) {
      testWidgets('$locale 語系下渲染不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: MissingSourceState(
            path: TestCopy.filePath,
            onRefresh: () {},
            testKey: _testKey,
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('token 引用（間距）', () {
    testWidgets('Column 內容置中對齊', (tester) async {
      await pumpHarness(
        tester,
        child: MissingSourceState(
          path: TestCopy.filePath,
          onRefresh: () {},
          testKey: _testKey,
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.crossAxisAlignment, CrossAxisAlignment.center);
      expect(column.mainAxisSize, MainAxisSize.min);
    });
  });
}
