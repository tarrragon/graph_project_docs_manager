/// 需求：[SPEC-006-test-design.md §1.4／§2.2〈實體化流程〉；SPEC-006
/// D3 的展開] IT-2 凍結 manifest 的解析與實體化 helper。
///
/// 只負責「把 manifest 列寫成暫存目錄下的真實檔案」，不涉及掃描或分類
/// 邏輯（那是待測的 [scanCorpus] 職責，本檔不 import 它）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// manifest 列的 `shape` 欄（test-design §2.2〈manifest 列欄位〉六種值域
/// 之一）。未知字串一律拋錯，不靜默略過（IT2-A4 守衛的依據）。
enum ManifestRowShape {
  usable,
  noFrontmatter,
  unclosed,
  emptyOrNonMap,
  yamlError,
  unreadableEncoding;

  static ManifestRowShape fromJson(String value) => switch (value) {
    'usable' => ManifestRowShape.usable,
    'no_frontmatter' => ManifestRowShape.noFrontmatter,
    'unclosed' => ManifestRowShape.unclosed,
    'empty_or_non_map' => ManifestRowShape.emptyOrNonMap,
    'yaml_error' => ManifestRowShape.yamlError,
    'unreadable_encoding' => ManifestRowShape.unreadableEncoding,
    _ => throw ArgumentError('未知的 manifest shape：$value'),
  };
}

/// 一列 manifest 的預期分類（`expected` 欄）。
class ManifestExpected {
  const ManifestExpected({
    required this.kind,
    this.nodeType,
    required this.candidateTypes,
    required this.schemaAmbiguous,
    this.reason,
  });

  /// `node`／`non_node`／`gap`／`failure_unmatched` 四類之一。
  final String kind;

  /// 命中一型時的型別名；平手或非節點時為 `null`。
  final String? nodeType;

  /// 平手時的候選型別清單；其餘情形為空清單。
  final List<String> candidateTypes;

  /// 平手時為 `true`。
  final bool schemaAmbiguous;

  /// 失敗檔的原因（與 [ManifestRowShape] 同款詞彙）；可用檔為 `null`。
  final String? reason;

  factory ManifestExpected.fromJson(Map<String, dynamic> json) =>
      ManifestExpected(
        kind: json['kind'] as String,
        nodeType: json['node_type'] as String?,
        candidateTypes: (json['candidate_types'] as List)
            .cast<String>(),
        schemaAmbiguous: json['schema_ambiguous'] as bool,
        reason: json['reason'] as String?,
      );
}

/// 一列 manifest。
class ManifestRow {
  const ManifestRow({
    required this.path,
    required this.project,
    required this.shape,
    this.id,
    required this.expected,
    required this.synthetic,
  });

  /// 帶 `<專案>/<相對路徑>` 前綴的完整路徑；`project` 為 `synthetic` 時
  /// 本身已是相對路徑（`docs/...`），見
  /// `test/fixtures/spec006/README.md`〈test/fixtures/spec006/it2/
  /// manifest.json〉一節。
  final String path;

  final String project;

  final ManifestRowShape shape;

  /// `shape: usable` 時可能寫入的 `id`；`null` 代表不寫 `id` 鍵（或由
  /// 實體化器依 [expected] 合成，見 [kSyntheticNodeIds]）。
  final String? id;

  final ManifestExpected expected;

  final bool synthetic;

  /// 相對於該 `project` 專屬工作區根目錄的路徑（掃描器一次只掃一個
  /// 工作區的 `docs/`，`path` 欄帶的專案前綴必須先去除；`synthetic`
  /// 專案的 [path] 本身已相對，不需去除）。
  String get relativePath =>
      project == 'synthetic' ? path : path.substring(project.length + 1);

  factory ManifestRow.fromJson(Map<String, dynamic> json) => ManifestRow(
    path: json['path'] as String,
    project: json['project'] as String,
    shape: ManifestRowShape.fromJson(json['shape'] as String),
    id: json['id'] as String?,
    expected: ManifestExpected.fromJson(
      json['expected'] as Map<String, dynamic>,
    ),
    synthetic: json['synthetic'] as bool,
  );
}

/// 整份凍結 manifest（`header` + `rows`）。
class Manifest {
  const Manifest({required this.header, required this.rows});

  /// 檔頭：凍結日期、型別表、FR-07 預期計數等（見
  /// `test/fixtures/spec006/README.md`）。
  final Map<String, dynamic> header;

