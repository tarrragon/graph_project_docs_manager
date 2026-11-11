/// SPEC-004 §4.0.6 key 表對 ARB 的單向集合比對契約（0.6.0-W1-152.2）。
///
/// 方向：表 -> ARB。ARB 中不屬 §4.0.6 的 key 不受本契約約束。
/// 淘汰 key 以引言敘述、非表列，天然排除；殘留守衛維持 arb_key_sync_test。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 待加入豁免（表有、ARB 尚無，規格先行的 key）。
/// 成員必須仍在表中且尚不在 ARB；ARB 一加入即紅，迫使移除豁免。
/// 1.113 三個 nodeDetail key 已由 0.6.0-W1-155 補入 ARB，當時為空。
/// 1.140～1.146 起 §4.0.6 新增規格先行 key（1.0 編輯功能票實作時補 ARB 並移出）。
const Set<String> pendingAdditionExemptions = <String>{
  'dropdownA11yLabel',
  'editDoneAction',
  'editFieldsAction',
  'fieldBlockedRewriteNotIsolated',
  'fieldBlockedSnapshotFailed',
  'fieldDraftUnsentHint',
  'fieldDraftUnsentHintMultiLine',
  'fieldEmptyValue',
  'fieldIoFailed',
  'fieldNotEditableHint',
  'fieldRequiredEmpty',
  'fieldSeeWriteLogHint',
  'fieldValueOutOfDomain',
  'fieldWriteInProgress',
  'nodeDetailBodyUnavailableMessage',
  'nodeDetailEditReadFailedMessage',
  'radioNo',
  'radioYes',
  'readonlyWorkspaceGitMissingBadge',
  'readonlyWorkspaceNotGitBadge',
  'referencePickerNoMatch',
  'validationFailed',
  'validationPassed',
  'validationRunning',
  'validationUnavailable',
  'validationUnavailableExecutableMissing',
  'validationUnavailableTimedOut',
  'validationUnavailableUnexpectedExitCode',
  'validationUnavailableUnparsableOutput',
  'writeLogColumnField',
  'writeLogColumnPath',
  'writeLogColumnRestore',
  'writeLogColumnResult',
  'writeLogColumnValidation',
  'writeLogEmptyMessage',
  'writeLogNavA11yLabel',
  'writeLogProjectLabel',
  'writeLogRowA11yLabel',
  'writeLogSnapshotExpiryNote',
  'writeLogTitle',
  'writeResultBlocked',
  'writeResultExternallyModified',
  'writeResultIoFailed',
  'writeResultWritten',
};

/// 表列仍保留、但 ARB 已刻意移除的淘汰 key（SPEC-004 該列註明「ARB 實檔已移除」）。
/// 這些 key 不比對；一旦重新出現在 ARB 即紅。
const Set<String> obsoleteRowKeys = <String>{
  'schemaAppVersionLabel',
  'schemaProjectVersionLabel',
};

/// 非字面豁免（儲存格是描述而非字面）：只豁免值比對，不豁免存在性。
/// 格式：key -> 豁免的語系集合。
/// healthBadgeA11yLabel en：「單複數：1 issue／{count} issues」為描述。
const Map<String, Set<String>> nonLiteralExemptions = <String, Set<String>>{
  'healthBadgeA11yLabel': <String>{'en'},
};

const int minimumRowCount = 100;

class SpecRow {
  const SpecRow(this.key, this.zh, this.en);
  final String key;
  final String zh;
  final String en;
}

/// 以未跳脫的 `|` 分欄，`\|` 還原為文案內的 `|`。
List<String> splitRow(String line) {
  const escapedPipe = '\u0001';
  return line
      .replaceAll(r'\|', escapedPipe)
      .split('|')
      .map((c) => c.replaceAll(escapedPipe, '|').trim())
      .toList();
}

/// 抽取 `#### 4.0.6` 至 `#### 4.0.7` 之間以 `| `key` |` 起首的列。
/// 並列多 key 的列（`a` / `b`）逐格以 ` / ` 切分 key 與兩語系值，一 key 一筆。
/// 格數與 key 數不符即拋出（寧可失敗，不靜默略過）。
List<SpecRow> extractRows(String spec) {
  final rowStart = RegExp(r'^\| (`[A-Za-z0-9_]+`(?: / `[A-Za-z0-9_]+`)*) \|');
  final rows = <SpecRow>[];
  var inSection = false;
  for (final line in spec.split('\n')) {
    if (line.startsWith('#### 4.0.6')) inSection = true;
    if (line.startsWith('#### 4.0.7')) inSection = false;
    if (!inSection) continue;
    final m = rowStart.firstMatch(line);
    if (m == null) continue;
    final keys = m
        .group(1)!
        .split(' / ')
        .map((k) => k.replaceAll('`', ''))
        .toList();
    final cells = splitRow(line);
    final single = keys.length == 1;
    final zhs = single ? [cells[2]] : cells[2].split(' / ');
    final ens = single ? [cells[3]] : cells[3].split(' / ');
    if (zhs.length != keys.length || ens.length != keys.length) {
      throw StateError('多 key 列的格數與 key 數不符：$line');
    }
    for (var i = 0; i < keys.length; i++) {
      rows.add(SpecRow(keys[i], zhs[i], ens[i]));
    }
  }
  return rows;
}

