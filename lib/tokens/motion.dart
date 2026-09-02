/// 時間 token（SPEC-003 §2.1，SPEC-002 FR-01 硬規則擴及時間字面值）。
///
/// 時間值不屬視覺樣式——它是互動契約的一部分（「按下取消後多久內抵達目標
/// 態」是行為，不是外觀），但適用 SPEC-002 的唯一硬規則：所有值先具名。
/// `lib/`（本目錄除外）不得出現 `Duration(milliseconds: <字面數字>)` 或
/// `Duration(seconds: <字面數字>)`。
///
/// 十個 token 依 SPEC-003 §2.1 分為兩類，呼叫慣例不同：
///
/// | 類別 | 呼叫慣例 | 成員 |
/// |------|---------|------|
/// | 契約（行為時限承諾） | `static const Duration`，`disableAnimations` 恆不歸零 | [Motion.feedback]、[Motion.spinnerMinVisible]、[Motion.cancelDeadline]、[Motion.progressTick]、[Motion.snackBar]、[Motion.snackBarWithAction]、[Motion.searchDebounce] |
/// | 動畫（純視覺呈現） | `static Duration` 依 `context` 求值（如 `Motion.transition(context)`），`disableAnimations` 為 `true` 時回傳 [Duration.zero] | [Motion.transition]、[Motion.overlay]、[Motion.skeletonCycle] |
///
/// 新增 token 時只需歸類「動畫」或「契約」，`disableAnimations` 下的行為即
/// 由本檔規則推導，不需逐一列舉例外（SPEC-003 §2.1）。
library;

import 'package:flutter/widgets.dart';

/// 時間 token。契約類為 `static const`，動畫類為依 `context` 求值的
/// `static` 方法。
abstract final class Motion {
  /// 點擊確認的出現上限。契約：100 ms 為知覺「操作立即生效」的上限。
  static const Duration feedback = Duration(
    milliseconds: 100,
  ); // magic-exempt token 定義本身

  /// 指示一旦顯示的最短停留。契約：避免載入極快時指示器一閃即逝。
  static const Duration spinnerMinVisible = Duration(
    milliseconds: 300,
  ); // magic-exempt token 定義本身

  /// 按下取消後抵達目標態的上限。契約：權衡系統過慢打斷操作連續感與等待
  /// 過久使用者失去專注兩種風險，訂於 400 ms–1 s 之間。
  static const Duration cancelDeadline = Duration(
    milliseconds: 500,
  ); // magic-exempt token 定義本身

  /// 進度計數文字的最小更新間隔。契約：高於此頻率的數字跳動不可讀。
  static const Duration progressTick = Duration(
    milliseconds: 200,
  ); // magic-exempt token 定義本身

  /// 純告知型 SnackBar 停留。契約：沿用 Flutter Material `SnackBar` 預設
  /// 顯示時長，不覆寫。
  static const Duration snackBar = Duration(
    seconds: 4,
  ); // magic-exempt token 定義本身

  /// 帶動作 SnackBar 停留。契約：需讀完再決定是否按，較純告知型加倍。
  static const Duration snackBarWithAction = Duration(
    seconds: 8,
  ); // magic-exempt token 定義本身

  /// 搜尋輸入停止後至觸發過濾的等待。契約：避免逐字元觸發造成畫面閃爍與
  /// 重複運算，訂為輸入停頓後的防抖動延遲。
  static const Duration searchDebounce = Duration(
    milliseconds: 300,
  ); // magic-exempt token 定義本身

  /// 狀態之間的 cross-fade。動畫：落在「幾乎即時帶」（100–400 ms）內，
  /// 以動畫掩蓋切換；`disableAnimations` 為 `true` 時回傳 [Duration.zero]。
  static Duration transition(BuildContext context) => _animated(
    context,
    const Duration(milliseconds: 150), // magic-exempt token 定義本身
  );

  /// 浮層展開與收合。動畫：浮層位移距離大於狀態淡入故取較長值；
  /// `disableAnimations` 為 `true` 時回傳 [Duration.zero]。
  static Duration overlay(BuildContext context) => _animated(
    context,
    const Duration(milliseconds: 200), // magic-exempt token 定義本身
  );

  /// 骨架 shimmer 的循環週期。動畫：一屏內可辨識為「持續進行」而不干擾
  /// 閱讀；`disableAnimations` 為 `true` 時回傳 [Duration.zero]（改為靜態
  /// 灰塊，由呼叫端處理視覺切換，本 token 僅提供時長）。
  static Duration skeletonCycle(BuildContext context) => _animated(
    context,
    const Duration(milliseconds: 1200), // magic-exempt token 定義本身
  );

  /// 動畫類 token 的共用歸零邏輯（SPEC-003 §2.1「減少動態效果」）。
  static Duration _animated(BuildContext context, Duration value) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }
}
