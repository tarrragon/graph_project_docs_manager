// SPEC-008 FR-02：`git log -p` 串流解析與檔案全文狀態追蹤（純函式風格，無 I/O）。
// 輸入為位元組分段，輸出為每個主線 commit 的（路徑 → 前後 frontmatter 文字）與計數。
import 'dart:convert';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

// git 輸出格式字面（非使用者可見字串）。
const String _diffGitPrefix = 'diff --git '; // i18n-exempt: git 輸出格式
const String _newFileMode = 'new file mode'; // i18n-exempt: git 輸出格式
const String _deletedFileMode = 'deleted file mode'; // i18n-exempt: git 輸出格式
const String _devNull = '/dev/null'; // i18n-exempt: git 輸出格式
const String _fmFence = '---'; // i18n-exempt: frontmatter 界線

/// 日誌級別：失步為 warning，無法解析的版本為 debug。
enum ParseLogLevel { debug, warning }

typedef ParseLogSink = void Function(ParseLogLevel level, String message);

/// 判斷 frontmatter 文字能否解析；預設以 YAML 解碼。
typedef FrontmatterParseCheck = bool Function(String frontmatterText);

/// commit 標頭（FR-02 規則 1）。
class HistoryCommit {
  const HistoryCommit({
    required this.id,
    required this.parents,
    required this.committedAtSeconds,
    required this.author,
    required this.subject,
  });

  final String id;
  final List<String> parents;
  final int committedAtSeconds;
  final String author;
  final String subject;
}

/// 單一路徑在一個 commit 前後的 frontmatter 文字（不含 `---` 界線）。
/// `null` 表示無 frontmatter（或檔案不存在）。
class PathChange {
  const PathChange({
    required this.path,
    required this.before,
    required this.after,
    required this.created,
    required this.deleted,
  });

  final String path;
  final String? before;
  final String? after;
  final bool created;
  final bool deleted;
}

class ScanCommitResult {
  const ScanCommitResult(this.commit, this.changes);
  final HistoryCommit commit;
  final List<PathChange> changes;
}

/// 解析計數（FR-02 規則 2、7、8）。
class ScanCounters {
  int undecodableLines = 0;
  int unparsableVersions = 0;
  int desyncs = 0;
  int yamlParses = 0;
}

class _FileState {
  List<String> lines = [];
  String? declText;
  int? frontmatterEnd;
  bool desynced = false;
}

class _Touch {
  _Touch({required this.before, required this.state});
  final String? before;
  final _FileState state;
  bool created = false;
  bool deleted = false;
  final List<int> hunkStarts = [];
}

class ScanStreamParser {
  ScanStreamParser({FrontmatterParseCheck? parseCheck, this.logSink})
    : _parseCheck = parseCheck ?? _defaultParseCheck;

  static final RegExp _hunkHeader = RegExp(
    r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
  );

  final FrontmatterParseCheck _parseCheck;
  final ParseLogSink? logSink;
  final ScanCounters counters = ScanCounters();
  final Map<String, _FileState> _states = {};
  final BytesBuilder _carry = BytesBuilder(copy: false);

  HistoryCommit? _commit;
  Map<String, _Touch> _touched = {};
  int _trackedChars = 0;

  /// 追蹤文字量的尖峰（UTF-16 code unit 數）。
  int peakTrackedChars = 0;

  // 條目狀態
  String? _diffGitPath;
  bool _entryNew = false;
  bool _entryDeleted = false;
  bool _entryHasPaths = false;
  String? _pendingOld;
  String? _entryPath;
  _Touch? _entryTouch;

  // hunk 狀態
  int _oldRemain = 0;
  int _newRemain = 0;
  int _hunkOldStart = 0;
  int _hunkOldCount = 0;
  int _hunkNewStart = 0;
  int _hunkNewCount = 0;
  List<String> _hunkOld = [];
  List<String> _hunkNew = [];

  /// 某路徑目前追蹤的全文行（測試與診斷用）；無狀態回傳 null。
  List<String>? fileLines(String path) => _states[path]?.lines;

