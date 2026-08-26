import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS entitlements 的契約測試。
///
/// entitlements 是純宣告：少一項或多一項都不會有編譯錯誤、不會有 lint 警告，
/// widget 與整合測試也照樣全綠 —— 問題要到實機執行才會炸開，而且症狀是
/// 「讀不到檔案」「CLI 跑不起來」這類難以歸因的執行期錯誤。
///
/// 本專案的核心契約是 **App Sandbox 必須維持關閉**。理由不是偏好而是能力：
/// 沙盒開啟時 `Process.run` 無法執行專案內的 doc CLI（實測：系統 python3 被
/// xcrun shim 以 "cannot be used within an App Sandbox" 拒絕；使用者安裝的
/// binary 直接 Operation not permitted）。若有人為了上架 Mac App Store 把
/// sandbox 打開，App 會靜默失去呼叫 CLI 的能力。
void main() {
  const files = {
    'Debug': 'macos/Runner/DebugProfile.entitlements',
    'Release': 'macos/Runner/Release.entitlements',
  };

  /// 僅 Debug 需要：Flutter 的 hot reload 與 Dart VM JIT。
  /// Release 走 AOT，出現在 Release 只會擴大 Hardened Runtime 的攻擊面。
  const debugOnly = {
    'com.apple.security.cs.allow-jit': 'Dart VM 的 JIT',
    'com.apple.security.network.server': 'hot reload / VM service',
  };

  /// 沙盒關閉後這些權限不再有意義，留著會誤導讀者以為 App 仍在沙盒內。
  const sandboxOnly = [
    'com.apple.security.files.user-selected.read-write',
    'com.apple.security.files.bookmarks.app-scope',
    'com.apple.security.network.client',
  ];

  files.forEach((label, path) {
    group('$label.entitlements', () {
      late String plist;
      setUpAll(() => plist = File(path).readAsStringSync());

      test('App Sandbox 明確關閉', () {
        expect(
          _valueOf(plist, 'com.apple.security.app-sandbox'),
          isFalse,
          reason: 'sandbox 一旦開啟，Process.run 就無法執行 doc CLI —— '
              'App 會靜默失去核心能力，且沒有任何編譯期徵兆',
        );
      });

      test('不含沙盒專屬權限', () {
        for (final key in sandboxOnly) {
          expect(
            _valueOf(plist, key),
            isNull,
            reason: '$key 只在沙盒下有意義，沙盒已關閉，留著會誤導',
          );
        }
      });
    });
  });

  group('Debug 專屬權限', () {
    late String debug;
    late String release;
    setUpAll(() {
      debug = File(files['Debug']!).readAsStringSync();
      release = File(files['Release']!).readAsStringSync();
    });

    debugOnly.forEach((key, purpose) {
      test('$key 只出現在 Debug', () {
        expect(_valueOf(debug, key), isTrue, reason: 'Debug 需要「$purpose」');
        expect(
          _valueOf(release, key),
          isNull,
          reason: '$key 屬 debug 專用，出現在 Release 會擴大攻擊面',
        );
      });
    });
  });
}

/// 讀取 entitlements plist 中某個 key 的布林值。
///
/// 回傳 `null` 表示該 key 不存在 —— 這與「存在且為 false」語意不同，
/// 本測試兩者都要能區分。
bool? _valueOf(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<(true|false)\\s*/>',
  ).firstMatch(plist);
  if (match == null) return null;
  return match.group(1) == 'true';
}
