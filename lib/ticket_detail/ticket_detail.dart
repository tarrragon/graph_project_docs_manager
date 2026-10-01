/// 需求：[SPEC-007 FR-07] TicketDetail：以 ID 查 ticket frontmatter 全文。
///
/// 依賴方向：只 import `lib/corpus/`（RawNode 事件型別），不 import
/// `lib/graph/`、`lib/diagnostics/`（測試設計 §1.3）。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';

const _ticketTypeName = 'Ticket';
const _idKey = 'id';

Map<String, dynamic> _deepFreezeMap(Map<dynamic, dynamic> source) =>
    Map<String, dynamic>.unmodifiable({
      for (final e in source.entries) e.key as String: _deepFreeze(e.value),
    });

dynamic _deepFreeze(dynamic value) {
  if (value is Map) return _deepFreezeMap(value);
  if (value is List) return List<dynamic>.unmodifiable(value.map(_deepFreeze));
  return value;
}

/// 一輪 Corpus rawNodes 建立的不可變 ticket 全文索引。
///
/// frontmatter 建構時遞迴深層複製並凍結（List／Map 逐層 unmodifiable 副本，
/// 純量原樣保留），與 RawNode 不共用任何可變引用。
class TicketDetail {
  TicketDetail._(this._byId);

  /// 只收 Ticket 型別；重複 ID 整批排除（FR-02 語意）。
  factory TicketDetail.fromRawNodes(Iterable<RawNode> rawNodes) {
    final candidates = <String, Map<String, dynamic>>{};
    final duplicated = <String>{};
    for (final node in rawNodes) {
      if (node.typeName != _ticketTypeName) continue;
      final id = node.frontmatter[_idKey];
      if (id is! String) continue;
      if (candidates.containsKey(id)) duplicated.add(id);
      candidates[id] = _deepFreezeMap(node.frontmatter);
    }
    duplicated.forEach(candidates.remove);
    return TicketDetail._(Map.unmodifiable(candidates));
  }

  final Map<String, Map<String, dynamic>> _byId;

  /// 查無、重複 ID、非 Ticket 皆回傳 null，不拋例外。
  Map<String, dynamic>? findById(String id) => _byId[id];
}
