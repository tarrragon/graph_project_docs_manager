/// [MatrixCell] widget test（SPEC-004 §4.15「測試點」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _directKey = ValueKey('cell-domain-ui-uc01');
const _indirectKey = ValueKey('cell-domain-ui-uc02');
const _noneKey = ValueKey('cell-domain-ui-uc03');

MatrixCell _cell({
  Relation relation = Relation.direct,
  bool isSelected = false,
  bool isRowSelected = false,
  String semanticLabel = 'ui × UC-01：直接貫穿',
  Key testKey = _directKey,
  VoidCallback? onTap,
}) {
  return MatrixCell(
    relation: relation,
    isSelected: isSelected,
    isRowSelected: isRowSelected,
    semanticLabel: semanticLabel,
    onTap: onTap ?? () {},
    testKey: testKey,
  );
}

Widget _sized(Widget child) =>
    SizedBox(width: LayoutSize.matrixColumnWidth, child: child);

void main() {
  group('三變體 × 三狀態 不溢位', () {
    for (final size in WindowSize.values) {
      for (final relation in Relation.values) {
        for (final isSelected in [false, true]) {
          for (final isRowSelected in [false, true]) {
            testWidgets(
              '$relation selected=$isSelected rowSelected=$isRowSelected @ '
              '${size.label} 不溢位',
              (tester) async {
                await pumpHarness(
                  tester,
                  size: size,
                  child: _sized(
                    _cell(
                      relation: relation,
                      isSelected: isSelected,
                      isRowSelected: isRowSelected,
                    ),
                  ),
                );

                expectNoOverflow(tester);
              },
            );
          }
        }
      }
    }
  });

  group('命中區', () {
    testWidgets('命中區不小於 hitTargetMin', (tester) async {
      await pumpHarness(tester, child: _sized(_cell()));

      final size = tester.getSize(find.byKey(_directKey));
      expect(size.width, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
      expect(size.height, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
    });
  });

  group('點選行為', () {
    testWidgets('未選格點選呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: _sized(_cell(onTap: () => callCount++)),
      );

      await tester.tap(find.byKey(_directKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('已選格再點零次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: _sized(
          _cell(isSelected: true, onTap: () => callCount++),
        ),
      );

      await tester.tap(find.byKey(_directKey), warnIfMissed: false);
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('Semantics.selected 與 isSelected 一致', (tester) async {
      await pumpHarness(tester, child: _sized(_cell(isSelected: true)));

      final semantics = tester.getSemantics(find.byKey(_directKey));
      expect(semantics.flagsCollection.isSelected.toString(), contains('True'));
    });

    testWidgets('未選格 Semantics.selected 為 false', (tester) async {
      await pumpHarness(tester, child: _sized(_cell()));

      final semantics = tester.getSemantics(find.byKey(_directKey));
      expect(
        semantics.flagsCollection.isSelected.toString(),
        contains('False'),
      );
    });
  });

  group('selected 與 rowSelected 可區辨', () {
    testWidgets('selected 底色為 accent，rowSelected 底色為 surfaceIconTint', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: Row(
          children: [
            _sized(_cell(testKey: _indirectKey, isSelected: true)),
            _sized(
              _cell(testKey: _noneKey, isRowSelected: true, relation: Relation.none),
            ),
          ],
        ),
      );

      final selectedContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(_indirectKey),
              matching: find.byType(Container),
            )
            .first,
      );
      final rowSelectedContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(_noneKey),
              matching: find.byType(Container),
            )
            .first,
      );

      final selectedColor =
          (selectedContainer.decoration! as BoxDecoration).color;
      final rowSelectedColor =
          (rowSelectedContainer.decoration! as BoxDecoration).color;

      expect(selectedColor, AppColors.accent);
      expect(rowSelectedColor, AppColors.surfaceIconTint);
      expect(selectedColor, isNot(rowSelectedColor));
    });
  });

  group('三變體符號與 token 顏色', () {
    testWidgets('direct 符號為 ●，色 accent', (tester) async {
      await pumpHarness(
        tester,
        child: _sized(_cell(relation: Relation.direct)),
      );

      final text = tester.widget<Text>(
        find.descendant(of: find.byKey(_directKey), matching: find.byType(Text)),
      );
      expect(text.data, '●');
      expect(text.style!.color, AppColors.accent);
    });

    testWidgets('indirect 符號為 ○，色 textSecondary', (tester) async {
      await pumpHarness(
        tester,
        child: _sized(_cell(testKey: _indirectKey, relation: Relation.indirect)),
      );

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(_indirectKey),
          matching: find.byType(Text),
        ),
      );
      expect(text.data, '○');
      expect(text.style!.color, AppColors.textSecondary);
    });

    testWidgets('none 符號為 ·，色 borderStrong', (tester) async {
      await pumpHarness(
        tester,
        child: _sized(_cell(testKey: _noneKey, relation: Relation.none)),
      );

      final text = tester.widget<Text>(
        find.descendant(of: find.byKey(_noneKey), matching: find.byType(Text)),
      );
      expect(text.data, '·');
      expect(text.style!.color, AppColors.borderStrong);
    });

    testWidgets('selected 態符號色改為 surfaceBase（成對設計）', (tester) async {
      await pumpHarness(
        tester,
        child: _sized(_cell(isSelected: true)),
      );

      final text = tester.widget<Text>(
        find.descendant(of: find.byKey(_directKey), matching: find.byType(Text)),
      );
      expect(text.style!.color, AppColors.surfaceBase);
    });
  });
}
