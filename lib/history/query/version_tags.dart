// SPEC-008 FR-06 規則 1、2：版本 tag 判定與基準 tag（純函式）。
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';

final RegExp _versionTagPattern = RegExp(r'^v?[0-9]+\.[0-9]+\.[0-9]+$');

/// 基準 tag 與其在主線清單（由新到舊）中的序號。
class BaseTag {
  const BaseTag({required this.tag, required this.mainlineIndex});

  final GitTagRef tag;

  /// 0 為 HEAD；序號越小越新。
  final int mainlineIndex;
}

/// 需求：[SPEC-008 FR-06 規則 1] 名稱符合版本樣式的 tag。
bool isVersionTagName(String name) => _versionTagPattern.hasMatch(name);

/// 需求：[SPEC-008 FR-06 規則 1、2] 主線序號最大（最接近 HEAD）、
/// 不是 HEAD 本身、且 commit 在主線清單內的版本 tag；沒有則回傳 null。
/// 不讀掃描輸出，故 tag 打在未觸及 docs/ 的 commit 時仍成立。
BaseTag? selectBaseTag({
  required List<String> mainline,
  required List<GitTagRef> tags,
  required String head,
}) {
  final indexById = {for (var i = 0; i < mainline.length; i++) mainline[i]: i};
  BaseTag? best;
  for (final tag in tags) {
    final index = indexById[tag.commitId];
    if (index == null || tag.commitId == head) continue;
    if (!isVersionTagName(tag.name)) continue;
    if (_isBetter(index, tag, best)) {
      best = BaseTag(tag: tag, mainlineIndex: index);
    }
  }
  return best;
}

bool _isBetter(int index, GitTagRef tag, BaseTag? best) {
  if (best == null || index < best.mainlineIndex) return true;
  return index == best.mainlineIndex && tag.name.compareTo(best.tag.name) > 0;
}
