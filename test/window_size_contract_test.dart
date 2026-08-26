import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/main.dart';

/// 視窗尺寸同時定義在原生端（Swift）與 Dart 端，兩者必須一致：
///
/// * Swift 的 `minSize` 決定使用者「實際」能把視窗縮到多小。
/// * Dart 的 [kMinWindowSize] 決定整合測試「驗收」到多小。
///
/// 若 Swift 端放得比 Dart 端更寬鬆，就會出現整合測試全綠、實機拉窄後
/// 卻跑版的破口。這個測試把跨語言的隱性約定變成會失敗的斷言。
void main() {
  late String swiftSource;

  setUpAll(() {
    swiftSource =
        File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
  });

  test('macOS minSize 與 Dart kMinWindowSize 一致', () {
    expect(
      _parseNSSize(swiftSource, 'minimumSize'),
      kMinWindowSize,
      reason: 'Swift 的視窗下限與 Dart 的驗收下限不符 —— '
          '整合測試將無法涵蓋實機可達到的最窄視窗',
    );
  });

  test('macOS 預設視窗尺寸與 Dart kDesignSize 一致', () {
    expect(
      _parseNSSize(swiftSource, 'defaultSize'),
      kDesignSize,
      reason: '預設視窗應等同設計稿基準，否則 App 一開啟縮放係數就不是 1.0',
    );
  });
}

/// 從 Swift 原始碼取出 `static let <name> = NSSize(width: W, height: H)` 的值。
Size _parseNSSize(String source, String constantName) {
  final match = RegExp(
    r'static\s+let\s+' +
        RegExp.escape(constantName) +
        r'\s*=\s*NSSize\(\s*width:\s*([\d.]+)\s*,\s*height:\s*([\d.]+)\s*\)',
  ).firstMatch(source);

  if (match == null) {
    fail('在 MainFlutterWindow.swift 中找不到常數 $constantName');
  }
  return Size(double.parse(match.group(1)!), double.parse(match.group(2)!));
}