/// 回傳違規描述清單；空即通過。
List<String> compareTableToArb(
  List<SpecRow> rows,
  Map<String, dynamic> zhArb,
  Map<String, dynamic> enArb, {
  Set<String> pending = pendingAdditionExemptions,
  Map<String, Set<String>> nonLiteral = nonLiteralExemptions,
}) {
  final violations = <String>[];
  final tableKeys = rows.map((r) => r.key).toSet();
  for (final key in pending) {
    if (!tableKeys.contains(key)) {
      violations.add('待加入豁免 $key 已不在表中，請移除豁免');
    }
    if (zhArb.containsKey(key) || enArb.containsKey(key)) {
      violations.add('待加入豁免 $key 已在 ARB，請移除豁免並進入值比對');
    }
  }
  for (final key in obsoleteRowKeys) {
    if (zhArb.containsKey(key) || enArb.containsKey(key)) {
      violations.add('淘汰 key $key 重新出現在 ARB，請移出 obsoleteRowKeys');
    }
  }
  for (final row in rows) {
    if (pending.contains(row.key) || obsoleteRowKeys.contains(row.key)) {
      continue;
    }
    for (final (locale, arb, expected) in [
      ('zh', zhArb, row.zh),
      ('en', enArb, row.en),
    ]) {
      if (!arb.containsKey(row.key)) {
        violations.add('${row.key} 不在 $locale ARB');
      } else if (!(nonLiteral[row.key]?.contains(locale) ?? false) &&
          arb[row.key] != expected) {
        violations.add(
          '${row.key} $locale 值不等：表=「$expected」ARB=「${arb[row.key]}」',
        );
      }
    }
  }
  return violations;
}

void main() {
  final spec = File('docs/spec/ui/SPEC-004-component-library.md')
      .readAsStringSync();
  final zhArb = jsonDecode(
    File('lib/l10n/app_zh.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  final enArb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  final rows = extractRows(spec);

  group('SPEC-004 §4.0.6 表 -> ARB 契約', () {
    test('表內無重複 key', () {
      final seen = <String>{};
      final dup = rows.map((r) => r.key).where((k) => !seen.add(k)).toList();
      expect(dup, isEmpty);
    });

    test('列數下界（防解析空轉）', () {
      expect(rows.length, greaterThanOrEqualTo(minimumRowCount));
    });

    test('表列 key 與值逐字符合 ARB（扣除豁免）', () {
      expect(compareTableToArb(rows, zhArb, enArb), isEmpty);
    });

    test('非字面豁免的 key 仍在表中且在兩語系 ARB', () {
      final keys = rows.map((r) => r.key).toSet();
      for (final k in nonLiteralExemptions.keys) {
        expect(keys, contains(k));
        expect(zhArb, contains(k));
        expect(enArb, contains(k));
      }
    });
  });

  group('E2 正向對照（注入資料，不改真實檔案）', () {
    test('竄改表列 key 的 ARB 值 -> 違規', () {
      final tampered = {...zhArb, rows.first.key: '${rows.first.zh}（竄改）'};
      final v = compareTableToArb(rows, tampered, enArb);
      final baseline = compareTableToArb(rows, zhArb, enArb);
      final injected = v.where((s) => !baseline.contains(s)).toList();
      expect(injected, hasLength(1));
      expect(injected.single, contains(rows.first.key));
    });

    test('baseline 非空（豁免遺漏）時 E2 仍只回報被竄改的 key', () {
      final base = compareTableToArb(rows, zhArb, enArb, pending: <String>{});
      final tampered = {...zhArb, rows.first.key: '${rows.first.zh}（竄改）'};
      final v = compareTableToArb(rows, tampered, enArb, pending: <String>{});
      final injected = v.where((s) => !base.contains(s)).toList();
      expect(injected, hasLength(1));
      expect(injected.single, contains(rows.first.key));
    });

    test('多 key 列解析：每個 key 各得一筆並帶對應值', () {
      const spec =
          '#### 4.0.6 x\n'
          '| `a` / `b` | 甲 / 乙 | A / B | — | 用 |\n'
          '#### 4.0.7 y\n';
      final r = extractRows(spec);
      expect(r.map((x) => (x.key, x.zh, x.en)), [
        ('a', '甲', 'A'),
        ('b', '乙', 'B'),
      ]);
    });

    test('合成表有 ARB 無的 key -> 違規', () {
      final synthetic = [
        ...rows,
        const SpecRow('syntheticMissingKey', 'a', 'b'),
      ];
      final v = compareTableToArb(synthetic, zhArb, enArb);
      expect(v.where((s) => s.contains('syntheticMissingKey')), hasLength(2));
    });

    test('已在 ARB 的 key 放進待加入豁免 -> 違規（豁免過期）', () {
      final v = compareTableToArb(
        rows,
        zhArb,
        enArb,
        pending: {rows.first.key},
      );
      expect(v.any((s) => s.contains('已在 ARB')), isTrue);
    });

    test('待加入豁免成員不在表中 -> 違規', () {
      final v = compareTableToArb(rows, zhArb, enArb, pending: {'notInTable'});
      expect(v.any((s) => s.contains('已不在表中')), isTrue);
    });

    test('解析器自檢：跳脫豎線還原', () {
      expect(splitRow(r'| `k` | a \| b | c |')[2], 'a | b');
    });
  });
}
