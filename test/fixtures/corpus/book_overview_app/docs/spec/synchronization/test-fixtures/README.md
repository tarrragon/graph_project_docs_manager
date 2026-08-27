# QR 離線同步共用測試 Fixtures

本目錄包含兩端（Extension 編碼 / App 解碼）共用的測試參照資料。
任何一端的測試都必須能通過這些 fixtures 的驗證。

## 用途

- Extension 端測試：編碼結果必須與 fixture 的 expected 輸出一致
- App 端測試：解碼 fixture 的 encoded 資料必須還原出 expected 原文

## Fixtures 清單

| Fixture | 說明 |
|---------|------|
| `frame-format-vectors.json` | Frame header 編解碼向量（含 magic、version、各欄位） |
| `sync-meta-schema.json` | sync_meta 結構驗證（合法/非法範例） |
| `merge-scenarios.json` | 合併邏輯各種邊界案例 |
