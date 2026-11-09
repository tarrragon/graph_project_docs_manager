// SPEC-008 測試設計 §1.4：合成 `git log -p` 輸出與 frontmatter 文字建構器。
// 只產生位元組序列，不啟動 git。hunk 的 `@@` 行數由建構器自動計算。
import 'dart:convert';

/// 檔案行：String 以 UTF-8 編碼；`List<int>` 原樣寫入（供非 UTF-8 案例）。
typedef LogLine = Object;

List<int> _lineBytes(LogLine line) =>
    line is String ? utf8.encode(line) : List<int>.from(line as List<int>);

/// 產生 frontmatter 檔案全文行序列（含前後 `---`），清單值為 block 形式。
List<String> frontmatterLines(
  Map<String, Object?> fields, {
  List<String> body = const [],
  String eol = '',
}) {
  final lines = <String>['---'];
  fields.forEach((key, value) {
    if (value is List) {
      lines.add('$key:');
      for (final item in value) {
        lines.add('  - $item');
      }
    } else {
      lines.add('$key: $value');
    }
  });
  lines.add('---');
  lines.addAll(body);
  return lines.map((l) => '$l$eol').toList();
}

/// 一個檔案條目（`diff --git` 起到下一個條目之前）。
class LogFileEntry {
  LogFileEntry._(this._build);

  final List<List<int>> Function() _build;

  List<List<int>> render() => _build();

  /// 新增檔；`lines` 為空時依 git 行為不輸出 `---`／`+++`／hunk。
  factory LogFileEntry.added(
    String path,
    List<LogLine> lines, {
    String? pathText,
    bool noEol = false,
  }) {
    return LogFileEntry._(() {
      final out = <List<int>>[
        _s('diff --git a/$path b/$path'),
        _s('new file mode 100644'),
      ];
      if (lines.isEmpty) {
        out.add(_s('index 0000000..e69de29'));
        return out;
      }
      out.add(_s('index 0000000..1111111'));
      out.add(_s('--- /dev/null'));
      out.add(_s('+++ ${_side('b', pathText ?? path)}'));
      out.add(_s('@@ -0,0 +1,${lines.length} @@'));
      for (var i = 0; i < lines.length; i++) {
        out.add([0x2B, ..._lineBytes(lines[i])]);
        if (noEol && i == lines.length - 1) out.add(_noEol());
      }
      return out;
    });
  }

  /// 刪除檔；`lines` 為空時不輸出 `---`／`+++`／hunk。
  factory LogFileEntry.deleted(String path, List<LogLine> lines) {
    return LogFileEntry._(() {
      final out = <List<int>>[
        _s('diff --git a/$path b/$path'),
        _s('deleted file mode 100644'),
      ];
      if (lines.isEmpty) {
        out.add(_s('index e69de29..0000000'));
        return out;
      }
      out.add(_s('index 1111111..0000000'));
      out.add(_s('--- a/$path'));
      out.add(_s('+++ /dev/null'));
      out.add(_s('@@ -1,${lines.length} +0,0 @@'));
      for (final l in lines) {
        out.add([0x2D, ..._lineBytes(l)]);
      }
      return out;
    });
  }

  /// 修改檔；以共同前後綴算出單一 hunk，前後各帶 `context` 行上下文。
  factory LogFileEntry.modified(
    String path, {
    required List<LogLine> before,
    required List<LogLine> after,
    int context = 3,
    String? pathText,
    bool noEolBefore = false,
    bool noEolAfter = false,
  }) {
    return LogFileEntry._(() {
      final shown = pathText ?? path;
      final out = <List<int>>[
        _s('diff --git a/$path b/$path'),
        _s('index 1111111..2222222 100644'),
        _s('--- ${_side('a', shown)}'),
        _s('+++ ${_side('b', shown)}'),
      ];
      out.addAll(_hunk(before, after, context, noEolBefore, noEolAfter));
      return out;
    });
  }

