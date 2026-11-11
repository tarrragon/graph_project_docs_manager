/// 規格列的「規格先行」標記解析（1.1.0-W1-108，格式定義見 SPEC-004 §4.0）。
///
/// 標記字面：`（規格先行：<落地票號>）`（全形括號與冒號），置於規格列的
/// 備註欄（key 表列的最後一格），不得置於 zh／en 文案欄。落地票號為
/// `<版本>-W<波>-<序>` 或其子票形式 `<版本>-W<波>-<序>.<子序>`。
///
/// 語意：帶標記的列表示規格已先於實作修改，契約測試對該列跳過比對；
/// 標記不得與實作並存——實作一經與該列一致，契約測試判紅並提示移除標記。
library;

final RegExp specFirstMarker = RegExp(
  r'（規格先行：(\d+\.\d+\.\d+-W\d+-\d+(?:\.\d+)*)）',
);

/// 回傳列上標記的落地票號；無標記回傳 null。
String? specFirstTicketOf(String line) =>
    specFirstMarker.firstMatch(line)?.group(1);

/// 以未跳脫的 `|` 分欄，`\|` 還原為文案內的 `|`。
List<String> splitSpecRow(String line) {
  const escapedPipe = '\u0001';
  return line
      .replaceAll(r'\|', escapedPipe)
      .split('|')
      .map((c) => c.replaceAll(escapedPipe, '|').trim())
      .toList();
}

/// 帶標記的列，其 ARB 是否已與規格列一致（兩語系皆存在且值逐字相等）。
bool arbAlreadyMatchesSpecRow(
  String key,
  String zhText,
  String enText,
  Map<String, dynamic> zhArb,
  Map<String, dynamic> enArb,
) => zhArb[key] == zhText && enArb[key] == enText;

/// 標記過期的紅燈訊息。
String staleSpecFirstMessage(String key, String ticket) =>
    '$key 帶有「規格先行：$ticket」標記，但 ARB 已與規格列一致，請移除該標記';
