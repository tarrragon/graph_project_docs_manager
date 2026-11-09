// SPEC-008 FR-06 規則 3～5：預設期間與「最近 30 天」判定（時鐘注入）。
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/query/version_tags.dart';

/// 「最近 30 天」的天數（用戶裁定 2026-11-09）。
const int recentPeriodDays = 30;

const int _secondsPerDay = 24 * 3600;

/// 期間判定；以主線序號或 committer 時間為準，與 tag commit 是否觸及 docs/ 無關。
class HistoryPeriod {
  HistoryPeriod._(this.baseTag, this._indexById, this._cutoffSeconds);

  /// 有基準 tag 時的基準；否則 null。畫面層可據此自行本地化描述。
  final GitTagRef? baseTag;
  final Map<String, int>? _indexById;
  final int _cutoffSeconds;

  /// 需求：[SPEC-008 FR-06 規則 5] 有基準 tag 為「`tag` 之後」，否則「最近 30 天」。
  String get description =>
      // i18n-exempt: 規格定案的描述字面（domain 層）；畫面層改以 baseTag 本地化
      baseTag == null ? '最近 $recentPeriodDays 天' : '${baseTag!.name} 之後';

  /// 嚴格大於：基準 tag commit 之後（序號較新）或 committer 時間晚於截止時間。
  bool containsCommit(String commitId, int committedAtSeconds) {
    final indexById = _indexById;
    if (indexById == null) return committedAtSeconds > _cutoffSeconds;
    final index = indexById[commitId];
    return index != null && index < indexById[baseTag!.commitId]!;
  }
}

int _cutoffFrom(DateTime now) =>
    now.millisecondsSinceEpoch ~/ 1000 - recentPeriodDays * _secondsPerDay;

/// 需求：[SPEC-008 FR-06 規則 3、4] 預設期間。[now] 為注入時鐘的目前時間。
HistoryPeriod resolveDefaultPeriod({
  required List<String> mainline,
  required List<GitTagRef> tags,
  required String head,
  required DateTime now,
}) {
  final base = selectBaseTag(mainline: mainline, tags: tags, head: head);
  if (base == null) return recentPeriod(now: now);
  return HistoryPeriod._(base.tag, {
    for (var i = 0; i < mainline.length; i++) mainline[i]: i,
  }, _cutoffFrom(now));
}

/// 需求：[SPEC-008 FR-06 規則 4] 「最近 30 天」，與預設期間無基準時共用。
HistoryPeriod recentPeriod({required DateTime now}) =>
    HistoryPeriod._(null, null, _cutoffFrom(now));
