import 'dart:async';

import 'package:graph_project_docs_manager/edit/write_result.dart';

/// 需求：[SPEC-009 FR-08] session 寫入清單的一列：只含識別（路徑、欄位名、
/// 節點 ID、快照 SHA）與該次寫入的驗證狀態，不含欄位值（C-2）。
class WriteListEntry {
  WriteListEntry({
    required this.relativePath,
    required this.field,
    required this.nodeId,
    required this.snapshotSha,
  });

  final String relativePath;
  final String field;
  final String nodeId;
  final String? snapshotSha;

  /// 尚無驗證器時為 null；否則 `running` 之後為終態。
  ValidationStatus? validationStatus;

  @override
  String toString() =>
      // i18n-exempt
      'WriteListEntry($relativePath, $field, $nodeId, '
      // i18n-exempt
      'snapshot: ${snapshotSha ?? '-'}, status: ${validationStatus ?? '-'})';
}

/// 需求：[SPEC-009 FR-08] 本 App session 內寫過的檔案與欄位清單，跨編輯
/// session 共用；驗證結果非同步回來時就地更新該列，使用者離開該檔後回來
/// 仍可在清單上看到失敗。
class SessionWriteList {
  final List<WriteListEntry> _entries = [];
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  List<WriteListEntry> get entries => List.unmodifiable(_entries);

  /// 清單內容或某列狀態變動。
  Stream<void> get changes => _changes.stream;

  WriteListEntry record({
    required String relativePath,
    required String field,
    required String? snapshotSha,
  }) {
    final entry = WriteListEntry(
      relativePath: relativePath,
      field: field,
      nodeId: nodeIdOf(relativePath),
      snapshotSha: snapshotSha,
    );
    _entries.add(entry);
    _changes.add(null);
    return entry;
  }

  void updateStatus(WriteListEntry entry, ValidationStatus status) {
    entry.validationStatus = status;
    _changes.add(null);
  }

  /// 節點 ID：檔名去掉 `.md`（文件 ID 與檔名同名）。
  static String nodeIdOf(String relativePath) {
    final name = relativePath.substring(relativePath.lastIndexOf('/') + 1);
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }
}
