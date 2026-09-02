// 契約測試：lib/tokens/layout.dart 的語意名回溯原始值（0.1.0-W1-047）。
//
// 涵蓋範圍：
// 1. 每個語意名的值可回溯 0.1.0-W1-044.1 NeedsContext 第 1 項的實測原始值。
// 2. 列高歸併（rowHeightDense / rowHeightRelaxed）的中位數計算與 dartdoc
//    記錄的歸併映射一致。
// 3. 右欄寬收斂（detailPaneWidth）確實收斂為單一值，不再是兩個並存的值。
//
// 「lib/ 下（tokens/ 除外）grep 不到新增的裸尺寸值」一項以 Bash 手動驗證
// （見本票 Test Results），不寫成永久單元測試：候選值多為通用小整數
// （如 13、15、17、46、52），隨 lib/ 成長極可能被無關程式碼合法使用
// （索引、清單長度等），寫成全域掃描斷言會對未來無關改動產生偽陽性。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/tokens/layout.dart';

void main() {
  group('LayoutSize 原始值回溯（單一原始值項目）', () {
    test('sidebarWidth 回溯側欄寬實測值 172', () {
      expect(LayoutSize.sidebarWidth, 172);
    });

    test('headerHeight 回溯頁首高實測值 52', () {
      expect(LayoutSize.headerHeight, 52);
    });

    test('overlayWidth 回溯專案切換浮層寬實測值 262', () {
      expect(LayoutSize.overlayWidth, 262);
    });

    test('matrixLeadColumnWidth 回溯矩陣首欄寬實測值 132', () {
      expect(LayoutSize.matrixLeadColumnWidth, 132);
    });

    test('matrixSubtotalWidth 回溯矩陣小計欄寬實測值 46', () {
      expect(LayoutSize.matrixSubtotalWidth, 46);
    });

    test('laneLabelWidth 回溯泳道名欄寬實測值 106', () {
      expect(LayoutSize.laneLabelWidth, 106);
    });

    test('laneRowHeight 回溯泳道列高實測值 52（與 headerHeight 各自獨立量測同值）', () {
      expect(LayoutSize.laneRowHeight, 52);
      expect(
        LayoutSize.laneRowHeight,
        LayoutSize.headerHeight,
        reason: '兩者恰好同值但語意不同，非共用來源',
      );
    });

    test('iconSm/iconMd/iconLg 回溯圖示尺寸三階實測值 13/15/17', () {
      expect(LayoutSize.iconSm, 13);
      expect(LayoutSize.iconMd, 15);
      expect(LayoutSize.iconLg, 17);
    });
  });

  group('表格列高歸併（rowHeightDense / rowHeightRelaxed）', () {
    test('rowHeightDense 為結構性列三值（28、29、31）的中位數', () {
      const structuralRowHeights = [28, 29, 31];
      final median = structuralRowHeights[structuralRowHeights.length ~/ 2];
      expect(LayoutSize.rowHeightDense, median.toDouble());
      expect(LayoutSize.rowHeightDense, 29);
    });

    test('rowHeightRelaxed 為扁平內容列三值（32、34、36）的中位數', () {
      const flatRowHeights = [32, 34, 36];
      final median = flatRowHeights[flatRowHeights.length ~/ 2];
      expect(LayoutSize.rowHeightRelaxed, median.toDouble());
      expect(LayoutSize.rowHeightRelaxed, 34);
    });

    test('兩階不重疊且順序正確：dense < relaxed', () {
      expect(LayoutSize.rowHeightDense, lessThan(LayoutSize.rowHeightRelaxed));
    });
  });

  group('右欄寬收斂（detailPaneWidth）', () {
    test('收斂為矩陣格詳情卡與節點詳情右欄中較寬的單一值 236', () {
      const matrixDetailCardWidth = 236;
      const nodeDetailPaneWidth = 216;
      final converged = matrixDetailCardWidth > nodeDetailPaneWidth
          ? matrixDetailCardWidth
          : nodeDetailPaneWidth;

      expect(LayoutSize.detailPaneWidth, converged.toDouble());
      expect(LayoutSize.detailPaneWidth, 236);
    });

    test('不再以兩個並存的值表示右欄寬（單一常數即為唯一契約值）', () {
      // detailPaneWidth 是單一 double 常數，型別本身即保證收斂為一值；
      // 此測試另行斷言其不等於未收斂前的較窄值，避免日後誤改回兩值並存。
      expect(LayoutSize.detailPaneWidth, isNot(216));
    });
  });

  group('最小命中區（hitTargetMin）', () {
    test('hitTargetMin 回溯桌機指標形態實測範圍 25～31px，取 macOS 慣例值 28', () {
      expect(LayoutSize.hitTargetMin, 28);
      const measuredMin = 25; // 頁首檢視切換分頁
      const measuredMax = 31; // 側欄導覽項
      expect(LayoutSize.hitTargetMin, greaterThanOrEqualTo(measuredMin));
      expect(LayoutSize.hitTargetMin, lessThanOrEqualTo(measuredMax));
    });
  });

  group('LayoutSize 原始值回溯（SPEC-004 第 4 章缺漏 token 補齊）', () {
    test('titleBarHeight 回溯九份 artboard 頂端標題列一致實測值 36', () {
      expect(LayoutSize.titleBarHeight, 36);
    });

    test('ticket 欄組回溯 TicketListA grid-template-columns 132/84/40/22', () {
      expect(LayoutSize.ticketIdColumnWidth, 132);
      expect(LayoutSize.ticketStatusColumnWidth, 84);
      expect(LayoutSize.ticketPriorityColumnWidth, 40);
      expect(LayoutSize.ticketMarkerColumnWidth, 22);
    });

    test('ticketIdColumnWidth 與 matrixLeadColumnWidth 恰好同值但語意不同', () {
      expect(
        LayoutSize.ticketIdColumnWidth,
        LayoutSize.matrixLeadColumnWidth,
        reason: '兩者恰好同值但各自獨立量測，非共用來源',
      );
    });

    test('step 欄組回溯 UCFlowB grid-template-columns 固定寬欄 26/118', () {
      expect(LayoutSize.stepNumberColumnWidth, 26);
      expect(LayoutSize.stepDomainColumnWidth, 118);
    });

    test('treeIndent 回溯 TraceA 四層 padding-left 等差值 24', () {
      const depths = [0, 24, 48, 72];
      for (var i = 1; i < depths.length; i++) {
        expect(depths[i] - depths[i - 1], LayoutSize.treeIndent);
      }
      expect(LayoutSize.treeIndent, 24);
    });
  });

  group('StepNumber 尺寸收斂（stepNumberSize）', () {
    test('收斂採 UCFlowB 圓形值 24，非 Main 方形值 16', () {
      const squareValue = 16; // Main 詳情卡步驟清單，border-radius:4px（方形）
      const circleValue = 24; // UCFlowB 步驟流，border-radius:12px（圓形，半徑=直徑/2）
      expect(LayoutSize.stepNumberSize, isNot(squareValue));
      expect(LayoutSize.stepNumberSize, circleValue);
    });
  });

  group('MatrixGrid UC 欄寬定案（matrixColumnWidth，待 PM 核定）', () {
    test('由 Main 版面尺寸鏈推算出 5 UC 欄合計並等分為 122', () {
      const artboardWidth = 1280;
      const sidebarWidth = 172;
      const contentPadding = 20;
      const detailPaneWidth = 236;
      const panelGap = 14;
      const panelPadding = 14;
      const panelBorder = 1;
      const ucColumnCount = 5;

      final dualColumnWidth =
          artboardWidth - sidebarWidth - contentPadding * 2;
      final matrixPanelWidth =
          dualColumnWidth - detailPaneWidth - panelGap;
      final gridContentWidth =
          matrixPanelWidth - panelPadding * 2 - panelBorder * 2;
      final ucColumnsTotal = gridContentWidth -
          LayoutSize.matrixLeadColumnWidth -
          LayoutSize.matrixSubtotalWidth;
      final perColumn = ucColumnsTotal / ucColumnCount;

      expect(perColumn, LayoutSize.matrixColumnWidth);
      expect(LayoutSize.matrixColumnWidth, 122);
    });
  });
}