  /// 只改 mode，無 hunk。
  factory LogFileEntry.modeOnly(String path) {
    return LogFileEntry._(
      () => [
        _s('diff --git a/$path b/$path'),
        _s('old mode 100644'),
        _s('new mode 100755'),
      ],
    );
  }

  /// 二進位條目。
  factory LogFileEntry.binary(String path) {
    return LogFileEntry._(
      () => [
        _s('diff --git a/$path b/$path'),
        _s('index 1111111..2222222 100644'),
        _s('Binary files a/$path and b/$path differ'),
      ],
    );
  }
}

List<int> _s(String text) => utf8.encode(text);

/// git 的路徑側：C-style 引號時整個含前綴的字串放進引號內。
String _side(String prefix, String path) =>
    path.startsWith('"') ? '"$prefix/${path.substring(1)}' : '$prefix/$path';

List<int> _noEol() => _s(r'\ No newline at end of file');

List<List<int>> _hunk(
  List<LogLine> before,
  List<LogLine> after,
  int context,
  bool noEolBefore,
  bool noEolAfter,
) {
  final bl = before.length;
  final al = after.length;
  var p = 0;
  while (p < bl && p < al && _same(before[p], after[p])) {
    p++;
  }
  var s = 0;
  while (s < bl - p &&
      s < al - p &&
      _same(before[bl - 1 - s], after[al - 1 - s])) {
    s++;
  }
  final start = p - context < 0 ? 0 : p - context;
  final endOld = bl - s + context > bl ? bl : bl - s + context;
  final endNew = al - s + context > al ? al : al - s + context;
  final oldCount = endOld - start;
  final newCount = endNew - start;
  final a = oldCount == 0 ? start : start + 1;
  final c = newCount == 0 ? start : start + 1;
  final out = <List<int>>[_s('@@ -$a,$oldCount +$c,$newCount @@')];
  for (var i = start; i < p; i++) {
    out.add([0x20, ..._lineBytes(before[i])]);
  }
  for (var i = p; i < bl - s; i++) {
    out.add([0x2D, ..._lineBytes(before[i])]);
    if (noEolBefore && i == bl - 1) out.add(_noEol());
  }
  for (var i = p; i < al - s; i++) {
    out.add([0x2B, ..._lineBytes(after[i])]);
    if (noEolAfter && i == al - 1) out.add(_noEol());
  }
  for (var i = bl - s; i < endOld; i++) {
    out.add([0x20, ..._lineBytes(before[i])]);
    if (noEolBefore && i == bl - 1) out.add(_noEol());
  }
  return out;
}

bool _same(LogLine a, LogLine b) => a is String && b is String
    ? a == b
    : _lineBytes(a).join(',') == _lineBytes(b).join(',');

/// 以宣告方式組出整份 `git log -p` 輸出。
class SyntheticLogBuilder {
  final List<List<int>> _lines = [];

  /// 附加一個主線 commit；標頭以 U+001E 開頭、U+0000 分隔。
  SyntheticLogBuilder commit(
    String id, {
    List<String> parents = const [],
    int time = 1700000000,
    String author = 'tester',
    String subject = 'subject',
    List<LogFileEntry> files = const [],
  }) {
    _lines.add(
      _s(
        '\u001e$id\u0000${parents.join(' ')}\u0000$time\u0000'
        '$author\u0000$subject',
      ),
    );
    if (files.isNotEmpty) _lines.add(const []);
    for (final f in files) {
      _lines.addAll(f.render());
    }
    return this;
  }

  /// 整份輸出位元組（每行以 LF 結尾）。
  List<int> toBytes() {
    final out = <int>[];
    for (final l in _lines) {
      out
        ..addAll(l)
        ..add(0x0A);
    }
    return out;
  }

  /// 依固定大小切段（段界可落在多位元組字元與行中間）。
  List<List<int>> toChunks(int size) {
    final all = toBytes();
    return [
      for (var i = 0; i < all.length; i += size)
        all.sublist(i, i + size > all.length ? all.length : i + size),
    ];
  }
}
