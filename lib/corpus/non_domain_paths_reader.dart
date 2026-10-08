/// 需求：[SPEC-006 FR-10；UC-02〈ticket 定位的五種狀態與整體未宣告〉；
/// EVT-CORPUS-005] Corpus 公開面：讀取被觀測專案的非 domain 路徑清單檔，
/// 提供三態（缺席／顯式空清單／有值）與格式錯誤事件。
///
/// 依賴方向：只 import `lib/schema/` 與本 domain；Graph 經本檔取得清單，
/// 不自行讀檔（`0.5.0-W1-096.7` acceptance 3）。
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:yaml/yaml.dart';

import 'docs_file_system.dart';

const _tag = 'corpus.non_domain_paths_reader';

/// 需求：[SPEC-006 FR-10 規則 2、2a] 格式錯誤的四種子原因。
enum NonDomainPathsMalformedReason {
  /// YAML 解析失敗（含內容不是合法 UTF-8）。
  yamlInvalid,

  /// 缺該鍵（含頂層不是 map）。
  keyMissing,

  /// 該鍵的值不是清單。
  notList,

  /// 清單內有非字串元素：只略過該元素，非 domain 側仍為已宣告（規則 2a）。
  elementNotString,
}

/// EVT-CORPUS-005 的負載（`docs/events/corpus/
/// EVT-CORPUS-005-non-domain-paths-parse-failed.md`〈負載結構〉）。
class NonDomainPathsParseFailedEvent {
  const NonDomainPathsParseFailedEvent({
    required this.path,
    required this.reason,
    this.nonStringElementCount,
  });

  /// 清單檔相對於工作區根目錄的路徑。
  final String path;

  final NonDomainPathsMalformedReason reason;

  /// 非字串元素數；只在 [reason] 為 `elementNotString` 時有值，其餘為 `null`。
  final int? nonStringElementCount;
}

/// 非 domain 側的宣告狀態。
sealed class NonDomainPathsDeclaration {
  const NonDomainPathsDeclaration();

  /// 已宣告時為模式清單（可為空清單）；未宣告（缺席或格式錯誤）時為 `null`。
  List<String>? get declaredPatterns;
}

/// 清單檔不存在：非 domain 側未宣告（FR-10 規則 3）。
class NonDomainPathsAbsent extends NonDomainPathsDeclaration {
  const NonDomainPathsAbsent();

  @override
  List<String>? get declaredPatterns => null;
}

/// 清單檔整份格式錯誤（規則 2 三種）：非 domain 側視為未宣告（FR-10 規則 4），
/// 另有事件。`elementNotString` 不走此型別（規則 2a）。
class NonDomainPathsMalformed extends NonDomainPathsDeclaration {
  const NonDomainPathsMalformed(this.reason);

  final NonDomainPathsMalformedReason reason;

  @override
  List<String>? get declaredPatterns => null;
}

/// 已宣告：[patterns] 為空清單代表已宣告且不收任何路徑。
class NonDomainPathsDeclared extends NonDomainPathsDeclaration {
  const NonDomainPathsDeclared(this.patterns);

  final List<String> patterns;

  @override
  List<String>? get declaredPatterns => patterns;
}

/// 一輪讀取結果；[malformedEvent] 最多一筆（EVT-CORPUS-005〈負載結構〉）。
class NonDomainPathsReadResult {
  const NonDomainPathsReadResult({
    required this.declaration,
    this.malformedEvent,
  });

  final NonDomainPathsDeclaration declaration;
  final NonDomainPathsParseFailedEvent? malformedEvent;
}

const _absentResult = NonDomainPathsReadResult(
  declaration: NonDomainPathsAbsent(),
);

/// 需求：[SPEC-006 FR-10] 依型別表定位清單檔並讀取。位置與鍵名取自
/// [projectTable]，缺欄時回落 [builtinTable]（規則 1）。
Future<NonDomainPathsReadResult> readNonDomainPaths({
  required DocsFileSystem fileSystem,
  required TypeTable projectTable,
  required TypeTable builtinTable,
}) async {
  final path =
      projectTable.nonDomainPathsFile ?? builtinTable.nonDomainPathsFile;
  final key = projectTable.nonDomainPathsKey ?? builtinTable.nonDomainPathsKey;
  if (path == null || key == null) {
    _log(
      // i18n-exempt: 開發者診斷 log
      'no non-domain paths location in either table; absent',
      900,
    );
    return _absentResult;
  }
  final read = await fileSystem.readBytes(path);
  switch (read) {
    case DocsReadFailure(:final reason):
      _log(
        // i18n-exempt: 開發者診斷 log
        'non-domain paths file unreadable, absent: $path (${reason.name})',
        800,
      );
      return _absentResult;
    case DocsReadSuccess(:final bytes):
      return _classify(path, key, bytes);
  }
}

/// 需求：[SPEC-006 FR-10 規則 2] 依解析結果分為已宣告或三種格式錯誤之一。
NonDomainPathsReadResult _classify(String path, String key, List<int> bytes) {
  final Object? document;
  try {
    document = loadYaml(utf8.decode(bytes));
  } on FormatException catch (error) {
    // YamlException 為 FormatException 子型別；UTF-8 解碼失敗同歸 YAML 解析失敗。
    _log(
      // i18n-exempt: 開發者診斷 log
      'non-domain paths file YAML invalid: $path ($error)',
      900,
    );
    return _malformed(path, NonDomainPathsMalformedReason.yamlInvalid);
  }
  if (document is! Map || !document.containsKey(key)) {
    return _malformed(path, NonDomainPathsMalformedReason.keyMissing);
  }
  final value = document[key];
  if (value is! List) {
    return _malformed(path, NonDomainPathsMalformedReason.notList);
  }
  return _declared(path, value);
}

/// 需求：[SPEC-006 FR-10 規則 2a、2b] 字串元素不檢查格式照收；非字串元素略過，
/// 有任一個時發一筆 `elementNotString` 事件並帶個數。
NonDomainPathsReadResult _declared(String path, List<dynamic> value) {
  final patterns = List<String>.unmodifiable(value.whereType<String>());
  final nonStringCount = value.length - patterns.length;
  final declaration = NonDomainPathsDeclared(patterns);
  if (nonStringCount == 0) {
    return NonDomainPathsReadResult(declaration: declaration);
  }
  _log(
    // i18n-exempt: 開發者診斷 log
    'non-domain paths non-string elements skipped: $path ($nonStringCount)',
    900,
  );
  return NonDomainPathsReadResult(
    declaration: declaration,
    malformedEvent: NonDomainPathsParseFailedEvent(
      path: path,
      reason: NonDomainPathsMalformedReason.elementNotString,
      nonStringElementCount: nonStringCount,
    ),
  );
}

NonDomainPathsReadResult _malformed(
  String path,
  NonDomainPathsMalformedReason reason,
) {
  _log(
    // i18n-exempt: 開發者診斷 log
    'non-domain paths file malformed: $path (${reason.name})',
    900,
  );
  return NonDomainPathsReadResult(
    declaration: NonDomainPathsMalformed(reason),
    malformedEvent: NonDomainPathsParseFailedEvent(path: path, reason: reason),
  );
}

void _log(String message, int level) {
  developer.log(message, name: _tag, level: level);
}
