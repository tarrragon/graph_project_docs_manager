/// 需求：[SPEC-006 FR-02、FR-05] 掃描用的檔案系統存取埠（port）。
///
/// 所有路徑皆相對於已綁定的工作區根目錄、以 `/` 分隔、不含前導 `./`
/// （SPEC-006-test-design.md §3.2 C8-5）；本介面本身不知道工作區根目錄是
/// 什麼——由呼叫端在建構 [DefaultDocsFileSystem] 時傳入該值，Corpus 掃描器
/// 不自行推導（C8-6：根目錄取自 Workspace domain 的公開面，`docs/domain-map.md`
/// §5 依賴邊 Corpus → Workspace）。
library;

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'parse_outcome.dart';

/// [DocsFileSystemEntry.kind] 三選一。
enum DocsFileSystemEntryKind {
  /// 一般檔案。
  file,

  /// 一般目錄，掃描器會遞迴進入。
  directory,

  /// 符號連結（不論指向檔案或目錄）：掃描器不追蹤、不列入結果（FR-02
  /// 規則：不追符號連結，避免迴圈與重複計數）。
  symlink,
}

/// 目錄底下的一個直接子項。
class DocsFileSystemEntry {
  const DocsFileSystemEntry({required this.path, required this.kind});

  /// 相對工作區根、以 `/` 分隔的完整路徑（非僅檔名，C8-5）。
  final String path;

  final DocsFileSystemEntryKind kind;
}

/// 讀取結果二選一：成功取得位元組，或無法讀取。編碼失敗（[UnreadableReason.encoding]）
/// 由呼叫端在拿到位元組後另行判定（見 `frontmatter_classifier.dart`），不屬於
/// 本埠職責——本埠只回報「位元組本身取不到」的兩種子原因（FR-05）。
sealed class DocsReadResult {
  const DocsReadResult();
}

/// 成功讀到位元組。
class DocsReadSuccess extends DocsReadResult {
  const DocsReadSuccess(this.bytes);
  final Uint8List bytes;
}

/// 位元組取不到。
class DocsReadFailure extends DocsReadResult {
  const DocsReadFailure(this.reason);

  /// 只會是 [UnreadableReason.permission] 或 [UnreadableReason.fileDeleted]。
  final UnreadableReason reason;
}

/// 需求：[SPEC-006 FR-02、FR-05] 掃描用的檔案系統存取埠。
abstract interface class DocsFileSystem {
  /// 列出 [relativePath] 底下的直接子項；[relativePath] 不存在時回傳空
  /// 清單，不視為錯誤（FR-02：工作區沒有 `docs/` 時掃描 0 檔，C8-1）。
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath);

  /// 讀取 [relativePath] 的位元組。
  Future<DocsReadResult> readBytes(String relativePath);
}

/// [DocsFileSystem] 的 dart:io 預設實作，綁定 [workspaceRoot] 為基準目錄。
class DefaultDocsFileSystem implements DocsFileSystem {
  const DefaultDocsFileSystem(this.workspaceRoot);

  /// 工作區根目錄的絕對路徑，由呼叫端提供（Workspace domain 公開面）。
  final String workspaceRoot;

  String _absolute(String relativePath) => '$workspaceRoot/$relativePath';

  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async {
    final dir = Directory(_absolute(relativePath));
    if (!await dir.exists()) {
      return const <DocsFileSystemEntry>[];
    }
    final entries = <DocsFileSystemEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      entries.add(
        DocsFileSystemEntry(
          path: '$relativePath/${_basename(entity.path)}',
          kind: await _kindOf(entity),
        ),
      );
    }
    return entries;
  }

  /// [FileSystemEntity.type] 以 `followLinks: false` 查詢，讓符號連結（不論
  /// 指向檔案或目錄）回報為 [FileSystemEntityType.link]，與 [directory.list]
  /// 同一份 `followLinks: false` 語意一致，避免兩處判斷不同步。
  Future<DocsFileSystemEntryKind> _kindOf(FileSystemEntity entity) async {
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    return switch (type) {
      FileSystemEntityType.directory => DocsFileSystemEntryKind.directory,
      FileSystemEntityType.file => DocsFileSystemEntryKind.file,
      _ => DocsFileSystemEntryKind.symlink,
    };
  }

  String _basename(String entityPath) {
    final trimmed = entityPath.endsWith(Platform.pathSeparator)
        ? entityPath.substring(0, entityPath.length - 1)
        : entityPath;
    final idx = trimmed.lastIndexOf(Platform.pathSeparator);
    return idx == -1 ? trimmed : trimmed.substring(idx + 1);
  }

  @override
  Future<DocsReadResult> readBytes(String relativePath) async {
    final file = File(_absolute(relativePath));
    try {
      return DocsReadSuccess(await file.readAsBytes());
    } on FileSystemException catch (e) {
      developer.log(
        '讀取失敗：$relativePath', // i18n-exempt: 開發者 debug log
        name: 'DocsFileSystem',
        level: 900,
        error: e,
      );
      return DocsReadFailure(_reasonFor(e));
    }
  }

  /// errno 對照：13 = EACCES（權限不足）；其餘（含 2 = ENOENT）保守歸類為
  /// 檔案消失——列出後、讀取前變動的最常見表現即是檔案已不存在（FR-05）。
  UnreadableReason _reasonFor(FileSystemException e) {
    if (e.osError?.errorCode == 13) {
      return UnreadableReason.permission;
    }
    return UnreadableReason.fileDeleted;
  }
}
