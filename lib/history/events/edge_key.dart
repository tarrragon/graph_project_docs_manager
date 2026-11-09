// SPEC-008 FR-04 規則 1：邊鍵與宣告來源元素。邊型與欄位名取自 Schema 邊型表。
import 'package:graph_project_docs_manager/schema/edge_type.dart';

/// 邊的身分：（邊型、起點、終點）。無向邊兩端依字典序排列。
class EdgeKey implements Comparable<EdgeKey> {
  const EdgeKey(this.edgeTypeName, this.from, this.to);

  final String edgeTypeName;
  final String from;
  final String to;

  /// 排序：邊型鍵名、起點、終點的字典序（FR-04 規則 4）。
  @override
  int compareTo(EdgeKey other) {
    final byType = edgeTypeName.compareTo(other.edgeTypeName);
    if (byType != 0) return byType;
    final byFrom = from.compareTo(other.from);
    return byFrom != 0 ? byFrom : to.compareTo(other.to);
  }

  @override
  bool operator ==(Object other) =>
      other is EdgeKey &&
      other.edgeTypeName == edgeTypeName &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(edgeTypeName, from, to);

  @override
  String toString() => 'EdgeKey($edgeTypeName, $from, $to)';
}

/// 宣告來源集合的元素：（路徑、欄位、值），另帶宣告者節點 ID 供事件呈現。
class EdgeSource {
  const EdgeSource({
    required this.path,
    required this.field,
    required this.value,
    required this.declarerId,
  });

  final String path;
  final String field;
  final String value;
  final String declarerId;

  @override
  bool operator ==(Object other) =>
      other is EdgeSource &&
      other.path == path &&
      other.field == field &&
      other.value == value &&
      other.declarerId == declarerId;

  @override
  int get hashCode => Object.hash(path, field, value, declarerId);
}

/// 需求：[SPEC-008 FR-04 規則 1] 由一筆宣告換算邊鍵。
/// 正向欄位為（邊型、宣告者、值），反向欄位為（邊型、值、宣告者），
/// 無向邊兩者依字典序。
EdgeKey edgeKeyOf({
  required EdgeTypeEntry edgeType,
  required String field,
  required String declarerId,
  required String value,
}) {
  if (edgeType.isUndirected) {
    final sorted = declarerId.compareTo(value) <= 0;
    return EdgeKey(
      edgeType.name,
      sorted ? declarerId : value,
      sorted ? value : declarerId,
    );
  }
  final isReverse = field == edgeType.reverseField;
  return isReverse
      ? EdgeKey(edgeType.name, value, declarerId)
      : EdgeKey(edgeType.name, declarerId, value);
}