  final List<ManifestRow> rows;

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
    header: json['header'] as Map<String, dynamic>,
    rows: (json['rows'] as List)
        .map((e) => ManifestRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  static Manifest load(String path) => Manifest.fromJson(
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  );

  /// 依 `project` 分組（含 `synthetic`）；掃描器一次只掃一個工作區，
  /// 每個 `project` 需要獨立的暫存工作區根。
  Map<String, List<ManifestRow>> get rowsByProject {
    final map = <String, List<ManifestRow>>{};
    for (final row in rows) {
      map.putIfAbsent(row.project, () => <ManifestRow>[]).add(row);
    }
    return map;
  }
}

/// `shape: usable` 且 `expected.kind == 'node'` 時，manifest 未保留真實
/// `id`（見 README〈與第一版的差異〉，7466 個真實列不內嵌原始位元組以
/// 控制體積），本 helper 為每個具路徑模式的節點型別合成一個確定會恰好
/// 命中該型 `id_pattern`、且不與型別表中任何其他型別（含兩個測試專用
/// 合成型別）的 `id_pattern` 衝突的 `id`（已逐型別對 9 個 `id_pattern`
/// 交叉驗證，見票面回報）。
const kSyntheticNodeIds = <String, String>{
  'DomainBundle': 'DOMAIN-MAP-test',
  'EVT': 'EVT-TEST-001',
  'FlowStep': 'flow-step-test',
  'PROP': 'PROP-001',
  'SPEC': 'SPEC-001',
  'Ticket': '0.1.0-W1-001',
  'UC': 'UC-01',
};

/// 需求：[SPEC-006-test-design.md §2.2〈實體化流程〉] 依 [rows] 在
/// [workspaceRoot] 下依 `shape` 寫出真實檔案；`shape` 未知時已在
/// [ManifestRow.fromJson] 拋錯（IT2-A4 守衛），本函式不再重複判斷。
Future<void> materializeManifestRows({
  required List<ManifestRow> rows,
  required Directory workspaceRoot,
}) async {
  for (final row in rows) {
    final file = File('${workspaceRoot.path}/${row.relativePath}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(_bytesFor(row));
  }
}

Uint8List _bytesFor(ManifestRow row) {
  switch (row.shape) {
    case ManifestRowShape.usable:
      return utf8.encode(_usableFrontmatter(row));
    case ManifestRowShape.noFrontmatter:
      // i18n-exempt: 測試 fixture 實體化內容，非 UI 顯示字串
      return utf8.encode('# 純 markdown\n\n無 frontmatter 的內容。\n');
    case ManifestRowShape.unclosed:
      // i18n-exempt: 測試 fixture 實體化內容，非 UI 顯示字串
      return utf8.encode('---\ntitle: 未閉合\n');
    case ManifestRowShape.emptyOrNonMap:
      return utf8.encode('---\n---\n');
    case ManifestRowShape.yamlError:
      // 與 C1-5 同款觸發字串：未閉合的引號字串。
      // i18n-exempt: 測試 fixture 實體化內容，非 UI 顯示字串
      return utf8.encode('---\ntitle: "unterminated\n---\n');
    case ManifestRowShape.unreadableEncoding:
      // 單一無效 UTF-8 位元組（0xFF 不是任何合法 UTF-8 序列的起始位元組）。
      return Uint8List.fromList(const [0xff, 0xfe, 0x00]);
  }
}

String _usableFrontmatter(ManifestRow row) {
  final buffer = StringBuffer('---\n');
  final explicitId = row.id;
  if (explicitId != null) {
    buffer.writeln('id: $explicitId'); // i18n-exempt: 測試 fixture YAML 內容
  } else if (row.expected.kind == 'node') {
    final nodeType = row.expected.nodeType;
    final syntheticId = nodeType == null ? null : kSyntheticNodeIds[nodeType];
    if (syntheticId == null) {
      throw StateError(
        // i18n-exempt: 開發期例外訊息，非 UI 顯示字串
        '節點型別 $nodeType 沒有對應的合成 id（kSyntheticNodeIds 未涵蓋）：${row.path}',
      );
    }
    buffer.writeln('id: $syntheticId'); // i18n-exempt: 測試 fixture YAML 內容
  }
  buffer.writeln('title: 測試'); // i18n-exempt: 測試 fixture YAML 內容
  buffer.writeln('---');
  return buffer.toString();
}
