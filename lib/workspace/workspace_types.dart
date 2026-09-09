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
