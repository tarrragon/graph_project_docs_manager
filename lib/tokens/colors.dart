/// 顏色 token（SPEC-002）。
///
/// 三層命名：
/// 1. 原始值層（`_Palette`）：這個值是多少。私有，畫面不得引用。
/// 2. 語意層（`AppColors`）：這個值代表什麼。畫面引用此層。
/// 3. 元件層：個別元件檔案中定義（如 `NavItem.selectedBg`），引用本檔的語意層。
///
/// 值來源：`design/` 九份 artboard 實測（1280x800 無縮放），已回填至
/// `docs/spec/ui/SPEC-002-design-tokens-and-component-library.md` 的顏色分佈表。
/// 兩者不符時以 artboard 為準（SPEC-002 設計約束）。
///
/// 本檔是 SPEC-002 定義的唯一允許出現裸色碼的位置，故 `_Palette` 內的
/// `Color(0x...)` 皆標記 `color-exempt`；語意層與元件層一律引用 [AppColors]，
/// 不得再出現裸色碼。
library;

import 'package:flutter/widgets.dart';

/// 原始值層：色碼與其在 artboard 的出現次數，僅供本檔內部參照與追溯。
/// 畫面程式碼不得直接引用 `_Palette`，一律經由 [AppColors]。
abstract final class _Palette {
  // 中性色階（依明度排序）
  static const Color black900 = Color(0xFF181C1B); // color-exempt 標題文字，21 次
  static const Color gray700 = Color(0xFF5C6866); // color-exempt 主要文字，147 次
  static const Color gray500 = Color(0xFF8A9694); // color-exempt 次要文字／弱化，116 次
  static const Color gray300 = Color(0xFFC7D2D0); // color-exempt 邊框（較深），47 次
  static const Color gray200 = Color(0xFFE2E9E8); // color-exempt 分隔線／邊框，70 次
  static const Color white = Color(0xFFFFFFFF); // color-exempt 底，37 次

  // 表面色（四個角色互異，非同一序列的四階明度，見 AppColors 各常數註解）
  static const Color surfaceSidebar = Color(0xFFF4F6F5); // color-exempt 側欄背景
  static const Color surfaceIconTint = Color(0xFFE0EFED); // color-exempt 圖示容器底
  static const Color surfaceChip = Color(0xFFE9EEED); // color-exempt 徽章／標籤底
  static const Color surfaceSegmentTrack = Color(0xFFDCE4E2); // color-exempt 分段控制軌道底

  // 品牌強調色
  static const Color teal900 = Color(0xFF0F4B47); // color-exempt 深色強調（圖示、標籤文字），59 次
  static const Color teal600 = Color(0xFF2E6F6A); // color-exempt seed／強調（按鈕底、作用中標記），47 次

  // 語意狀態色
  static const Color green600 = Color(0xFF2E6F3E); // color-exempt 成功，13 次
  static const Color amber800 = Color(0xFF8A5A00); // color-exempt 警告，11 次
  static const Color amber100 = Color(0xFFFBF1DF); // color-exempt 警告底，3 次
  static const Color red600 = Color(0xFFB3261E); // color-exempt 錯誤，10 次
  static const Color red100 = Color(0xFFFBE9E7); // color-exempt 錯誤底，6 次
}

/// 語意層：畫面與元件引用此層，不引用 [_Palette]。
///
/// 每個名字回溯自 [_Palette] 的原始值：
/// - [textPrimary] = `_Palette.gray700`
/// - [textSecondary] = `_Palette.gray500`
/// - [textTitle] = `_Palette.black900`
/// - [accent] = `_Palette.teal600`
/// - [accentStrong] = `_Palette.teal900`
/// - [border] = `_Palette.gray200`
/// - [borderStrong] = `_Palette.gray300`
/// - [surfaceBase] = `_Palette.white`
/// - [surfaceSidebar] = `_Palette.surfaceSidebar`
/// - [surfaceIconTint] = `_Palette.surfaceIconTint`
/// - [surfaceChip] = `_Palette.surfaceChip`
/// - [surfaceSegmentTrack] = `_Palette.surfaceSegmentTrack`
/// - [success] = `_Palette.green600`
/// - [warning] = `_Palette.amber800`
/// - [warningSurface] = `_Palette.amber100`
/// - [error] = `_Palette.red600`
/// - [errorSurface] = `_Palette.red100`
abstract final class AppColors {
  static const Color textPrimary = _Palette.gray700;
  static const Color textSecondary = _Palette.gray500;
  static const Color textTitle = _Palette.black900;

  static const Color accent = _Palette.teal600;
  static const Color accentStrong = _Palette.teal900;

  static const Color border = _Palette.gray200;
  static const Color borderStrong = _Palette.gray300;

  static const Color surfaceBase = _Palette.white;

  /// 側欄／頁面級底色。非「內容表面明度階」的一階，是側欄專屬背景。
  static const Color surfaceSidebar = _Palette.surfaceSidebar;

  /// 圖示容器底色（icon 外框的淡色底）。
  static const Color surfaceIconTint = _Palette.surfaceIconTint;

  /// 徽章／標籤／小卡片的中性底色。
  static const Color surfaceChip = _Palette.surfaceChip;

  /// 分段控制（segmented control）軌道底色，選中項的容器背景。
  static const Color surfaceSegmentTrack = _Palette.surfaceSegmentTrack;

  static const Color success = _Palette.green600;
  static const Color warning = _Palette.amber800;
  static const Color warningSurface = _Palette.amber100;
  static const Color error = _Palette.red600;
  static const Color errorSurface = _Palette.red100;
}
