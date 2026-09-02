// SPEC-004 §4.3 Divider 測試點。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  group('單一狀態渲染', () {
    testWidgetsAtEachSize('寬等於父寬、高等於線寬', (tester, windowSize) async {
      await pumpHarness(
        tester,
        size: windowSize,
        child: const SizedBox(width: 300, child: Divider()),
      );
      expectNoOverflow(tester);

      final size = tester.getSize(find.byType(Divider));
      expect(size.width, 300);
      expect(size.height, 1);
    });
  });

  group('顏色 token', () {
    testWidgets('引用 AppColors.border 非硬編碼', (tester) async {
      await pumpHarness(
        tester,
        child: const SizedBox(width: 300, child: Divider()),
      );
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.border!.bottom.color, AppColors.border);
    });
  });

  group('無障礙', () {
    testWidgets('語意樹無節點（裝飾性）', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: const SizedBox(width: 300, child: Divider()),
      );
      expect(
        find.descendant(
          of: find.byType(Divider),
          matching: find.bySemanticsLabel(RegExp('.*')),
        ),
        findsNothing,
      );
      handle.dispose();
    });
  });
}
