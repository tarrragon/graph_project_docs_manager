/// 需求：[SPEC-006 FR-09] 從 UC 本文取出第一個合法 flow 區塊的步驟清單，
/// 並判定是否有 flow 區塊解析失敗（EVT-CORPUS-004 的發送條件）。
///
/// 區塊判準對齊框架 `uc_registry.py` 的 `_extract_structured_flow_steps`：
/// 以 trim 後等於 ```` ```yaml ```` 的行開啟、等於 ```` ``` ```` 的行關閉。
library;

import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import 'frontmatter_classifier.dart';

const _tag = 'corpus.uc_flow_extractor';
const _fenceOpen = '```yaml';
const _fenceClose = '```';

/// 規則 3b (a)：區塊內行首（無縮排）以此開頭即判為 flow 區塊（文字層判定）。
const _topLevelFlowKeyPrefix = 'flow:';

/// 需求：[SPEC-006 FR-09 規則 3a] flow 區塊解析失敗的原因碼（EVT-CORPUS-004
/// 的 `reason`）；與 `nonDomainPathsMalformed` 同一命名慣例。
const flowBlockMalformedReasonCode = 'flowBlockMalformed';

// i18n-exempt: 事件負載資料值，非 UI 顯示字串
const flowNonMapItemReasonNote = 'flow 清單含非 map 項目';

// i18n-exempt: 事件負載資料值，非 UI 顯示字串
const flowSyntaxReasonNote = 'flow 區塊語法錯誤或圍欄未閉合';

// i18n-exempt: 事件負載資料值，非 UI 顯示字串
const flowUnexpectedErrorReasonNote = 'flow 擷取發生非預期例外';

/// 一份 UC 本文的 flow 擷取結果。
class UcFlowExtraction {
  const UcFlowExtraction({
    required this.steps,
    required this.hasMalformedFlowBlock,
    this.hasNonMapFlowItem = false,
    this.unexpectedErrorSummary,
  });

  /// 規則 3a：擷取時發生 YAML 解析例外以外的非預期例外時的例外摘要
  /// （此時 [hasMalformedFlowBlock] 亦為 true，步驟為空）；否則為 null。
  final String? unexpectedErrorSummary;

  /// 規則 3c：合格 flow 區塊的清單內有非 map 項目（該項已略過）。
  final bool hasNonMapFlowItem;

  /// 第一個合法 flow 區塊的步驟（原始順序，每步為區塊中該項的完整 map）；
  /// 找不到時為空清單。
  final List<Map<String, dynamic>> steps;

  /// 任一含頂層 `flow:` 行的區塊 YAML 解析失敗（不論後方是否另有合法區塊）。
  /// 含擷取時的非預期例外，以 `unexpectedErrorSummary != null` 區分。
  final bool hasMalformedFlowBlock;
}

/// 需求：[SPEC-006 FR-09 規則 1～5、3a、3b] 擷取 [bytes] 的 flow 資訊。
/// [path] 只用於日誌（YAML 解析失敗時帶出 UC 路徑）。
UcFlowExtraction extractUcFlow(Uint8List bytes, String path) {
  final body = bodyLinesAfterFrontmatter(bytes) ?? const <String>[];
  var steps = const <Map<String, dynamic>>[];
  var foundValid = false;
  var malformed = false;
  var nonMapItem = false;
  var inFence = false;
  var fenceLines = <String>[];

  for (final line in body) {
    final stripped = line.trim();
    if (!inFence) {
      if (stripped == _fenceOpen) {
        inFence = true;
        fenceLines = <String>[];
      }
      continue;
    }
    if (stripped != _fenceClose) {
      fenceLines.add(line);
      continue;
    }
    inFence = false;
    final outcome = _evaluateBlock(fenceLines, path);
    malformed = malformed || outcome.malformed;
    nonMapItem = nonMapItem || outcome.nonMapItem;
    final blockSteps = outcome.steps;
    if (!foundValid && blockSteps != null) {
      foundValid = true;
      steps = blockSteps;
    }
  }
  // 規則 3d：本文結尾未閉合的圍欄，含頂層 flow: 行即判為壞掉的 flow 區塊，
  // 不解析、不採用其步驟。
  if (inFence && _hasTopLevelFlowKey(fenceLines)) {
    developer.log(
      // i18n-exempt: 開發者 debug log
      'UC 本文結尾有未閉合的 yaml 圍欄且含頂層 flow: 行，視為壞掉的 flow 區塊：$path',
      name: _tag,
      level: 900,
    );
    malformed = true;
  }
  return UcFlowExtraction(
    steps: steps,
    hasMalformedFlowBlock: malformed,
    hasNonMapFlowItem: nonMapItem,
  );
}

bool _hasTopLevelFlowKey(List<String> lines) =>
    lines.any((line) => line.startsWith(_topLevelFlowKeyPrefix));

({List<Map<String, dynamic>>? steps, bool malformed, bool nonMapItem})
_evaluateBlock(List<String> blockLines, String path) {
  final isFlowBlock = blockLines.any(
    (line) => line.startsWith(_topLevelFlowKeyPrefix),
  );
  Object? parsed;
  try {
    parsed = loadYaml(blockLines.join('\n'));
  } on YamlException catch (e) {
    developer.log(
      // i18n-exempt: 開發者 debug log
      'UC 的 yaml 區塊解析失敗，略過該區塊（flow 區塊判定=$isFlowBlock）：$path',
      name: _tag,
      level: 900,
      error: e,
    );
    return (steps: null, malformed: isFlowBlock, nonMapItem: false);
  }
  if (parsed is! YamlMap) {
    return (steps: null, malformed: false, nonMapItem: false);
  }
  final flow = parsed['flow'];
  if (flow is! YamlList || flow.isEmpty) {
    return (steps: null, malformed: false, nonMapItem: false);
  }
  final steps = _stepMaps(flow);
  return (
    steps: steps,
    malformed: false,
    nonMapItem: steps.length != flow.length,
  );
}

/// 每步保存完整 map；非 map 的清單項略過（規則 3c，呼叫端另行發 004）。
List<Map<String, dynamic>> _stepMaps(YamlList flow) {
  return List.unmodifiable([
    for (final item in flow)
      if (item is YamlMap) toPlainYamlValue(item) as Map<String, dynamic>,
  ]);
}
