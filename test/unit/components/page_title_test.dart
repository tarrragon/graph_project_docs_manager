/// SPEC-004 §4.11 `PageTitle` 測試點。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';

import '../../helpers/helpers.dart';

void main() {
  group('PageTitle', () {
    testWidgetsAtEachSize('有副標與無副標皆渲染，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: PageTitle(title: 'Domain 視圖', subtitle: '7 個 domain'),
          ),
        ),
      );
      expect(find.text('Domain 視圖'), findsOneWidget);
      expect(find.text('7 個 domain'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('無副標時只渲染一行標題，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: PageTitle(title: 'Ticket 清單'),
          ),
        ),
      );
      expect(find.text('Ticket 清單'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('最長測試文案兩 slot 皆截斷，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: PageTitle(
              title: TestCopy.longToken,
              subtitle: TestCopy.longEn,
            ),
          ),
        ),
      );
      expectNoOverflow(tester);
    });

    testWidgets('title 標記為 Semantics.header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: const PageTitle(title: 'Domain 視圖', subtitle: '副標'),
      );

      final titleNode = tester.getSemantics(find.text('Domain 視圖'));
      expect(
        titleNode.flagsCollection.isHeader,
        isTrue,
      );

      final subtitleNode = tester.getSemantics(find.text('副標'));
      expect(
        subtitleNode.flagsCollection.isHeader,
        isFalse,
      );

      handle.dispose();
    });
  });
}
