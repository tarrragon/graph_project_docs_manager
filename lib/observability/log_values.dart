/// SPEC-010 FR-03：欄位值白名單包裝型別。
///
/// `fields` 只接受 [LogValue]，任意 String 無法通過編譯；字串型包裝以建構驗證。
library;

import 'package:graph_project_docs_manager/observability/log_enums.dart';

/// 白名單值；[toJson] 為序列化結果。
sealed class LogValue {
  const LogValue();

  /// enum 值（序列化為值名稱）。
  const factory LogValue.enumValue(Enum value) = LogEnumValue;

  /// 整數。
  const factory LogValue.integer(int value) = LogIntValue;

  /// 布林。
  const factory LogValue.boolean(bool value) = LogBoolValue;

  /// 工作區相對路徑；不在根之下時改為 [LogLocation.other]。
  factory LogValue.path(String root, String path) {
    final created = WorkspaceRelativePath.tryCreate(root, path);
    return created ?? const LogEnumValue(LogLocation.other);
  }

  /// 欄位名；不合法時改為 [LogIdentityRejected.fieldNameRejected]。
  factory LogValue.fieldName(String name) {
    final created = FieldName.tryCreate(name);
    return created ?? const LogEnumValue(LogIdentityRejected.fieldNameRejected);
  }

  /// 節點 ID；不合法時改為 [LogIdentityRejected.nodeIdRejected]。
  factory LogValue.nodeId(String id) {
    final created = NodeId.tryCreate(id);
    return created ?? const LogEnumValue(LogIdentityRejected.nodeIdRejected);
  }

  /// commit SHA；不合法時改為 [LogLocation.other]。
  factory LogValue.commitSha(String sha) {
    final created = CommitSha.tryCreate(sha);
    return created ?? const LogEnumValue(LogLocation.other);
  }

  Object toJson();
}

final class LogEnumValue extends LogValue {
  const LogEnumValue(this.value);
  final Enum value;
  @override
  Object toJson() => value.name;
}

final class LogIntValue extends LogValue {
  const LogIntValue(this.value);
  final int value;
  @override
  Object toJson() => value;
}

final class LogBoolValue extends LogValue {
  const LogBoolValue(this.value);
  final bool value;
  @override
  Object toJson() => value;
}

/// 工作區相對路徑，以 `/` 分隔。
final class WorkspaceRelativePath extends LogValue {
  const WorkspaceRelativePath._(this.value);
  final String value;

  /// 路徑不在 [root] 之下（含正規化後逃出根）時回傳 null。
  static WorkspaceRelativePath? tryCreate(String root, String path) {
    final rootSegments = _normalize(root);
    final pathSegments = _normalize(path);
    if (rootSegments == null || pathSegments == null) return null;
    if (pathSegments.length <= rootSegments.length) return null;
    for (var i = 0; i < rootSegments.length; i++) {
      if (rootSegments[i] != pathSegments[i]) return null;
    }
    final relative = pathSegments.sublist(rootSegments.length).join('/');
    return WorkspaceRelativePath._(relative);
  }

  /// 以 `/` 切段並消去 `.`、`..`；非絕對路徑或逃出起點回傳 null。
  static List<String>? _normalize(String path) {
    if (!path.startsWith('/')) return null;
    final out = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (out.isEmpty) return null;
        out.removeLast();
      } else {
        out.add(part);
      }
    }
    return out;
  }

  @override
  Object toJson() => value;
}

final RegExp _fieldNamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,63}$');
final RegExp _nodeIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');
final RegExp _commitShaPattern = RegExp(r'^[0-9a-f]{40}$');

/// 欄位名（字元集見 SPEC-010 FR-03）。
final class FieldName extends LogValue {
  const FieldName._(this.value);
  final String value;

  static FieldName? tryCreate(String name) =>
      _fieldNamePattern.hasMatch(name) ? FieldName._(name) : null;

  @override
  Object toJson() => value;
}

/// 節點 ID（字元集見 SPEC-010 FR-03）。
final class NodeId extends LogValue {
  const NodeId._(this.value);
  final String value;

  static NodeId? tryCreate(String id) =>
      _nodeIdPattern.hasMatch(id) ? NodeId._(id) : null;

  @override
  Object toJson() => value;
}

/// 40 字元小寫十六進位 SHA，不轉小寫。
final class CommitSha extends LogValue {
  const CommitSha._(this.value);
  final String value;

  static CommitSha? tryCreate(String sha) =>
      _commitShaPattern.hasMatch(sha) ? CommitSha._(sha) : null;

  @override
  Object toJson() => value;
}

/// 事件負載；鍵為字串、值只能是 [LogValue]。
final class LogFields {
  const LogFields(this.values);

  static const LogFields empty = LogFields({});

  final Map<String, LogValue> values;

  Map<String, Object> toJson() => {
    for (final e in values.entries) e.key: e.value.toJson(),
  };
}
