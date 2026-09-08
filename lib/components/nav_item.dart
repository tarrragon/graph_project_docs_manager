/// 側欄導覽項（SPEC-004 §4.7）。
///
/// 側欄六項導覽的唯一承載元件，`nav-item-<destination>`（既有錨點，不
/// 改名）。單一變體，`selected` / `unselected` 為狀態非變體差異；無
/// disabled——六項導覽恆可用（SPEC-003 §2.3）。純顯示 + callback（SPEC-004
/// §2 傳值 + callback 慣例），不持有選中狀態，呼叫端傳入 [isSelected]。
library;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'app_icon.dart';
import 'app_text.dart';

/// 側欄導覽項元件（SPEC-004 §4.7）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [icon] | 是 | `AppIcon`（`lg`，裝飾性，`semanticLabel` 為 `null`） |
/// | [label] | 是 | 單行文字，呼叫端傳入 i18n key 取值 |
/// | [isSelected] | 是 | 選中態旗標，決定底色與字色 |
/// | [onTap] | 是 | 點選（含 Space / Enter）觸發的回呼 |
/// | [testKey] | 是 | 呼叫端依 SPEC-004 4.7 slot 契約提供的定址 key（`nav-item-<destination>`） |
class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.testKey,
  });

  /// 導覽項圖示（裝飾性，`semanticLabel` 為 `null`）。
  final AppIcon icon;

  /// 導覽項文字，單行截斷（SPEC-004 4.7 內容政策）。
  final String label;

  /// 選中態旗標：`true` 時底 [AppColors.surfaceIconTint]、字與圖示
  /// [AppColors.accentStrong]、字重半粗。
  final bool isSelected;

  /// 點選觸發的回呼；點選已選項時本回呼仍呼叫，但不改變狀態
  /// （狀態由呼叫端持有，SPEC-004 4.7 互動反應）。
  final VoidCallback onTap;

  /// 呼叫端定址 key（SPEC-004 4.7 slot 契約，既有 `nav-item-<destination>`）。
  final Key testKey;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.accentStrong
        : AppColors.textPrimary;

    // 選中態圖示色隨狀態改變（SPEC-004 4.7 狀態矩陣），呼叫端傳入的
    // [icon] 只承載圖示資料，色彩由本元件依 [isSelected] 重新賦值。
    final effectiveIcon = AppIcon(
      icon: icon.icon,
      size: icon.size,
      color: foreground,
      semanticLabel: icon.semanticLabel,
    );

    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      // `hitTargetMin` 是**命中區下界**（SPEC-004 §1「可點元件的最小尺寸不得
      // 小於之」），不是內容容器的高度上界。以 `SizedBox(height:)` 釘死等於把
      // 無障礙下限反過來當排版上限用：內容（`iconLg` + 2 × `Space.sm`）需要的
      // 高度超過它，`SizedBox` 對超出部分是靜默裁切而非拋例外，實機上表現為
      // 中文字形上下緣被切。改為下界約束後高度隨內容固有值增長，SPEC-004 4.7
      // 尺寸契約的「高固有」與「最小命中區」同時成立。
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: LayoutSize.hitTargetMin),
        child: InkWell(
          key: testKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radius.md),
          excludeFromSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surfaceIconTint : null,
              borderRadius: BorderRadius.circular(Radius.md),
            ),
            // 外層 Semantics 已提供 label / button / selected；內部視覺
            // 內容（icon、Text）排除於語意樹，避免 Text 自帶語意節點與外層
            // label 合併重複。
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                child: Row(
                  children: [
                    effectiveIcon,
                    SizedBox(width: Space.sm),
                    Flexible(
                      child: AppText(
                        label,
                        maxLines: 1,
                        emphasis: isSelected,
                        tone: isSelected
                            ? AppTextTone.accentStrong
                            : AppTextTone.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
