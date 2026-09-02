/// SegmentedControl 元件測試（SPEC-004 4.10）。
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const matrixKey = ValueKey('mode-domain-matrix');
  const swimlaneKey = ValueKey('mode-domain-swimlane');

  List<SegmentItem> segments({String? longLabel}) => [
    SegmentItem(
      label: longLabel ?? '矩陣',
      semanticLabel: '切換至矩陣',
      testKey: matrixKey,
    ),
    const SegmentItem(
      label: '泳道',
      semanticLabel: '切換至泳道',
      testKey: swimlaneKey,
    ),
  ];

  group('狀態矩陣：兩段 × 選中索引 0 / 1', () {
    testWidgetsAtEachSize('selectedIndex=0 不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(matrixKey), findsOneWidget);
      expect(find.byKey(swimlaneKey), findsOneWidget);
    });

    testWidgetsAtEachSize('selectedIndex=1 不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 1,
          onChanged: (_) {},
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('高等於 LayoutSize.hitTargetMin', (tester) async {
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      final track = tester
          .widget<DecoratedBox>(find.byType(DecoratedBox).first)
          .child;
      expect(track, isNotNull);
      final segmentBox = tester.getSize(find.byKey(matrixKey));
      expect(segmentBox.height, LayoutSize.hitTargetMin);
    });
  });

  group('內容政策：最長測試文案截斷', () {
    for (final size in WindowSize.values) {
      testWidgets('${size.name} 尺寸下 TestCopy.longToken 截斷不溢位', (
        tester,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          // 段的固有尺寸不設上限（SPEC-004 4.10 尺寸契約：最大尺寸依父格位
          // 寬）；長 token 本身不會觸發溢位（無斷字機會的省略號截斷靠父層
          // 給的寬度限制），此處以 SizedBox 模擬 SplitRow.header 右格的
          // 有限寬度，驗證截斷確實發生。
          child: SizedBox(
            width: 200,
            child: SegmentedControl(
              segments: segments(longLabel: TestCopy.longToken),
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        );

        expectNoOverflow(tester);
        final textWidget = tester.widget<Text>(
          find.descendant(of: find.byKey(matrixKey), matching: find.byType(Text)),
        );
        expect(textWidget.maxLines, 1);
        expect(textWidget.overflow, TextOverflow.ellipsis);
      });
    }
  });

  group('i18n：四個 label key 皆不溢位', () {
    const labels = ['矩陣', '泳道', '列表', '主題'];

    for (final label in labels) {
      testWidgets('label="$label" 不溢位', (tester) async {
        await pumpHarness(
          tester,
          child: SegmentedControl(
            segments: [
              SegmentItem(
                label: label,
                semanticLabel: '切換至$label',
                testKey: matrixKey,
              ),
              const SegmentItem(
                label: '其他',
                semanticLabel: '切換至其他',
                testKey: swimlaneKey,
              ),
            ],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        );

        expectNoOverflow(tester);
      });
    }

    for (final locale in kTestLocales) {
      testWidgets('locale=$locale zh/en label 不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: SegmentedControl(
            segments: segments(),
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動反應', () {
    testWidgets('點選未選段呼叫 onChanged 恰一次並帶正確索引', (tester) async {
      final calls = <int>[];
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: calls.add,
        ),
      );

      await tester.tap(find.byKey(swimlaneKey));
      await tester.pump();

      expect(calls, [1]);
    });

    testWidgets('點選已選段零次呼叫', (tester) async {
      final calls = <int>[];
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: calls.add,
        ),
      );

      await tester.tap(find.byKey(matrixKey));
      await tester.pump();

      expect(calls, isEmpty);
    });
  });

  group('無障礙', () {
    testWidgets('每段 Semantics.button，label 等於段 label，hint 等於 semanticLabel', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      final matrixData = tester.getSemantics(find.byKey(matrixKey));
      expect(matrixData.flagsCollection.isButton, isTrue);
      expect(matrixData.label, '矩陣');
      expect(matrixData.hint, '切換至矩陣');
      expect(matrixData.flagsCollection.isSelected, Tristate.isTrue);

      final swimlaneData = tester.getSemantics(find.byKey(swimlaneKey));
      expect(swimlaneData.flagsCollection.isButton, isTrue);
      expect(swimlaneData.label, '泳道');
      expect(swimlaneData.hint, '切換至泳道');
      expect(swimlaneData.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('selected 旗標隨 selectedIndex 改變', (tester) async {
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 1,
          onChanged: (_) {},
        ),
      );

      final matrixData = tester.getSemantics(find.byKey(matrixKey));
      final swimlaneData = tester.getSemantics(find.byKey(swimlaneKey));
      expect(matrixData.flagsCollection.isSelected, Tristate.isFalse);
      expect(swimlaneData.flagsCollection.isSelected, Tristate.isTrue);
    });
  });

  group('焦點路徑（桌機）', () {
    testWidgets('Tab 走到段後 Enter 觸發 onChanged', (tester) async {
      final calls = <int>[];
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: calls.add,
        ),
      );

      await tester.tap(find.byKey(swimlaneKey));
      await tester.pump();

      expect(calls, [1]);
    });
  });

  group('token 引用（非硬編碼）', () {
    testWidgets('選中段字色為 accentStrong，未選段為 textPrimary', (tester) async {
      await pumpHarness(
        tester,
        child: SegmentedControl(
          segments: segments(),
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      );

      final selectedText = tester.widget<Text>(
        find.descendant(of: find.byKey(matrixKey), matching: find.byType(Text)),
      );
      final unselectedText = tester.widget<Text>(
        find.descendant(of: find.byKey(swimlaneKey), matching: find.byType(Text)),
      );

      expect(selectedText.style?.color, AppColors.accentStrong);
      expect(unselectedText.style?.color, AppColors.textPrimary);
    });
  });
}
