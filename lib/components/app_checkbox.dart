/// AppCheckbox（SPEC-004 §4.43）。
///
/// 單一布林設定的常駐切換：核取框 + 單行 label，核取框與 label 共用一個
/// 命中區與一個 Tab 停留點，點擊呼叫 `onChanged(!value)` 恰一次。內部以
/// Material `Checkbox` 實作，頁面層禁直用 `Checkbox`（SPEC-004 §6）。
library;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// 核取切換元件（SPEC-004 §4.43，單一變體 `default`）。
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.testKey,
  });

  /// 可見文字（單行，超出截斷）。呼叫端傳入 i18n 取值。
  final String label;

  /// 目前核取值。
  final bool value;

  /// 點擊（核取框或文字）時呼叫，帶翻轉後的值。
  final ValueChanged<bool> onChanged;

  /// 測試錨點（`action-history-include-ticket-created`）。
  final Key testKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: testKey,
      container: true,
      checked: value,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!value),
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(Radius.sm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: LayoutSize.hitTargetMin,
            minHeight: LayoutSize.hitTargetMin,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.xs),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _box(),
                  SizedBox(width: Space.xs),
                  Flexible(child: _text()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _box() {
    return SizedBox(
      width: LayoutSize.iconLg,
      height: LayoutSize.iconLg,
      child: IgnorePointer(
        child: Checkbox(
          value: value,
          onChanged: (_) {},
          activeColor: AppColors.accent,
          checkColor: AppColors.surfaceBase,
          side: BorderSide(color: AppColors.textSecondary),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radius.sm),
          ),
        ),
      ),
    );
  }

  Widget _text() {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.body,
        color: AppColors.textPrimary,
      ),
    );
  }
}
