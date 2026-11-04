/// [SPEC-006 FR-11 規則 10、D10] 就緒後存活檢查的金絲雀檔實作。
/// 只寫 `docs/` 第一層、符合命名的單一檔案。
library;

import 'dart:io';
import 'dart:math';

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:path/path.dart' as p;

const String _docsDirName = 'docs';
const int _tokenRadix = 36; // magic-exempt: base36 隨機 token
const int _tokenBound = 1 << 30; // magic-exempt: 隨機 token 範圍

class FileWatchCanaryIo implements WatchCanaryIo {
  FileWatchCanaryIo();

  final Random _random = Random();

  @override
  List<String> residualCanaries(String workspaceRoot) {
    final docs = Directory(p.join(workspaceRoot, _docsDirName));
    return [
      for (final e in docs.listSync(followLinks: false))
        if (e is File &&
            p.basename(e.path).startsWith(watchCanaryPrefix) &&
            p.basename(e.path).endsWith(watchCanarySuffix))
          '$_docsDirName/${p.basename(e.path)}',
    ];
  }

  @override
  String newCanaryPath() {
    final token = _random.nextInt(_tokenBound).toRadixString(_tokenRadix);
    return '$_docsDirName/$watchCanaryPrefix$token$watchCanarySuffix';
  }

  @override
  void write(String workspaceRoot, String relativePath) =>
      File(p.join(workspaceRoot, relativePath)).writeAsStringSync('');

  @override
  void delete(String workspaceRoot, String relativePath) =>
      File(p.join(workspaceRoot, relativePath)).deleteSync();
}
