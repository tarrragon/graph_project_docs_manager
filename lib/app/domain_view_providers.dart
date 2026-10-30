/// Domain 視圖的畫面狀態注入點（app 層讀寫）。
///
/// [domainViewStateProvider] 為狀態注入點：gate 偵測與資料載入
/// （`app/domain_view_loader.dart`，0.5.0-W1-114.14）寫入真實狀態，測試以
/// `overrideWith` 切換至其餘十個狀態，畫面直接渲染。依賴畫面投影的 provider
/// （矩陣、泳道等）留在 `screens/domain_view/domain_view_providers.dart`。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';

/// 目前畫面狀態；預設 `DomainLoading`：App 啟動到 restore 完成前不顯示
/// fixture 矩陣（0.5.0-W3-003），由 shell 啟動流程寫入真實狀態。
final domainViewStateProvider = StateProvider<DomainViewState>(
  (ref) => const DomainLoading(),
);
