/// 目前選定的 UC（App 層共用值；SPEC-003 §2.8〈選定 UC：App 層共用值〉，
/// 用戶裁示 2026-09-14）。
///
/// 不屬於任一畫面的頁面狀態；四個設定入口寫同一個值，後寫者覆蓋先寫者：
/// Domain 視圖矩陣點交叉格（入口 1）、UC Flow 視圖選擇 UC（入口 2）、
/// Domain 視圖格詳情卡「在泳道中檢視」（入口 3）、破洞報告事件類破洞項
/// （入口 4，`0.1.0-W3-335.67` K7）。0.1 僅入口 4 有呼叫端——Domain 視圖與
/// UC Flow 視圖尚未實作（CLAUDE.md 里程碑），入口 1–3 留待對應畫面票接線。
/// 切換專案時清空為空，其餘操作不影響此值（見 SPEC-003 §2.8 表）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 目前選定的 UC 節點 id；空代表尚未選定。
final selectedUcProvider = StateProvider<String?>((ref) => null);
