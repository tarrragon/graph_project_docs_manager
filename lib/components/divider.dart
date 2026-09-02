/// 分隔線（SPEC-004 §4.3）。
///
/// 純顯示原子元件，無變體、無 slot、無互動。區隔垂直堆疊中的群組
/// （例如節點詳情主欄標籤列與內文之間）。**不用於**分節之間（`Section`
/// 節間距承載）、表格列之間（`TableRow` 底邊框承載）、側欄與主區之間
/// （`AppShell` 內部）。
library;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// 水平分隔線（SPEC-004 §4.3）。
///
/// 寬填滿父容器，高為邊框線寬（Flutter 預設 1 邏輯像素，SPEC-004 §4.0.3）。
/// 裝飾性元素，排除於語意樹（[ExcludeSemantics]）。
class Divider extends StatelessWidget {
  const Divider({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
        ),
      ),
    );
  }
}
