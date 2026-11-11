import 'dart:io';

/// 寫入授權用的工作區相對路徑（SPEC-009 FR-04）。
///
/// 只有 [WorkspaceRelativePath.from] 一個入口；失敗回傳 null。寫入函式只收
/// 此型別，因此「寫入前驗證路徑」不需要呼叫端記得。與 SPEC-010 的日誌識別
/// 路徑型別是兩個型別：本型別可轉為日誌型別，反向不行。
class WorkspaceRelativePath {
  const WorkspaceRelativePath._(this.relative, this.absolute);

  /// 已驗證的相對路徑（以 `/` 分隔，無 `.`、`..`、空段）。
  final String relative;

  /// 父目錄經 symlink 解析後的絕對路徑，保證落在解析後的工作區根之內。
  final String absolute;

  /// 正規化並驗證 [relativePath] 是否在 [workspaceRoot] 之內。
  ///
  /// 解析基準為 [workspaceRoot]，不是行程工作目錄。不做大小寫折疊。
  static WorkspaceRelativePath? from(
    String workspaceRoot,
    String relativePath,
  ) {
    final segments = _validSegments(relativePath);
    if (segments == null) return null;
    final root = _resolveDirectory(workspaceRoot);
    if (root == null) return null;
    final parent = _resolveDirectory(
      _join(root, segments.sublist(0, segments.length - 1)),
    );
    if (parent == null || !_isInside(root, parent)) return null;
    final absolute = _join(parent, [segments.last]);
    if (_isSymlink(absolute)) return null;
    return WorkspaceRelativePath._(segments.join('/'), absolute);
  }

  static List<String>? _validSegments(String input) {
    if (input.isEmpty || input.startsWith('/') || input.contains('\u0000')) {
      return null;
    }
    final segments = input.split('/');
    final bad = segments.any((s) => s.isEmpty || s == '.' || s == '..');
    return bad ? null : segments;
  }

  static String? _resolveDirectory(String path) {
    try {
      return Directory(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
  }

  /// 以「根加分隔符」為前綴比對，避免 `/work` 誤判 `/workspace`。
  static bool _isInside(String root, String path) {
    if (path == root) return true;
    final prefix = root.endsWith('/') ? root : '$root/';
    return path.startsWith(prefix);
  }

  static String _join(String base, List<String> segments) =>
      [base, ...segments].join('/');

  static bool _isSymlink(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.link;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceRelativePath && other.absolute == absolute;

  @override
  int get hashCode => absolute.hashCode;

  @override
  String toString() => 'WorkspaceRelativePath($relative)';
}
