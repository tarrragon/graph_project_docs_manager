/// ARB key 同步契約（0.3.3-W3-395）：已移除的 key 不得殘留於任一語系 ARB。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const removedKeys = ['backToDomainAction', 'noUcNodesMessage'];

  for (final file in ['lib/l10n/app_zh.arb', 'lib/l10n/app_en.arb']) {
    test('$file 不含已移除的 key', () {
      final arb =
          jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      for (final key in removedKeys) {
        expect(arb.containsKey(key), isFalse, reason: key);
        expect(arb.containsKey('@$key'), isFalse, reason: '@$key');
      }
    });
  }
}
