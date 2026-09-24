/// 記憶體檔案系統 fake（SPEC-006-test-design.md §1.4「記憶體檔案系統
/// fake」），供 C1、C8、C9、C10 等測試群組獨立建構掃描用 fixture。
///
/// 以宣告方式（`addFile`、`addSymlinkDirectory`、`denyReadPermission`、
/// `markDisappearedAfterListing`）指定每個路徑的位元組、權限拒絕、列出後
/// 消失，不重用任何真實 `dart:io` 物件。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';

class FakeDocsFileSystem implements DocsFileSystem {
  final Map<String, DocsFileSystemEntryKind> _entries =
      <String, DocsFileSystemEntryKind>{};
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  final Set<String> _permissionDenied = <String>{};
  final Set<String> _disappeared = <String>{};
  final Map<String, int> _listDenied = <String, int>{};
  final Map<String, Object> _readThrows = <String, Object>{};

  /// 新增一份檔案；沿途祖先目錄自動註冊為 [DocsFileSystemEntryKind.directory]。
  void addFile(String path, List<int> bytes) {
    _registerAncestorDirectories(path);
    _entries[path] = DocsFileSystemEntryKind.file;
    _files[path] = Uint8List.fromList(bytes);
  }

  /// 新增一個符號連結目錄（C8-4）：會被列出，但掃描器不會遞迴進入它。
  void addSymlinkDirectory(String path) {
    _registerAncestorDirectories(path);
    _entries[path] = DocsFileSystemEntryKind.symlink;
  }

  /// 新增一個非目錄非檔案的項目（[DocsFileSystemEntryKind.other]，如具名
  /// 管線或 socket）：會被列出，掃描器待遇與符號連結相同（略過、不遞迴），
  /// 但不冒稱符號連結（0.3.0-W3-535）。
  void addOtherEntry(String path) {
    _registerAncestorDirectories(path);
    _entries[path] = DocsFileSystemEntryKind.other;
  }

  /// 新增一個空目錄（沿途祖先目錄與自身皆註冊為
  /// [DocsFileSystemEntryKind.directory]），供 [denyListPermission] 標記
  /// 「無法列出」使用——沒有可讀內容，不需經由 [addFile] 間接註冊。
  void addDirectory(String path) {
    _registerAncestorDirectories('$path/_placeholder');
  }

  /// [path] 的列出回報無法列出（FR-02、NFR-01：目錄權限拒絕）。[errno]
  /// 對照 POSIX errno：預設 13（EACCES），亦可傳 1（EPERM）——掃描器須將
  /// 兩者皆判為權限不足（0.3.0-W3-535）。呼叫前 [path] 須已透過
  /// [addDirectory] 或 [addFile] 的祖先自動註冊為目錄。
  void denyListPermission(String path, {int errno = 13}) {
    assert(
      _entries[path] == DocsFileSystemEntryKind.directory,
      'denyListPermission 前必須先是已知目錄：$path', // i18n-exempt: 測試 assert 訊息，非 UI 顯示字串
    );
    _listDenied[path] = errno;
  }

  /// [path] 的讀取直接拋出 [error]（而非回傳 [DocsReadFailure]），模擬
  /// [DocsFileSystem] 實作違反 [DocsReadResult] 契約的非預期例外，供驗證
  /// `corpus_scanner.dart` 兜底 catch 的分類邏輯（0.3.0-W3-535）。呼叫前
  /// [path] 須已透過 [addFile] 加入，讓它仍出現在列出結果中。
  void throwOnRead(String path, Object error) {
    assert(
      _entries[path] == DocsFileSystemEntryKind.file,
      'throwOnRead 前必須先 addFile：$path', // i18n-exempt: 測試 assert 訊息，非 UI 顯示字串
    );
    _readThrows[path] = error;
  }

  /// [path] 的讀取回報權限拒絕（C9-3）。呼叫前 [path] 須已透過 [addFile]
  /// 加入，讓它仍出現在列出結果中，僅讀取失敗。
  void denyReadPermission(String path) {
    assert(
      _entries[path] == DocsFileSystemEntryKind.file,
      'denyReadPermission 前必須先 addFile：$path', // i18n-exempt: 測試 assert 訊息，非 UI 顯示字串
    );
    _permissionDenied.add(path);
  }

  /// [path] 在「列出後、讀取前」消失（C9-4）。呼叫前 [path] 須已透過
  /// [addFile] 加入，讓它仍出現在列出結果中，僅讀取失敗。
  void markDisappearedAfterListing(String path) {
    assert(
      _entries[path] == DocsFileSystemEntryKind.file,
      'markDisappearedAfterListing 前必須先 addFile：$path', // i18n-exempt: 測試 assert 訊息，非 UI 顯示字串
    );
    _disappeared.add(path);
  }

  void _registerAncestorDirectories(String path) {
    final segments = path.split('/');
    var current = '';
    for (var i = 0; i < segments.length - 1; i++) {
      current = current.isEmpty ? segments[i] : '$current/${segments[i]}';
      _entries[current] = DocsFileSystemEntryKind.directory;
    }
  }

  String _parentOf(String path) {
    final idx = path.lastIndexOf('/');
    return idx == -1 ? '' : path.substring(0, idx);
  }

  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async {
    final deniedErrno = _listDenied[relativePath];
    if (deniedErrno != null) {
      throw FileSystemException(
        '模擬列出失敗', // i18n-exempt: 測試模擬訊息，非 UI 顯示字串
        relativePath,
        OSError('模擬列出失敗', deniedErrno), // i18n-exempt: 測試模擬訊息，非 UI 顯示字串
      );
    }
    final children = _entries.entries
        .where((entry) => _parentOf(entry.key) == relativePath)
        .map((entry) => DocsFileSystemEntry(path: entry.key, kind: entry.value))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return children;
  }

  @override
  Future<DocsReadResult> readBytes(String relativePath) async {
    final thrown = _readThrows[relativePath];
    if (thrown != null) {
      throw thrown;
    }
    if (_disappeared.contains(relativePath)) {
      return const DocsReadFailure(UnreadableReason.fileDeleted);
    }
    if (_permissionDenied.contains(relativePath)) {
      return const DocsReadFailure(UnreadableReason.permission);
    }
    final bytes = _files[relativePath];
    if (bytes == null) {
      return const DocsReadFailure(UnreadableReason.fileDeleted);
    }
    return DocsReadSuccess(Uint8List.fromList(bytes));
  }
}
