/// NoticeBanner 元件測試（SPEC-004 4.49）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/app_button.dart';
import 'package:graph_project_docs_manager/components/app_icon.dart';
import 'package:graph_project_docs_manager/components/notice_banner.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const bannerKey = ValueKey('panel-nodeDetail-edit-banner');
  const actionKey = ValueKey('action-nodeDetail-edit-reload');

  /// 主欄寬（4.50 交叉軸代入）。
  const mainColumnWidth = 476.0;

  AppButton actionButton(String label) => AppButton(
    label: label,
    variant: AppButtonVariant.secondary,
    onPressed: () {},
    testKey: actionKey,
  );

  Widget banner(
    NoticeBannerVariant variant,
    String message, {
    bool withAction = true,
    String actionLabel = 'reload',
    double? width,
  }) {
    final widget = NoticeBanner(
      variant: variant,
      message: message,
      action: withAction ? actionButton(actionLabel) : null,
      testKey: bannerKey,
    );
    return width == null
        ? widget
        : Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: widget),
          );
  }

  Container bannerContainer(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(bannerKey));

  group('兩變體 × 有／無動作鈕 × 三則編輯區訊息', () {
    for (final variant in NoticeBannerVariant.values) {
      for (final withAction in [true, false]) {
        testWidgetsAtEachSize(
          '${variant.name} withAction=$withAction 三則訊息（zh）不溢位',
          (tester, size) async {
            await pumpHarness(
              tester,
              size: size,
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final m in [
                          l10n.editBannerExternallyModifiedWarning,
                          l10n.editBannerExternallyModifiedBlocked,
                          l10n.editBannerReloadFailed,
                        ])
                          banner(
                            variant,
                            m,
                            withAction: withAction,
                            actionLabel: l10n.editDiscardAndReloadAction,
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
            expectNoOverflow(tester);
            expect(
              find.byKey(actionKey),
              withAction ? findsNWidgets(3) : findsNothing,
            );
          },
        );
      }
    }
  });

  group('變體外觀：底色、圖示形狀與顏色引用 token', () {
    testWidgets('warning 底 warningSurface、圖示 warning 色', (tester) async {
      await pumpHarness(
        tester,
        child: banner(NoticeBannerVariant.warning, 'm'),
      );
      final deco = bannerContainer(tester).decoration! as BoxDecoration;
      expect(deco.color, AppColors.warningSurface);
      expect(deco.borderRadius, BorderRadius.circular(Radius.md));
      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.color, AppColors.warning);
      expect(icon.size, IconSize.md);
      expect(icon.semanticLabel, isNull);
    });

    testWidgets('negative 底 errorSurface、圖示 error 色，且圖示形狀與 warning 不同', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: banner(NoticeBannerVariant.negative, 'm'),
      );
      final deco = bannerContainer(tester).decoration! as BoxDecoration;
      expect(deco.color, AppColors.errorSurface);
      final negativeIcon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(negativeIcon.color, AppColors.error);

      await pumpHarness(
        tester,
        child: banner(NoticeBannerVariant.warning, 'm'),
      );
      final warningIcon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(warningIcon.icon, isNot(negativeIcon.icon));
    });

    testWidgets('內距為 Space.sm', (tester) async {
      await pumpHarness(
        tester,
        child: banner(NoticeBannerVariant.warning, 'm'),
      );
      expect(bannerContainer(tester).padding, EdgeInsets.all(Space.sm));
    });
  });

  group('尺寸與內容政策', () {
    for (final variant in NoticeBannerVariant.values) {
      testWidgets('${variant.name}：主欄 476 寬長文案不溢位且訊息最多 4 行', (tester) async {
        await pumpHarness(
          tester,
          child: SingleChildScrollView(
            child: banner(variant, TestCopy.longZh * 4, width: mainColumnWidth),
          ),
        );
        expectNoOverflow(tester);
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(bannerKey),
            matching: find.text(TestCopy.longZh * 4),
          ),
        );
        expect(text.maxLines, 4);
        expect(text.overflow, TextOverflow.ellipsis);
      });

      testWidgets('${variant.name}：最小寬（圖示 + 一字元）不溢位', (tester) async {
        const minWidth = 2 * 8.0 + LayoutSize.iconMd + 8.0 + 16.0;
        await pumpHarness(
          tester,
          child: SingleChildScrollView(
            child: banner(variant, 'X', width: minWidth, withAction: false),
          ),
        );
        expectNoOverflow(tester);
      });
    }
  });

  group('無障礙：liveRegion 與焦點', () {
    testWidgets('訊息節點 liveRegion 為 true；動作鈕節點不帶 liveRegion', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: banner(NoticeBannerVariant.warning, 'banner-message-text'),
      );
      final msg = tester.getSemantics(find.text('banner-message-text'));
      expect(msg.flagsCollection.isLiveRegion, isTrue);
      final btn = tester.getSemantics(find.byKey(actionKey));
      SemanticsNode? n = btn;
      while (n != null) {
        expect(n.flagsCollection.isLiveRegion, isFalse);
        n = n.parent;
        if (n != null && n.id == msg.id) break;
      }
      handle.dispose();
    });

    testWidgets('出現時焦點所在節點不變', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      Widget host(bool show) => Column(
        children: [
          if (show) banner(NoticeBannerVariant.warning, 'm', withAction: false),
          Focus(focusNode: focus, child: const SizedBox(width: 10, height: 10)),
        ],
      );
      await pumpHarness(tester, child: host(false));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await pumpHarness(tester, child: host(true));
      expect(find.byKey(bannerKey), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, focus);
    });
  });
}
