/// 開啟原始檔使用的編輯器偏好（SPEC-003 §2.2〈編輯器對照表〉、§3.8）。
///
/// 選定值是一個編輯器 id（[systemEditorId] 或 [editorTable] 成員），屬 App 層
/// 設定，與 workspace 偏好共用 `shared_preferences`，鍵名見
/// [editorPreferenceKey]；不隨專案切換改變（SPEC-001 §9）。
///
/// 可觀測性（observability 規則 5）：讀寫的失敗皆經 `LogSink`
/// （[EditorPreferenceLogEvent]）記錄。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/workspace/workspace_io_log_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「系統預設（不定位）」的選定值，也是未曾選擇時的預設值。
const String systemEditorId = 'system';

/// 選定編輯器 id 的 `shared_preferences` 鍵名（App 層）。
const String editorPreferenceKey = 'app.openEditorId';

/// 編輯器對照表的一列：[id] 同時是設定面板選項錨點的後綴。
class EditorSpec {
  const EditorSpec({
    required this.id,
    required this.name,
    required this.scheme,
  });

  /// 持久化值與選項錨點後綴。
  final String id;

  /// 編輯器顯示名（產品專有名詞，不翻譯）。
  final String name;

  /// 該編輯器註冊的 URL scheme；查 handler 與組開啟 URL 共用。
  final String scheme;
}

/// 首批四個編輯器，順序即設定面板選項順序（SPEC-003 §2.2〈編輯器對照表〉）。
// i18n-exempt: 編輯器顯示名為產品專有名詞，不隨語系翻譯
const List<EditorSpec> editorTable = [
  EditorSpec(
    id: 'vscode',
    name: 'VS Code',
    scheme: 'vscode',
  ), // i18n-exempt: 專有名詞
  EditorSpec(
    id: 'vscode-insiders',
    name: 'VS Code Insiders', // i18n-exempt: 專有名詞
    scheme: 'vscode-insiders',
  ),
  EditorSpec(
    id: 'cursor',
    name: 'Cursor',
    scheme: 'cursor',
  ), // i18n-exempt: 專有名詞
  EditorSpec(id: 'zed', name: 'Zed', scheme: 'zed'), // i18n-exempt: 專有名詞
];

/// 依 id 查對照表；[systemEditorId] 與未知 id 回傳 `null`。
EditorSpec? editorById(String id) {
  for (final spec in editorTable) {
    if (spec.id == id) return spec;
  }
  return null;
}

/// 組編輯器開啟 URL：`<scheme>://file/<絕對路徑>:<line>`。
///
/// 由 [Uri] 負責百分比編碼，路徑含空白或中文時不需手動處理。
String editorUrlFor(EditorSpec spec, String path, int line) {
  return Uri(scheme: spec.scheme, host: 'file', path: '$path:$line').toString();
}

/// 查詢某 URL scheme 在本機是否有 handler（唯讀，不啟動任何應用程式）。
abstract interface class EditorHandlerProbe {
  Future<bool> hasHandler(String scheme);
}

/// 選定編輯器 id 的持久化介面。
abstract interface class EditorPreferenceStore {
  /// 讀取選定值；從未寫入或讀取失敗時回傳 [systemEditorId]。
  Future<String> read();

  /// 寫入選定值並回報成敗：成功 `true`，失敗 `false`（記錄日誌，不拋出，
  /// 持久化值不變），供呼叫端分流提示（SPEC-003 §3.8）。
  Future<bool> write(String editorId);
}

/// [EditorPreferenceStore] 的 `shared_preferences` 載體。
class SharedPreferencesEditorStore implements EditorPreferenceStore {
  const SharedPreferencesEditorStore();

  @override
  Future<String> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(editorPreferenceKey) ?? systemEditorId;
    } on Object catch (error) {
      editorPreferenceLogSink(
        EditorPreferenceLogEvent.readFailed,
        LogFields.empty,
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
        error: error,
      );
      return systemEditorId;
    }
  }

  @override
  Future<bool> write(String editorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(editorPreferenceKey, editorId);
      editorPreferenceLogSink(
        EditorPreferenceLogEvent.written,
        LogFields({
          WorkspaceIoLogKeys.editorId: LogValue.fieldName(editorId),
          WorkspaceIoLogKeys.saved: LogValue.boolean(saved),
        }),
      );
      return saved;
    } on Object catch (error) {
      editorPreferenceLogSink(
        EditorPreferenceLogEvent.writeFailed,
        LogFields({WorkspaceIoLogKeys.editorId: LogValue.fieldName(editorId)}),
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
        error: error,
      );
      return false;
    }
  }
}

/// [EditorPreferenceStore] 的 Riverpod 掛點；測試以 override 注入記憶體替身。
final editorPreferenceStoreProvider = Provider<EditorPreferenceStore>((ref) {
  return const SharedPreferencesEditorStore();
});
