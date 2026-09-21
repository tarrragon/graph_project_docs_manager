/// Domain 視圖的狀態注入點（設計約束同 trace/gap_report：狀態注入而非
/// 等待真實解析，`test/fixtures/corpus/` 收錄理由同源，本票不接真實
/// 工作資料夾與圖建置）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain_view_state.dart';

/// 目前畫面狀態；預設 `DomainReady`（矩陣模式，無選格、無降級旗標）。
/// 測試以 `overrideWith` 切換至其餘十個狀態，畫面直接渲染，不經真實
/// 資料夾選擇或節點解析。
final domainViewStateProvider = StateProvider<DomainViewState>(
  (ref) => const DomainReady(mode: DomainMode.matrix),
);
