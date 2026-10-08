/// 分布已知 fixture 與內建型別表載入（SPEC-007 測試設計 §1.4）。
///
/// 計數皆為手算，寫在 [KnownDistribution] 內；本票只涵蓋節點、
/// `duplicateId` 與 FR-03 三類計數，邊數與 `multiSource` 由 W2-004 擴充。
library;

import 'dart:convert';
import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import 'raw_node_builder.dart';

/// 讀內建型別表 asset，回傳可修改的新解碼副本。
Map<String, dynamic> loadBuiltinSchemaJson() {
  final file = File('assets/schema/builtin_tracking_schema.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// 內建表副本，全部邊型移除 `direction` 欄（S6-14 的專案表）。
Map<String, dynamic> loadBuiltinSchemaJsonWithoutDirection() {
  final table = loadBuiltinSchemaJson();
  for (final edge in (table['edge_types'] as Map<String, dynamic>).values) {
    (edge as Map<String, dynamic>).remove('direction');
  }
  return table;
}

/// 由型別表 JSON 取得建圖輸入（使用中邊型與節點型別表）。
///
/// [schemaJson] 缺省為內建表；內建表恆作為版本基準（不會落入不可用）。
({List<EdgeTypeEntry> edgeTypes, Map<String, NodeTypeEntry> nodeTypes})
graphInputsFrom([Map<String, dynamic>? schemaJson]) {
  final builtin = loadBuiltinSchemaJson();
  final table = schemaJson ?? builtin;
  final resolution = resolveEdgeTypes(
    projectSchemaJson: table,
    builtinSchemaJson: builtin,
  );
  return (
    edgeTypes: resolution.activeEdgeTypes.toList(),
    nodeTypes: typeTableFromJson(table).nodeTypes,
  );
}

/// 一組 rawNodes 與其手算計數。
class KnownDistribution {
  const KnownDistribution({
    required this.rawNodes,
    required this.nodeCount,
    required this.duplicateIdCount,
    required this.totalReferences,
    required this.resolved,
    required this.dangling,
    required this.malformed,
  });

  final List<RawNode> rawNodes;
  final int nodeCount;
  final int duplicateIdCount;
  final int totalReferences;
  final int resolved;
  final int dangling;
  final int malformed;
}

/// 手算（內建型別表）：
///
/// - 0.1.0-W1-001：relatedTo 1（成功）、blockedBy 2（成功、`42` invalidShape）、
///   source_ticket 1（targetMissing）
/// - 0.1.0-W1-002：relatedTo 1（patternMismatch）、parent_id 1（selfReference）、
///   spawned_tickets 1（指向重複 ID，targetDuplicated）
/// - PROP-001：outputs.spec_refs 2（成功、targetMissing）、outputs.notes 1
///   （invalidShape）
/// - SPEC-001：source_proposal 1（成功），status 為數字
/// - 兩份 0.1.0-W1-005（重複 ID）：各帶 relatedTo，不計入
///
/// 總數 11 = 成功 4 + 斷邊 3 + 格式錯誤 4；節點 4；`duplicateId` 1。
KnownDistribution buildKnownDistribution() {
  return KnownDistribution(
    rawNodes: [
      buildRawNode(
        id: '0.1.0-W1-001',
        extra: {
          'relatedTo': ['0.1.0-W1-002'],
          'blockedBy': ['0.1.0-W1-002', 42],
          'source_ticket': '0.1.0-W9-999',
        },
      ),
      buildRawNode(
        id: '0.1.0-W1-002',
        extra: {
          'relatedTo': ['0.1.0-W1-001 0.1.0-W1-002'],
          'parent_id': '0.1.0-W1-002',
          'spawned_tickets': ['0.1.0-W1-005'],
        },
      ),
      buildRawNode(
        id: 'PROP-001',
        typeName: 'PROP',
        extra: {
          'outputs': {
            'spec_refs': ['SPEC-001', 'SPEC-404'],
            'notes': 'x',
          },
        },
      ),
      buildRawNode(
        id: 'SPEC-001',
        typeName: 'SPEC',
        extra: {
          'status': 3,
          'source_proposal': ['PROP-001'],
        },
      ),
      buildRawNode(
        id: '0.1.0-W1-005',
        path: 'docs/dup-a.md',
        extra: {
          'relatedTo': ['0.1.0-W1-001'],
        },
      ),
      buildRawNode(
        id: '0.1.0-W1-005',
        path: 'docs/dup-b.md',
        extra: {
          'relatedTo': ['0.1.0-W1-001'],
        },
      ),
    ],
    nodeCount: 4,
    duplicateIdCount: 1,
    totalReferences: 11,
    resolved: 4,
    dangling: 3,
    malformed: 4,
  );
}

/// 擴充的分布已知 fixture（W2-004）：在 [buildKnownDistribution] 的 rawNodes
/// 之後加五個節點，涵蓋僅終點、兩端、`multiSource`、無向兩端。
///
/// 既有 [KnownDistribution] 計數常數不動（G1～G3 依賴）；本類計數為整組
/// rawNodes 的手算值：
///
/// - 基準邊 3：`association {W1-001,W1-002}` 一端、`blocking W1-001→W1-002`
///   僅起點、`provenance SPEC-001→PROP-001` 兩端
/// - 新增邊 5：`spawn W2-002→W2-001` 兩端、`spawn W2-003→W2-001` 僅終點、
///   `spawn W2-004→W2-001` 僅起點、`spawn W2-004→W2-005` 僅終點、
///   `association {W2-002,W2-003}` 兩端
/// - `multiSource`：W2-004（`spawn` 基數 one，兩終點）
class KnownGraphDistribution {
  const KnownGraphDistribution({
    required this.rawNodes,
    required this.nodeCount,
    required this.edgeCount,
    required this.edgesByType,
    required this.directedFromOnly,
    required this.directedToOnly,
    required this.directedBoth,
    required this.undirectedOneEnd,
    required this.undirectedBoth,
    required this.duplicateIdCount,
    required this.totalReferences,
    required this.resolved,
    required this.dangling,
    required this.malformed,
    required this.multiSourceCount,
    required this.graphDefectCount,
  });

  final List<RawNode> rawNodes;
  final int nodeCount;
  final int edgeCount;
  final Map<String, int> edgesByType;
  final int directedFromOnly;
  final int directedToOnly;
  final int directedBoth;
  final int undirectedOneEnd;
  final int undirectedBoth;
  final int duplicateIdCount;
  final int totalReferences;
  final int resolved;
  final int dangling;
  final int malformed;
  final int multiSourceCount;
  final int graphDefectCount;
}

KnownGraphDistribution buildKnownGraphDistribution() {
  return KnownGraphDistribution(
    rawNodes: [
      ...buildKnownDistribution().rawNodes,
      buildRawNode(
        id: '0.2.0-W1-001',
        extra: {
          'spawned_tickets': ['0.2.0-W1-002', '0.2.0-W1-003'],
        },
      ),
      buildRawNode(
        id: '0.2.0-W1-002',
        extra: {
          'source_ticket': '0.2.0-W1-001',
          'relatedTo': ['0.2.0-W1-003'],
        },
      ),
      buildRawNode(
        id: '0.2.0-W1-003',
        extra: {
          'relatedTo': ['0.2.0-W1-002'],
        },
      ),
      buildRawNode(
        id: '0.2.0-W1-004',
        extra: {'source_ticket': '0.2.0-W1-001'},
      ),
      buildRawNode(
        id: '0.2.0-W1-005',
        extra: {
          'spawned_tickets': ['0.2.0-W1-004'],
        },
      ),
    ],
    nodeCount: 9,
    edgeCount: 8,
    edgesByType: const {
      'association': 2,
      'blocking': 1,
      'provenance': 1,
      'spawn': 4,
    },
    directedFromOnly: 2,
    directedToOnly: 2,
    directedBoth: 2,
    undirectedOneEnd: 1,
    undirectedBoth: 1,
    duplicateIdCount: 1,
    totalReferences: 18,
    resolved: 11,
    dangling: 3,
    malformed: 4,
    multiSourceCount: 1,
    graphDefectCount: 9,
  );
}
