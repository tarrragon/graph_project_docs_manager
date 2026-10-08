/// 需求：[SPEC-006 FR-09] 從 UC 本文取出第一個合法 flow 區塊的步驟清單，
/// 並判定是否有 flow 區塊解析失敗（EVT-CORPUS-004 的發送條件）。
///
/// 區塊判準對齊框架 `uc_registry.py` 的 `_extract_structured_flow_steps`：
/// 以 trim 後等於 ```` ```yaml ```` 的行開啟、等於 ```` ``` ```` 的行關閉。
library;

import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import 'frontmatter_classifier.dart';

const _fenceOpen = '```yaml';
const _fenceClose = '```';

/// 規則 3b (a)：區塊內行首（無縮排）以此開頭即判為 flow 區塊（文字層判定）。
const _topLevelFlowKeyPrefix = 'flow:';

/// 需求：[SPEC-006 FR-09 規則 3a] flow 區塊解析失敗的原因碼（EVT-CORPUS-004
/// 的 `reason`）；與 `nonDomainPathsMalformed` 同一命名慣例。
const flowBlockMalformedReasonCode = 'flowBlockMalformed';

/// 一份 UC 本文的 flow 擷取結果。
class UcFlowExtraction {
  const UcFlowExtraction({
    required this.steps,
    required this.hasMalformedFlowBlock,
  });

  /// 第一個合法 flow 區塊的步驟（原始順序，每步為區塊中該項的完整 map）；
  /// 找不到時為空清單。
  final List<Map<String, dynamic>> steps;

  /// 任一含頂層 `flow:` 行的區塊 YAML 解析失敗（不論後方是否另有合法區塊）。
  final bool hasMalformedFlowBlock;
}

/// 需求：[SPEC-006 FR-09 規則 1～5、3a、3b] 擷取 [bytes] 的 flow 資訊。
UcFlowExtraction extractUcFlow(Uint8List bytes) {
  final body = bodyLinesAfterFrontmatter(bytes) ?? const <String>[];
  var steps = const <Map<String, dynamic>>[];
  var foundValid = false;
  var malformed = false;
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
    final outcome = _evaluateBlock(fenceLines);
    malformed = malformed || outcome.malformed;
    final blockSteps = outcome.steps;
    if (!foundValid && blockSteps != null) {
      foundValid = true;
      steps = blockSteps;
    }
  }
  return UcFlowExtraction(steps: steps, hasMalformedFlowBlock: malformed);
}

({List<Map<String, dynamic>>? steps, bool malformed}) _evaluateBlock(
  List<String> blockLines,
) {
  final isFlowBlock = blockLines.any(
    (line) => line.startsWith(_topLevelFlowKeyPrefix),
  );
  Object? parsed;
  try {
    parsed = loadYaml(blockLines.join('\n'));
  } on YamlException {
    return (steps: null, malformed: isFlowBlock);
  }
  if (parsed is! YamlMap) {
    return (steps: null, malformed: false);
  }
  final flow = parsed['flow'];
  if (flow is! YamlList || flow.isEmpty) {
    return (steps: null, malformed: false);
  }
  return (steps: _stepMaps(flow), malformed: false);
}

/// 每步保存完整 map；非 map 的清單項不是 FlowStep，不納入（規則 5 不檢查
/// 欄位完整性，但清單項本身須是 map 才有「該步的完整 map」可保存）。
List<Map<String, dynamic>> _stepMaps(YamlList flow) {
  return List.unmodifiable([
    for (final item in flow)
      if (item is YamlMap) toPlainYamlValue(item) as Map<String, dynamic>,
  ]);
}
