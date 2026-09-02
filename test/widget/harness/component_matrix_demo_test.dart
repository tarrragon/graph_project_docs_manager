// 基座示範：元件票的「兩種尺寸 × 全變體 × 兩語系 × 最長文案」寫法
// （SPEC-004 §4.0.5），以及以真實 App 起導覽殼的寫法。
//
// 元件庫尚未落地，變體以最小替身（單行 / 多行兩種文字處置）代替；
// 各元件票把 `_variants` 換成該元件的變體列舉、`_build` 換成該元件即可。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/shell.dart';

import '../../helpers/helpers.dart';

enum _Variant { singleLine, multiLine }

/// 置於寬度受限的父格位（SPEC-004 §4.1 測試點第二項的寫法）。
Widget _build(_Variant variant, String copy) {
  return SizedBox(
    width: 200,
    child: switch (variant) {
      _Variant.singleLine => Text(
          copy,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      _Variant.multiLine => Text(copy, softWrap: true),
    },
  );
}

void main() {
  group('全變體 × 兩語系 × 最長文案 × 兩尺寸', () {
    for (final variant in _Variant.values) {
      for (final locale in kTestLocales) {
        for (final copy in TestCopy.longCopies) {
          testWidgetsAtEachSize(
            '${variant.name} / ${locale.languageCode} / ${copy.substring(0, 8)}…',
            (tester, size) async {
              await pumpHarness(
                tester,
                child: _build(variant, copy),
                size: size,
                locale: locale,
              );
              expectNoOverflow(tester);
              expect(find.text(copy), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('減少動態效果', () {
    testWidgets('disableAnimations 透過 MediaQuery 抵達元件', (tester) async {
      late bool observed;
      await pumpHarness(
        tester,
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            observed = MediaQuery.disableAnimationsOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(observed, isTrue);
    });
  });

  group('真實 App 導覽殼', () {
    testWidgetsAtEachSize('pumpApp 起 AppShell 不溢位', (tester, size) async {
      await pumpApp(tester, size: size);
      expect(find.byKey(AppShell.shellKey), findsOneWidget);
      expect(AnchorFinder.projectSwitcherEntry, findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
