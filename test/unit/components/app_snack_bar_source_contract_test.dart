/// AppSnackBar 原始碼契約測試（G-E，0.1.0-W3-205 P2.1）。
///
/// 驗收對象是原始碼文字本身，不是執行期行為——純 `test()`，不 import 任何
/// `lib/` 符號，不需要 widget harness（P2.1 第 3 點）。與行為測試分檔的理由
/// 見 Phase 2 P2.1「G-E 為新增檔的四項理由」。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _libDir = 'lib';
const _snackBarPath = 'lib/components/app_snack_bar.dart';
const _levelPath = 'lib/app/attention_level.dart';
const _mainPath = 'lib/main.dart';
const _shellPath = 'lib/app/shell.dart';
const _specPath = 'docs/spec/ui/SPEC-003-interaction-response.md';

/// 剝除 `///`／`//` 行尾、`/* */` 跨行區塊；字串字面量內的 `//` 不解析
/// （已知限制，見 T-205-21(a)）。單趟字元狀態機，換行一律保留（行數守恆，
/// Phase 3a P3a.5.1）。
String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  const codeState = 0;
  const lineCommentState = 1;
  const blockCommentState = 2;
  var state = codeState;
  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    switch (state) {
      case codeState:
        if (c == '/' && next == '/') {
          state = lineCommentState;
          i += 2;
        } else if (c == '/' && next == '*') {
          state = blockCommentState;
          i += 2;
        } else {
          buffer.write(c);
          i += 1;
        }
      case lineCommentState:
        if (c == '\n') {
          state = codeState;
          buffer.write(c);
        }
        i += 1;
      case blockCommentState:
        if (c == '*' && next == '/') {
          state = codeState;
          i += 2;
        } else {
          if (c == '\n') {
            buffer.write(c);
          }
          i += 1;
        }
      default:
        i += 1;
    }
  }
  return buffer.toString();
}

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      '0.1.0-W3-205 原始碼契約守衛：檔案不存在（$path）。守衛應紅燈而非'
      '靜默跳過（P2.5 執行環境規範）。',
    );
  }
  return file.readAsStringSync();
}

