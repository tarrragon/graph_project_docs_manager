/// baseline 差集判定（SPEC-009 FR-05）：解讀 doc CLI 的結束碼與輸出，並以
/// 「寫入後的問題集合減去 baseline」判定 [ValidationStatus]。純函式，不做 IO。
library;

import 'package:graph_project_docs_manager/edit/write_result.dart';

/// 驗證器（`doc validate`、`doc uc verify`）。
enum ValidatorTool { docValidate, ucVerify }

/// 單一驗證器一次執行的解讀結果。
sealed class ToolOutcome {
  const ToolOutcome();
}

/// 結束碼 0：無問題。
final class ToolClean extends ToolOutcome {
  const ToolClean();
}

/// 結束碼 1：有問題；[issues] 為「識別值 → 出現次數」（不含行號與路徑）。
final class ToolIssues extends ToolOutcome {
  const ToolIssues(this.issues);

  final Map<String, int> issues;
}

/// 結束碼 2：驗證器無法定位或解析目標文件。
final class ToolUnreadable extends ToolOutcome {
  const ToolUnreadable();
}

/// 無法判定。
final class ToolUnavailable extends ToolOutcome {
  const ToolUnavailable(this.reason);

  final UnavailableReason reason;
}

final RegExp _ucLine = RegExp(r'^.+:\d+:(\S+)$');
final RegExp _validateLine = RegExp(r'^\s+-\s+(\S.*)$');
final RegExp _lineBreak = RegExp(r'\r?\n');

/// 需求：[SPEC-009 FR-05] CLI 結束碼對應：0 無問題；1 有問題（解析輸出取得
/// 問題集合，解析不出任何問題為 `unparsableOutput`）；2 無法定位或解析；
/// 其餘為 `unexpectedExitCode`。
///
/// 輸出樣本（2026-11-12 以真實 doc CLI 取得）：
/// `doc uc verify` 為「發現 N 處違規 UC 編號:」後逐行 `<路徑>:<行號>:<UC>`；
/// `doc validate` 為「驗證失敗: `<id>` 缺少以下項目」後逐行 `  - <問題>`。
ToolOutcome interpretToolOutput(
  ValidatorTool tool,
  int exitCode,
  String stdout,
) {
  switch (exitCode) {
    case 0:
      return const ToolClean();
    case 1:
      final issues = _parseIssues(tool, stdout);
      return issues.isEmpty
          ? const ToolUnavailable(UnavailableReason.unparsableOutput)
          : ToolIssues(issues);
    case 2:
      return const ToolUnreadable();
    default:
      return const ToolUnavailable(UnavailableReason.unexpectedExitCode);
  }
}

Map<String, int> _parseIssues(ValidatorTool tool, String stdout) {
  final pattern = tool == ValidatorTool.ucVerify ? _ucLine : _validateLine;
  final issues = <String, int>{};
  for (final line in stdout.split(_lineBreak)) {
    final key = pattern.firstMatch(line)?.group(1)?.trim();
    if (key != null) {
      final scoped = '${tool.name}:$key';
      issues[scoped] = (issues[scoped] ?? 0) + 1;
    }
  }
  return issues;
}

/// 一次量測的結果（開始編輯時的 baseline，或寫入後的問題集合）。
sealed class ValidationMeasure {
  const ValidationMeasure();
}

/// 兩個驗證器都有可比對的結果。
final class MeasureReady extends ValidationMeasure {
  const MeasureReady(this.outcomes);

  final Map<ValidatorTool, ToolOutcome> outcomes;
}

/// 無法判定。作為 baseline 時，該次編輯期間所有寫入的驗證皆為 `unavailable`。
final class MeasureUnavailable extends ValidationMeasure {
  const MeasureUnavailable(this.reason);

  final UnavailableReason reason;
}

/// 需求：[SPEC-009 FR-05] 任一驗證器無法判定即整體無法判定。
ValidationMeasure measureFromOutcomes(
  Map<ValidatorTool, ToolOutcome> outcomes,
) {
  for (final outcome in outcomes.values) {
    if (outcome is ToolUnavailable) {
      return MeasureUnavailable(outcome.reason);
    }
  }
  return MeasureReady(outcomes);
}

/// 需求：[SPEC-009 FR-05] 判定寫入後的狀態。baseline 無法判定或寫入後無法
/// 判定為 `unavailable`；否則逐驗證器計算差集：問題以識別值加次數比對，
/// 結束碼 2 在 baseline 已是 2 時視為既有問題，否則算 1 個新增問題。
ValidationStatus judgeAgainstBaseline(
  ValidationMeasure baseline,
  ValidationMeasure after,
) {
  if (baseline is MeasureUnavailable) {
    return ValidationUnavailable(baseline.reason);
  }
  if (after is MeasureUnavailable) {
    return ValidationUnavailable(after.reason);
  }
  final before = (baseline as MeasureReady).outcomes;
  final now = (after as MeasureReady).outcomes;
  var added = 0;
  for (final tool in ValidatorTool.values) {
    added += _newIssues(before[tool], now[tool]);
  }
  return added == 0 ? const ValidationPassed() : ValidationFailed(added);
}

int _newIssues(ToolOutcome? before, ToolOutcome? after) {
  switch (after) {
    case ToolUnreadable():
      return before is ToolUnreadable ? 0 : 1;
    case ToolIssues(:final issues):
      final known = before is ToolIssues
          ? before.issues
          : const <String, int>{};
      var added = 0;
      issues.forEach((key, count) {
        final extra = count - (known[key] ?? 0);
        if (extra > 0) added += extra;
      });
      return added;
    default:
      return 0;
  }
}
