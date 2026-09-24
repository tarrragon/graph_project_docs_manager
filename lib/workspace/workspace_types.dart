/// `WorkspaceRepository` 的 value types：狀態建模，與外部系統互動正交。
///
/// 提取自 `workspace_repository.dart`（`0.1.0-W3-147`）。此檔只承載純資料
/// 形狀，無外部依賴；三個 port 介面、其 private default adapter、
/// `WorkspaceRepository` 本體留在原檔（`0.1.0-W3-133` 已裁定同檔為本專案
/// 接縫形態）。
library;

/// 工作資料夾的狀態。
sealed class WorkspaceState {
  const WorkspaceState();
}

/// 從未選過資料夾。
class WorkspaceUnset extends WorkspaceState {
  const WorkspaceUnset();
}

/// 資料夾存在且可讀。
class WorkspaceReady extends WorkspaceState {
  const WorkspaceReady(this.path);
  final String path;
}

/// 先前選過資料夾，但現在無法使用（已刪除、外接磁碟未掛載、權限變更）。
/// [lastKnownPath] 供 UI 提示使用者是哪一個。
///
/// [reason] 是使用者可見欄位（`main.dart` 的 `_WorkspaceBanner` 直接以
/// `l10n.workspaceUnavailable(reason)` 渲染）：契約規定只能是固定文案
/// 常數（見 `workspace_repository.dart` 的 `_reasonFolderMissing` 等），
/// 禁止插值原始例外字串或平台回傳的 OS 語系訊息——那些內容語言不受控，
/// 且對使用者無行動意義。
class WorkspaceUnavailable extends WorkspaceState {
  const WorkspaceUnavailable({
    required this.lastKnownPath,
    required this.reason,
  });
  final String? lastKnownPath;
  final String reason;
}

/// `chooseFolder()` 的結局。與 [WorkspaceState] 正交：
/// [WorkspaceState] 描述「資料夾現在能不能用」，本型別描述「這次選取這個
/// 動作的結局」。
sealed class ChooseFolderResult {
  const ChooseFolderResult();
}

/// 使用者關閉面板未選取。對應現行 null 回傳。
class ChooseFolderCancelled extends ChooseFolderResult {
  const ChooseFolderCancelled();
}

/// 選取面板本身開不起來（MissingPluginException、PlatformException）。
///
/// [reason] 是診斷用欄位（例外字串或訊息），`main.dart` 的呼叫端目前不
/// 消費此欄位——使用者看到的是固定文案 SnackBar，不是 [reason] 本身。
/// 保留 [reason] 是為了讓 `workspace_repository_test.dart` 的失敗分支
/// 斷言（不互相抵扣：日誌與回傳分別驗證）有內容可比對，非死程式碼。
class ChooseFolderUnavailable extends ChooseFolderResult {
  const ChooseFolderUnavailable(this.reason);
  final String reason;
}

/// 已選定且已持久化：下次啟動 restore() 讀得回來。
class ChooseFolderSelected extends ChooseFolderResult {
  const ChooseFolderSelected(this.state);
  final WorkspaceState state;
}

/// 已選定但未能記住：本次可用，下次啟動會回到 WorkspaceUnset，使用者需重選。
///
/// [reason] 是診斷用欄位，`main.dart` 的呼叫端目前不消費此欄位（見
/// [ChooseFolderUnavailable] 文件同一契約）。
class ChooseFolderNotRemembered extends ChooseFolderResult {
  const ChooseFolderNotRemembered({required this.state, required this.reason});
  final WorkspaceState state;
  final String reason;
}

/// 最近開啟過的專案（`workspace.recentProjects` JSON 陣列的單一元素，
/// SPEC-005 §2.4）。[path] 為資料夾絕對路徑，[lastOpenedAt] 為 UTC 時間，
/// 供清單依最近一次開啟時間降冪排序。
class RecentProject {
  const RecentProject({required this.path, required this.lastOpenedAt});
  final String path;
  final DateTime lastOpenedAt;
}

/// `workspace.schemaVersion` 讀取後的遷移判定結果（`0.2.0-W1-021`）。
///
/// 三種結局刻意不共用同一個 `path` 欄位形狀（見 [SchemaMigrationFailed]
/// 沒有攜帶任何 path）——遷移失敗與「無需遷移」若在回傳值上同形，呼叫端
/// 就會誤把失敗當成正常的舊資料而繼續使用未經驗證的內容。
sealed class SchemaMigrationResult {
  const SchemaMigrationResult();
}

/// 版號已是目前版本，資料結構不需轉換，[path] 可直接使用。
class SchemaCurrent extends SchemaMigrationResult {
  const SchemaCurrent(this.path);
  final String? path;
}

/// 版號落後（含「無版號但已有 path，判定為 v0 舊資料」的情形），已就地轉換
/// 為目前版本的結構，[path] 可直接使用。
class SchemaMigrated extends SchemaMigrationResult {
  const SchemaMigrated(this.path);
  final String? path;
}

/// 版號無法辨識或轉換邏輯本身失敗（例如版號比目前版本更新，代表資料是被
/// 未來版本寫入的，本版邏輯不認得其結構）。[storedVersion] 保留供日誌診斷，
/// 不做為使用者可見文案。
class SchemaMigrationFailed extends SchemaMigrationResult {
  const SchemaMigrationFailed(this.storedVersion);
  final int? storedVersion;
}