List<File> _dartFilesUnder(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

int _countOccurrences(String text, Pattern pattern) =>
    pattern.allMatches(text).length;

/// 以大括號配對從 [start]（指向簽名後第一個 `{`）取出函式體，處理引號
/// （單／雙引號、跳脫字元），避免字串內大括號使配對提前結束（Phase 3a
/// P3a.5.4：深度掃描須處理引號，剝除器不需要）。
String _extractBracedBody(String text, int start) {
  var depth = 0;
  var i = start;
  const codeState = 0;
  const stringState = 1;
  var state = codeState;
  var quote = '';
  final bodyStart = start;
  while (i < text.length) {
    final c = text[i];
    switch (state) {
      case codeState:
        if (c == "'" || c == '"') {
          state = stringState;
          quote = c;
        } else if (c == '{') {
          depth += 1;
        } else if (c == '}') {
          depth -= 1;
          if (depth == 0) {
            return text.substring(bodyStart, i + 1);
          }
        }
      case stringState:
        if (c == '\\') {
          i += 1;
        } else if (c == quote) {
          state = codeState;
        }
      default:
        break;
    }
    i += 1;
  }
  fail('0.1.0-W3-205 原始碼契約守衛：大括號未配對完成（$start 起）。');
}

void main() {
  group('T-205-14／T-205-15：hideCurrentSnackBar 呼叫點守衛（觀察 A）', () {
    late String stripped;

    setUpAll(() {
      stripped = _stripComments(_readFile(_snackBarPath));
    });

    test('T-205-14：app_snack_bar.dart 內 hideCurrentSnackBar 恰 2 次', () {
      expect(
        _countOccurrences(stripped, 'hideCurrentSnackBar'),
        2,
        reason:
            '0.1.0-W3-205 INV-SNACKBAR-NOQUEUE／觀察 A：hideCurrentSnackBar '
            '應恰 2 處（無引數清除 1 次 + reason: action 清除 1 次）。新增'
            '第三個呼叫點使 reason == hide 不再恆等於「被截斷」，須同步'
            '確認觀察 A 的承重前提。',
      );
      expect(
        _countOccurrences(stripped, 'removeCurrentSnackBar'),
        0,
        reason: '0.1.0-W3-205：removeCurrentSnackBar 不應出現——本元件不引入'
            '任何形式的提示佇列（0.1.0-W3-239）。',
      );
      expect(
        _countOccurrences(stripped, 'clearSnackBars'),
        0,
        reason: '0.1.0-W3-205：clearSnackBars 不應出現，理由同上。',
      );
      expect(
        _countOccurrences(
          stripped,
          RegExp(r'hideCurrentSnackBar\(\s*\)'),
        ),
        1,
        reason: '0.1.0-W3-205：無引數清除（INV-SNACKBAR-NOQUEUE 的唯一清除）'
            '恰應出現 1 次。',
      );
      expect(
        _countOccurrences(
          stripped,
          RegExp(r'hideCurrentSnackBar\(\s*reason:\s*SnackBarClosedReason\.action'),
        ),
        1,
        reason: '0.1.0-W3-205：帶 reason: action 的清除恰應出現 1 次'
            '（動作回呼順序改動，觀察 B 處置）。',
      );
    });

    test('T-205-15：三個識別符在本元件之外的 lib/ 範圍零命中', () {
      for (final file in _dartFilesUnder(_libDir)) {
        if (file.path == _snackBarPath) {
          continue;
        }
        final content = _stripComments(file.readAsStringSync());
        for (final symbol in [
          'hideCurrentSnackBar',
          'removeCurrentSnackBar',
          'clearSnackBars',
        ]) {
          expect(
            content.contains(symbol),
            isFalse,
            reason: '0.1.0-W3-205：$symbol 在 ${file.path} 出現，'
                '應僅限 $_snackBarPath 內部（觀察 A 的承重前提）。',
          );
        }
      }
    });
  });

  group('T-205-16：INV-SNACKBAR-NOQUEUE（B12、場景 13）', () {
    late String stripped;

    setUpAll(() {
      stripped = _stripComments(_readFile(_snackBarPath));
    });

    test('showSnackBar 恰 1 次，且緊接於唯一的無引數清除之後，深度相等', () {
      final showCount = _countOccurrences(
        stripped,
        RegExp(r'messenger\.showSnackBar\('),
      );
      expect(
        showCount,
        1,
        reason: '0.1.0-W3-205 T-205-16(a)：showSnackBar 呼叫點應恰 1 處。',
      );

      final hideIndex = stripped.indexOf(RegExp(r'hideCurrentSnackBar\(\s*\)'));
      final showIndex = stripped.indexOf('messenger.showSnackBar(');
      expect(
        hideIndex,
        isNot(-1),
        reason: 'T-205-16(b)：無引數清除應恰 1 次存在。',
      );
      expect(
        showIndex,
        greaterThan(hideIndex),
        reason: 'T-205-16(c)：清除應早於呈現（來源順序）。',
      );

      final between = stripped.substring(hideIndex, showIndex);
      expect(
        between.contains('return'),
        isFalse,
        reason: 'T-205-16(d)：清除與呈現之間不得出現 return——INV-SNACKBAR-'
            'NOQUEUE 要求兩者間無早退，否則會使 Material 內建 FIFO 生效，'
            '構成 0.1.0-W3-239 禁止的提示佇列。',
      );

      // T-205-16(e)：兩者的大括號巢狀深度相等——排除「hide 被包進條件
      // 分支而 show 在分支外」這種「不 hide 就 show」的形態。不得以放寬
      // 本斷言消紅燈（Phase 3a P3a.1.1 明文禁止），紅燈時應把條件改寫為
      // 前置護衛。
      int depthAt(int index) {
        var depth = 0;
        for (var i = 0; i < index; i++) {
          if (stripped[i] == '{') depth += 1;
          if (stripped[i] == '}') depth -= 1;
        }
        return depth;
      }

      expect(
        depthAt(hideIndex),
        depthAt(showIndex),
        reason:
            '0.1.0-W3-205 T-205-16(e) INV-SNACKBAR-NOQUEUE：清除與呈現的'
            '大括號巢狀深度須相等（兩者皆為 show 函式主體的直屬語句）。'
            '紅燈代表清除或呈現被包進條件分支，正確處置是改寫為前置護衛，'
            '不是放寬本斷言。',
      );
    });
  });

  group('T-205-17：裁決函式輸入面（B10、場景 11）', () {
    test('_resolvePreemption 參數恰 2 個，函式體不含無關輸入或私有轉呼', () {
      final stripped = _stripComments(_readFile(_snackBarPath));
      final sigMatch = RegExp(
        r'_resolvePreemption\(\s*([\w?<>]+)\s+\w+\s*,\s*([\w?<>]+)\s+\w+\s*,?\s*\)\s*\{',
      ).firstMatch(stripped);
      expect(
        sigMatch,
        isNotNull,
        reason: '0.1.0-W3-205 T-205-17(a)：找不到 _resolvePreemption 的'
            '簽名，應恰兩個具型別參數。',
      );
      expect(sigMatch!.group(1), 'AttentionLevel');
      expect(sigMatch.group(2), 'AttentionHolderHint?');

      final braceStart = stripped.indexOf('{', sigMatch.end - 1);
      final body = _extractBracedBody(stripped, braceStart);

      for (final forbidden in [
        'variant',
        'origin',
        'message',
        'context',
        'runtimeType',
        ' is ',
      ]) {
        expect(
          body.contains(forbidden),
          isFalse,
          reason: '0.1.0-W3-205 T-205-17(b)：裁決函式體不得引用 $forbidden'
              '——裁決輸入恰為級別與持有者快照。',
        );
      }
      expect(
        body.contains(RegExp(r'_\w+\(')),
        isFalse,
        reason: '0.1.0-W3-205 T-205-17(c)：裁決函式體不得轉呼其他私有函式。',
      );
      expect(
        body.contains('AppSnackBar.'),
        isFalse,
        reason: '0.1.0-W3-205 T-205-17(d)：裁決函式體不得存取元件靜態成員。',
      );
    });
  });

  group('T-205-18：元件靜態成員白名單（票面 acceptance 4 靜態面）', () {
    test('static 成員與 enum 名稱集合恰為既定白名單', () {
      final stripped = _stripComments(_readFile(_snackBarPath));

      final staticNames = RegExp(
        r'static\s+(?:const\s+)?(?:[\w?<>,\s]+?)\s+(_\w+|logSink|show)\s*[=(]',
      ).allMatches(stripped).map((m) => m.group(1)!).toSet();
      const expectedStatic = {
        '_actionSlotAssertMessage',
        '_tag',
        '_levelInfo',
        '_levelWarning',
        '_lastShowId',
        'logSink',
        '_nextShowId',
        '_resolveClosedLevel',
        '_resolvePreemption',
        '_defaultLogSink',
        'show',
      };
      final extra = staticNames.difference(expectedStatic);
      expect(
        extra,
        isEmpty,
        reason: '0.1.0-W3-205 T-205-18(a)：發現白名單外的新增靜態成員：'
            '$extra。新增靜態成員需先確認不是在引入持有者狀態或待顯集合'
            '（票面 acceptance 4：元件內無「當前顯示者」狀態欄位）。',
      );
      final missing = expectedStatic.difference(staticNames);
      expect(
        missing,
        isEmpty,
        reason: '0.1.0-W3-205 T-205-18(a)：既有靜態成員被移除或改名：'
            '$missing。',
      );

      final enumNames = RegExp(
        r'enum\s+(\w+)\s*\{',
      ).allMatches(stripped).map((m) => m.group(1)!).toSet();
      const expectedEnums = {
        'AppSnackBarVariant',
        'AppSnackBarOrigin',
        'AppSnackBarLogEvent',
        '_Preemption',
      };
      expect(
        enumNames,
        expectedEnums,
        reason: '0.1.0-W3-205 T-205-18(b)：本檔宣告的 enum 集合應恰為'
            '$expectedEnums，實際為 $enumNames。',
      );
    });
  });

  group('T-205-19：AttentionLevel 定義唯一（B11、場景 12、票面 acceptance 3）', () {
    test('AttentionLevel 在 lib/ 內恰 1 處宣告，位於 attention_level.dart', () {
      var declarationCount = 0;
      for (final file in _dartFilesUnder(_libDir)) {
        final content = _stripComments(file.readAsStringSync());
        if (RegExp(r'enum\s+AttentionLevel\s*\{').hasMatch(content)) {
          declarationCount += 1;
          expect(
            file.path,
            _levelPath,
            reason: '0.1.0-W3-205 T-205-19(a)：AttentionLevel 的宣告位置'
                '應僅在 $_levelPath，實際發現於 ${file.path}。',
          );
        }
      }
      expect(
        declarationCount,
        1,
        reason: '0.1.0-W3-205 T-205-19(a)：AttentionLevel 應在 lib/ 內恰 '
            '1 處宣告，實際 $declarationCount 處——多於一處即兩份平行定義'
            '（SPEC-003 §2.15 警告的兩份同一事實）。',
      );
    });

    test('三個值依序為 discardable、mustLeaveTrace、undroppable', () {
      final raw = _readFile(_levelPath);
      final stripped = _stripComments(raw);
      final order = RegExp(
        r'enum\s+AttentionLevel\s*\{([^}]*)\}',
      ).firstMatch(stripped)!.group(1)!;
      final values = order
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      expect(
        values,
        ['discardable', 'mustLeaveTrace', 'undroppable'],
        reason: '0.1.0-W3-205 T-205-19(b)：列舉宣告順序即優先序，index '
            '越大級別越高，順序不可調換。',
      );

      for (final mainName in ['可棄', '須留痕', '不可棄']) {
        expect(
          raw.contains(mainName),
          isTrue,
          reason: '0.1.0-W3-205 T-205-19(c)：$_levelPath 的 dartdoc 應含'
              '主名「$mainName」（權威來源為《事件流負載仲裁方法論》'
              '〈級別〉表，不對 SPEC-003 §2.14 表格做剖析比對）。',
        );
      }
      expect(
        raw.contains('注意力通道的到達類別與級別指派表'),
        isTrue,
        reason: '0.1.0-W3-205 T-205-19(d)：$_levelPath 應以標題文字引用 '
            'SPEC-003〈注意力通道的到達類別與級別指派表〉。',
      );
    });
  });

  group('T-205-20：main.dart 收斂（票面 acceptance 1 靜態面）', () {
    test('ScaffoldMessenger／showSnackBar 各 0 次，AppSnackBar.show 至少 1 次', () {
      final stripped = _stripComments(_readFile(_mainPath));
      expect(
        _countOccurrences(stripped, 'ScaffoldMessenger'),
        0,
        reason: '0.1.0-W3-205 T-205-20：main.dart 不應再直接引用 '
            'ScaffoldMessenger（票面 acceptance 1）。',
      );
      expect(
        _countOccurrences(stripped, 'showSnackBar'),
        0,
        reason: '0.1.0-W3-205 T-205-20：main.dart 不應再直接呼叫 '
            'showSnackBar。',
      );
      expect(
        _countOccurrences(stripped, 'AppSnackBar.show'),
        greaterThanOrEqualTo(1),
        reason: '0.1.0-W3-205 T-205-20：main.dart 應至少一處經 '
            'AppSnackBar.show 呈現提示——若計數下降為 0，代表剝除器或分支'
            '本身被誤刪，而非收斂完成。',
      );
    });
  });

  group('T-205-21：守衛自身的守衛', () {
    test('T-205-21(a)：剝除器對四種形態產出預期結果', () {
      expect(_stripComments('// line comment\ncode();'), '\ncode();');
      expect(_stripComments('/// doc comment\ncode();'), '\ncode();');
      expect(
        _stripComments('code(); // trailing\nmore();'),
        'code(); \nmore();',
      );
      expect(
        _stripComments('before();\n/* block\n comment */\nafter();'),
        'before();\n\n\nafter();',
      );
    }, skip: '已知限制（P2.4／P3a.5.1）：剝除器不解析字串字面量，字串內含 '
        '// 時會被誤剝。lib/ 現況零命中（實測 2026-09-10），形態出現時本'
        '測試為發現點，不得因此「修好」剝除器——修好會使本測試預期值失效，'
        '其職責是讓限制可見。');

    test('T-205-21(a-verified)：三種可驗證形態的剝除結果', () {
      expect(_stripComments('// line comment\ncode();'), '\ncode();');
      expect(_stripComments('/// doc comment\ncode();'), '\ncode();');
      expect(
        _stripComments('code(); // trailing\nmore();'),
        'code(); \nmore();',
      );
      expect(
        _stripComments('before();\n/* block\n comment */\nafter();'),
        'before();\n\n\nafter();',
      );
      // 行數守恆：任意 fixture 剝除前後行數相等。
      const fixture =
          '// a\ncode();\n/* b\nc */\nmore(); // d\nlast();';
      expect(
        '\n'.allMatches(_stripComments(fixture)).length,
        '\n'.allMatches(fixture).length,
      );
      // 無註解輸入恆等：不含任何註解的 fixture 剝除後與輸入逐字相等。
      const noComment = 'final x = 1;\nfinal y = 2;\n';
      expect(_stripComments(noComment), noComment);
    });

    test('T-205-21(b)：正向對照——shell.dart 剝除後 ScaffoldMessenger 命中為 0', () {
      final raw = _readFile(_shellPath);
      expect(
        _countOccurrences(raw, 'ScaffoldMessenger'),
        greaterThan(0),
        reason: '0.1.0-W3-205 T-205-21(b) 前置：剝除前應能命中'
            '（2026-09-10 實測為 2），否則本正向對照無意義。',
      );
      expect(
        _countOccurrences(_stripComments(raw), 'ScaffoldMessenger'),
        0,
        reason: '0.1.0-W3-205 T-205-21(b)：剝除器若失效變成空操作，本斷言'
            '應先紅——lib/app/shell.dart 內的 ScaffoldMessenger 皆在'
            '說明註解中，剝除後應零命中。',
      );
    });

    test('T-205-21(c)：SPEC-003 五段章節標題文字存在', () {
      final spec = _readFile(_specPath);
      for (final heading in [
        '注意力通道的到達類別與級別指派表',
        '讓步規則的可驗收形態',
        '鑑別「綁級別」與「綁呼叫路徑」兩種實作',
        '截斷事件的日誌等級',
        '顯示位爭用時的約束與 0.1 的處置規則',
      ]) {
        expect(
          spec.contains(heading),
          isTrue,
          reason: '0.1.0-W3-205 T-205-21(c)：SPEC-003 的章節標題「$heading」'
              '已變更或消失，請同步更新 lib/app/attention_level.dart 與 '
              'lib/components/app_snack_bar.dart 的 dartdoc 章節引用'
              '（本斷言為該引用的唯一守衛）。',
        );
      }
    });
  });
}