  /// 餵入一段位元組，回傳此段內完成的 commit。
  List<ScanCommitResult> addChunk(List<int> bytes) {
    final done = <ScanCommitResult>[];
    var start = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0x0A) continue;
      _carry.add(bytes.sublist(start, i));
      _processLine(_carry.takeBytes(), done);
      start = i + 1;
    }
    if (start < bytes.length) _carry.add(bytes.sublist(start));
    return done;
  }

  /// 輸出結束：處理殘餘的最後一行並結算最後一個 commit。
  List<ScanCommitResult> close() {
    final done = <ScanCommitResult>[];
    if (_carry.length > 0) _processLine(_carry.takeBytes(), done);
    _finishCommit(done);
    return done;
  }

  void _processLine(Uint8List raw, List<ScanCommitResult> done) {
    final line = _decode(raw);
    if (_oldRemain > 0 || _newRemain > 0) {
      _consumeHunkLine(line);
      return;
    }
    if (line.startsWith('\u001e')) {
      _finishCommit(done);
      _commit = _parseHeader(line);
      return;
    }
    if (_commit == null) return;
    _processOutsideHunk(line);
  }

  String _decode(Uint8List raw) {
    try {
      return utf8.decode(raw);
    } on FormatException {
      counters.undecodableLines++;
      return utf8.decode(raw, allowMalformed: true);
    }
  }

  HistoryCommit _parseHeader(String line) {
    final f = line.substring(1).split('\u0000');
    String at(int i) => i < f.length ? f[i] : '';
    return HistoryCommit(
      id: at(0),
      parents: at(1).split(' ').where((p) => p.isNotEmpty).toList(),
      committedAtSeconds: int.tryParse(at(2)) ?? 0,
      author: at(3),
      subject: at(4),
    );
  }

  void _processOutsideHunk(String line) {
    if (line.startsWith(_diffGitPrefix)) {
      _closeEntry();
      _diffGitPath = _pathFromDiffGit(line);
    } else if (line.startsWith(_newFileMode)) {
      _entryNew = true;
    } else if (line.startsWith(_deletedFileMode)) {
      _entryDeleted = true;
    } else if (line.startsWith('--- ')) {
      _pendingOld = _stripSide(line.substring(4), 'a');
    } else if (line.startsWith('+++ ') && _pendingOld != null) {
      _openEntry(_pendingOld!, _stripSide(line.substring(4), 'b'));
    } else if (line.startsWith('@@ ')) {
      _beginHunk(line);
    }
  }

  // ---- 路徑 ----

  String _stripSide(String text, String prefix) {
    var t = text.endsWith('\t') ? text.substring(0, text.length - 1) : text;
    if (t == _devNull) return t;
    if (t.startsWith('"')) t = _unquote(t);
    return t.startsWith('$prefix/') ? t.substring(2) : t;
  }

  /// 還原 C-style 引號（八進位位元組與常見跳脫），再以 UTF-8 解碼。
  String _unquote(String quoted) {
    final inner = quoted.endsWith('"') && quoted.length >= 2
        ? quoted.substring(1, quoted.length - 1)
        : quoted.substring(1);
    final out = <int>[];
    final units = utf8.encode(inner);
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (u != 0x5C || i + 1 >= units.length) {
        out.add(u);
        continue;
      }
      final n = units[++i];
      if (n >= 0x30 && n <= 0x37) {
        var v = n - 0x30;
        for (var k = 0; k < 2 && i + 1 < units.length; k++) {
          final d = units[i + 1];
          if (d < 0x30 || d > 0x37) break;
          v = v * 8 + (d - 0x30);
          i++;
        }
        out.add(v & 0xFF);
      } else {
        out.add(_simpleEscapes[n] ?? n);
      }
    }
    return utf8.decode(out, allowMalformed: true);
  }

  static const Map<int, int> _simpleEscapes = {
    0x6E: 0x0A,
    0x74: 0x09,
    0x72: 0x0D,
    0x61: 0x07,
    0x62: 0x08,
    0x66: 0x0C,
    0x76: 0x0B,
  };

  /// 空檔新增／刪除沒有 `---`／`+++`，只能由 `diff --git` 行取路徑
  /// （`--no-renames` 且固定前綴，兩側路徑相同）。
  String? _pathFromDiffGit(String line) {
    final rest = line.substring(_diffGitPrefix.length);
    if (rest.startsWith('"')) {
      final end = _closingQuote(rest);
      return end < 0 ? null : _stripSide(rest.substring(0, end + 1), 'a');
    }
    final n = (rest.length - 5) ~/ 2;
    if (n <= 0 || rest.length != 2 * n + 5) return null;
    return rest.substring(2, 2 + n);
  }

  int _closingQuote(String s) {
    for (var i = 1; i < s.length; i++) {
      if (s[i] == r'\') {
        i++;
      } else if (s[i] == '"') {
        return i;
      }
    }
    return -1;
  }

  // ---- 條目與 hunk ----

  void _openEntry(String oldPath, String newPath) {
    _entryHasPaths = true;
    _pendingOld = null;
    final isNew = oldPath == _devNull;
    final isDeleted = newPath == _devNull;
    final path = isDeleted ? oldPath : newPath;
    _entryPath = _isMarkdown(path) ? path : null;
    if (_entryPath == null) return;
    _entryTouch = isNew ? _createFile(path) : _touchExisting(path);
    if (isDeleted) _entryTouch?.deleted = true;
  }

  bool _isMarkdown(String path) => path.endsWith('.md');

  _Touch _createFile(String path) {
    final old = _states[path];
    if (old != null) _trackedChars -= _charsOf(old.lines);
    final state = _FileState();
    _states[path] = state;
    final touch = _Touch(before: null, state: state)..created = true;
    _touched[path] = touch;
    return touch;
  }

  _Touch? _touchExisting(String path) {
    final state = _states[path];
    if (state == null) {
      _markDesync(path);
      _states[path] = _FileState()..desynced = true;
      return null;
    }
    return _touched.putIfAbsent(
      path,
      () => _Touch(before: state.declText, state: state),
    );
  }

  void _closeEntry() {
    final path = _diffGitPath;
    if (!_entryHasPaths && path != null && _isMarkdown(path)) {
      if (_entryNew) {
        _createFile(path);
      } else if (_entryDeleted) {
        _touchExisting(path)?.deleted = true;
      }
    }
    _diffGitPath = null;
    _entryNew = false;
    _entryDeleted = false;
    _entryHasPaths = false;
    _pendingOld = null;
    _entryPath = null;
    _entryTouch = null;
  }

  void _beginHunk(String line) {
    final m = _hunkHeader.firstMatch(line);
    if (m == null) return;
    _hunkOldStart = int.parse(m[1]!);
    _hunkOldCount = int.parse(m[2] ?? '1');
    _hunkNewStart = int.parse(m[3]!);
    _hunkNewCount = int.parse(m[4] ?? '1');
    _oldRemain = _hunkOldCount;
    _newRemain = _hunkNewCount;
    _hunkOld = [];
    _hunkNew = [];
    if (_oldRemain == 0 && _newRemain == 0) _applyHunk();
  }

  void _consumeHunkLine(String line) {
    final tag = line.isEmpty ? ' ' : line[0];
    final content = line.isEmpty ? '' : line.substring(1);
    if (tag == r'\') return;
    if (tag == '-') {
      _oldRemain--;
      _hunkOld.add(content);
    } else if (tag == '+') {
      _newRemain--;
      _hunkNew.add(content);
    } else {
      _oldRemain--;
      _newRemain--;
      _hunkOld.add(content);
      _hunkNew.add(content);
    }
    if (_oldRemain <= 0 && _newRemain <= 0) {
      _oldRemain = 0;
      _newRemain = 0;
      _applyHunk();
    }
  }

  void _applyHunk() {
    final path = _entryPath;
    final touch = _entryTouch;
    if (path == null || touch == null) return;
    final state = touch.state;
    if (state.desynced) return;
    final index = _hunkNewCount == 0 ? _hunkNewStart : _hunkNewStart - 1;
    if (!_oldSideMatches(state.lines, index)) {
      _markDesync(path);
      state.desynced = true;
      return;
    }
    state.lines.replaceRange(index, index + _hunkOld.length, _hunkNew);
    _trackedChars += _charsOf(_hunkNew) - _charsOf(_hunkOld);
    if (_trackedChars > peakTrackedChars) peakTrackedChars = _trackedChars;
    touch.hunkStarts.add(
      _hunkOldCount == 0 ? _hunkOldStart + 1 : _hunkOldStart,
    );
  }

  bool _oldSideMatches(List<String> lines, int index) {
    if (index < 0 || index + _hunkOld.length > lines.length) return false;
    for (var i = 0; i < _hunkOld.length; i++) {
      if (lines[index + i] != _hunkOld[i]) return false;
    }
    return true;
  }

  int _charsOf(List<String> lines) {
    var n = 0;
    for (final l in lines) {
      n += l.length;
    }
    return n;
  }

  void _markDesync(String path) {
    counters.desyncs++;
    logSink?.call(
      ParseLogLevel.warning,
      'history.scan.desync path=$path commit=${_commit?.id ?? ''}',
    ); // i18n-exempt: 日誌
  }

  // ---- commit 結算與 frontmatter ----

  void _finishCommit(List<ScanCommitResult> done) {
    _closeEntry();
    final commit = _commit;
    if (commit == null) return;
    final changes = <PathChange>[];
    _touched.forEach((path, touch) {
      final change = _settle(path, touch);
      if (change != null) changes.add(change);
    });
    done.add(ScanCommitResult(commit, changes));
    _touched = {};
    _commit = null;
  }

  PathChange? _settle(String path, _Touch touch) {
    final state = touch.state;
    if (state.desynced) return null;
    if (touch.deleted) {
      _trackedChars -= _charsOf(state.lines);
      _states.remove(path);
      return PathChange(
        path: path,
        before: touch.before,
        after: null,
        created: false,
        deleted: true,
      );
    }
    _refreshDeclaration(path, touch);
    final after = state.declText;
    if (!touch.created && after == touch.before) return null;
    return PathChange(
      path: path,
      before: touch.before,
      after: after,
      created: touch.created,
      deleted: false,
    );
  }

  void _refreshDeclaration(String path, _Touch touch) {
    final state = touch.state;
    if (_canSkipReparse(touch)) return;
    final range = _frontmatterRange(state.lines);
    state.frontmatterEnd = range;
    if (range == null) {
      state.declText = null;
      return;
    }
    final text = state.lines.sublist(1, range - 1).map(_stripCr).join('\n');
    counters.yamlParses++;
    if (_parseCheck(text)) {
      state.declText = text;
      return;
    }
    counters.unparsableVersions++;
    logSink?.call(
      ParseLogLevel.debug,
      'history.scan.unparsable path=$path commit=${_commit?.id ?? ''}',
    ); // i18n-exempt: 日誌
  }

  /// 效能捷徑（規則 6）：全部 hunk 都落在上次 frontmatter 結束行之後。
  bool _canSkipReparse(_Touch touch) {
    final end = touch.state.frontmatterEnd;
    if (touch.created || end == null) return false;
    return touch.hunkStarts.every((s) => s > end);
  }

  /// 回傳結尾 `---` 的 1-based 行號；沒有 frontmatter 回傳 null。
  int? _frontmatterRange(List<String> lines) {
    if (lines.isEmpty || _stripCr(lines[0]) != _fmFence) return null;
    for (var i = 1; i < lines.length; i++) {
      if (_stripCr(lines[i]) == _fmFence) return i + 1;
    }
    return null;
  }

  String _stripCr(String l) =>
      l.endsWith('\r') ? l.substring(0, l.length - 1) : l;

  static bool _defaultParseCheck(String text) {
    try {
      loadYaml(text);
      return true;
    } on YamlException {
      return false;
    }
  }
}
