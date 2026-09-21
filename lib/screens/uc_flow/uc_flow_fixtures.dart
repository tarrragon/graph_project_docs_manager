/// UC Flow 視圖的固定假資料（設計約束：假資料驅動，不接真實圖建置，
/// `0.1.0-W1-003`／CLAUDE.md §6 同源；UC id 沿用 `domain_view_fixtures.dart`
/// 既有三個 UC，維持跨畫面一致）。
library;

/// UC 清單項：id + 是否含結構化 flow（`hasFlowStep`，決定選定後落
/// 「flow 未結構化」或「正常」）。
class UcFlowFixtureUc {
  const UcFlowFixtureUc({required this.id, required this.hasFlowStep});

  final String id;
  final bool hasFlowStep;
}

/// UC Flow 視圖固定假資料入口。
abstract final class UcFlowFixtures {
  /// 專案內全部 UC 節點（決定「無 UC」與「尚未選定 UC」的分派）。
  static const List<UcFlowFixtureUc> ucList = [
    UcFlowFixtureUc(id: 'UC-02', hasFlowStep: true),
    UcFlowFixtureUc(id: 'UC-04', hasFlowStep: true),
    UcFlowFixtureUc(id: 'UC-06', hasFlowStep: false),
  ];
}
