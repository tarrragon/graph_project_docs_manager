import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS App Sandbox 權限的契約測試。
///
/// entitlements 是純宣告：少一項不會有編譯錯誤、不會有 lint 警告，
/// 整合測試也照樣全綠 —— 問題要到實機執行（甚至打包上架後）才會炸開，
/// 而且症狀是「連線失敗」「讀不到檔案」這類難以歸因的執行期錯誤。
/// 因此把必要權限釘成會失敗的斷言。
void main() {
  /// 兩個 build 組態都必須具備的權限。
  const requiredInBoth = <String, String>{
    'com.apple.security.app-sandbox': 'App Sandbox 本身',
    'com.apple.security.network.client': '對外網路連線',
    'com.apple.security.files.user-selected.read-write':
        '使用者選取的檔案／資料夾讀寫',
    'com.apple.security.files.bookmarks.app-scope':
        'security-scoped bookmark（重啟後保留資料夾授權）',
  };

  /// 僅 Debug 需要：Flutter 的 hot reload 與 VM service 走 incoming 連線。
  const requiredInDebugOnly = <String, String>{
    'com.apple.security.cs.allow-jit': 'Dart VM 的 JIT',
    'com.apple.security.network.server': 'hot reload / VM service',
  };

  group('DebugProfile.entitlements', () {
    late String plist;
    setUpAll(() {
      plist = File('macos/Runner/DebugProfile.entitlements').readAsStringSync();
    });

    for (final entry in {...requiredInBoth, ...requiredInDebugOnly}.entries) {
      test('具備 ${entry.key}', () {
        expect(_isEnabled(plist, entry.key), isTrue,
            reason: '缺少「${entry.value}」權限');
      });
    }
  });

  group('Release.entitlements', () {
    late String plist;
    setUpAll(() {
      plist = File('macos/Runner/Release.entitlements').readAsStringSync();
    });

    for (final entry in requiredInBoth.entries) {
      test('具備 ${entry.key}', () {
        expect(_isEnabled(plist, entry.key), isTrue,
            reason: '缺少「${entry.value}」權限 —— '
                'Release 樣板預設不含網路權限，這是打包後連不上網的頭號成因');
      });
    }

    test('不含 debug 專用權限', () {
      for (final key in requiredInDebugOnly.keys) {
        expect(_isEnabled(plist, key), isFalse,
            reason: '$key 屬於 debug 專用，出現在 Release 會擴大攻擊面');
      }
    });
  });
}

/// 檢查 entitlements plist 中某個 key 是否被設為 `<true/>`。
bool _isEnabled(String plist, String key) => RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<true\\s*/>',
    ).hasMatch(plist);
