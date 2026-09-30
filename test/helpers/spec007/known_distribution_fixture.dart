/// 分布已知 fixture 與內建型別表載入（SPEC-007 測試設計 §1.4）。
///
/// 計數皆為手算，寫在 [KnownDistribution] 內；本票只涵蓋節點、
/// `duplicateId` 與 FR-03 三類計數，邊數與 `multiSource` 由 W2-004 擴充。
library;

import 'dart:convert';
import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import 'raw_node_builder.dart';

/// 讀內建型別表 asset，回傳可修改的新解碼副本。
Map<String, dynamic> loadBuiltinSchemaJson() {
  final file = File('assets/schema/builtin_tracking_schema.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
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
