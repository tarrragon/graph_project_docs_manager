/// gate 偵測所需的三個 filesystem 訊號探測介面（`0.2.0-W1-033`）。
///
/// SPEC-001 v1.18〈Gate 三問對照〉判定順序需要三項訊號：目標專案
/// `.claude/VERSION` 值、`tracking_schema.json`（PROP-002 明定全路徑：
/// `.claude/skills/doc/doc_system/core/tracking_schema.json`）存在性、
/// 該 JSON 的 `schema_generated_at_framework_version` 欄。本檔以介面
/// 定義三項訊號讀取，讓 `GateDetectionNotifier`（見
/// `screens/domain_view/gate_detection_notifier.dart`）與其測試可注入
/// mock，不依賴真實檔案系統（`test/integration/gate_manifest_test.dart`
/// 的 17 列凍結 manifest 不觸碰 `~/project`）。
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

/// 探測目標專案的框架訊號。介面可 mock，生產預設為
/// [DefaultFrameworkSignalProbe]。
abstract interface class FrameworkSignalProbePort {
  /// 讀取 `.claude/VERSION` 內容；檔案不存在或內容為空白回傳 `null`。
  Future<String?> readVersion(String workspacePath);

  /// `tracking_schema.json`（PROP-002 全路徑）是否存在。
  Future<bool> schemaJsonExists(String workspacePath);

  /// 讀取 JSON 的 `schema_generated_at_framework_version` 欄；檔案不存在、
  /// 內容無法解析為 JSON、或該欄位缺失／非字串時回傳 `null`（安全預設：
  /// 呼叫端據此判定「不確定」而非臆測一個版本值）。
  Future<String?> readSchemaJsonVersion(String workspacePath);
}

/// [FrameworkSignalProbePort] 的生產實作，讀取真實檔案系統。
class DefaultFrameworkSignalProbe implements FrameworkSignalProbePort {
  const DefaultFrameworkSignalProbe();

  /// `.claude/VERSION` 相對於工作資料夾的路徑。
  static const String versionRelativePath = '.claude/VERSION';

  /// `tracking_schema.json` 相對於工作資料夾的路徑（PROP-002 明定）。
  static const String schemaJsonRelativePath =
      '.claude/skills/doc/doc_system/core/tracking_schema.json';

  @override
  Future<String?> readVersion(String workspacePath) async {
    final file = File('$workspacePath/$versionRelativePath');
    if (!await file.exists()) return null;
    try {
      final content = (await file.readAsString()).trim();
      return content.isEmpty ? null : content;
    } on FileSystemException catch (e) {
      developer.log(
        'VERSION 讀取失敗：$workspacePath', // i18n-exempt: 開發者 debug log
        name: 'FrameworkSignalProbe',
        level: 900,
        error: e,
      );
      return null;
    }
  }

  @override
  Future<bool> schemaJsonExists(String workspacePath) {
    return File('$workspacePath/$schemaJsonRelativePath').exists();
  }

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async {
    final file = File('$workspacePath/$schemaJsonRelativePath');
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        developer.log(
          'tracking_schema.json 最上層非物件：$workspacePath', // i18n-exempt: 開發者 debug log
          name: 'FrameworkSignalProbe',
          level: 900,
        );
        return null;
      }
      final version = decoded['schema_generated_at_framework_version'];
      return version is String ? version : null;
    } on FileSystemException catch (e) {
      developer.log(
        'tracking_schema.json 讀取失敗：$workspacePath', // i18n-exempt: 開發者 debug log
        name: 'FrameworkSignalProbe',
        level: 900,
        error: e,
      );
      return null;
    } on FormatException catch (e) {
      developer.log(
        'tracking_schema.json 解析失敗：$workspacePath', // i18n-exempt: 開發者 debug log
        name: 'FrameworkSignalProbe',
        level: 900,
        error: e,
      );
      return null;
    }
  }
}
