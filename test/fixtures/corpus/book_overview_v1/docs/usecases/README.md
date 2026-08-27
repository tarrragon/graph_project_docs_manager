# 用例（Use Cases）

用例文件目錄。定義使用場景、驗收標準和例外處理，供測試設計和驗收參考。

> UseCase 是**跨 domain** 的使用場景，一個 UC 可能涉及多個 domain。

## 使用方式

建立新用例時，從 Skill 模板複製：

```bash
cp .claude/skills/doc/templates/usecase-template.md docs/usecases/UC-{XX}-{簡短描述}.md
```

> 模板規範和欄位說明見 `.claude/skills/doc/references/usecases.md`

## 用例索引

| 用例 ID | 名稱 | 平台 | Extension 狀態 | 相關 Spec |
|---------|------|------|---------------|-----------|
| [UC-01](UC-01-import.md) | 匯入 Chrome Extension 書庫資料 | both | implemented | SPEC-004, SPEC-002 |
| [UC-02](UC-02-export.md) | 匯出書庫資料 | both | implemented | SPEC-004 |
| [UC-03](UC-03-isbn-scan.md) | ISBN 條碼掃描新增書籍 | app | not-applicable | - |
| [UC-04](UC-04-search-enrich.md) | 關鍵字搜尋補充書籍資訊 | both | partial | SPEC-002, SPEC-008 |
| [UC-05](UC-05-library-display.md) | 雙模式書庫展示系統 | both | implemented | SPEC-008, SPEC-006 |
| [UC-06](UC-06-loan-management.md) | 借閱管理系統 | app | not-applicable | SPEC-004 |
| [UC-07](UC-07-sync.md) | 跨平台資料同步準備 | both | partial | SPEC-004, SPEC-003 |
| [UC-08](UC-08-error-handling.md) | 系統錯誤處理與恢復 | both | implemented | SPEC-001, SPEC-007 |
| [UC-09](UC-09-auto-full-library-extraction.md) | 全自動化書庫提取 | chrome-extension | planned | - |
| [UC-10](UC-10-multi-platform-detection.md) | 多書城偵測與切換 | chrome-extension | planned | SPEC-STORAGE-ISOLATION |

## 平台歸屬說明

| 標記 | 說明 |
|------|------|
| both | Chrome Extension 和 Flutter APP 都適用 |
| app | 僅 Flutter APP（如需相機、SQLite 等） |
| extension | 僅 Chrome Extension |

## Extension 實作狀態

| 狀態 | 說明 | 數量 |
|------|------|------|
| implemented | Chrome Extension 已完整實作 | 4 |
| partial | 部分實作或概念相通但細節不同 | 2 |
| not-applicable | 不適用於 Chrome Extension | 2 |

## 雙 UC 系統關係說明

本專案存在兩套 UC 編號系統，來源於不同開發階段，編號重疊但語意不同。

### 兩套系統對照

| 項目 | v1 基線 UC | APP 版 UC（本目錄） |
|------|-----------|-------------------|
| 檔案位置 | `docs/use-cases.md`（單一檔案） | `docs/usecases/UC-*.md`（原子化檔案） |
| 原始來源 | Chrome Extension v1.0 規格 | `docs/app-use-cases.md`（已原子化至本目錄） |
| UC 數量 | 7 個（UC-01 ~ UC-07） | 12 個（UC-01 ~ UC-12） |
| 適用範圍 | 僅 Chrome Extension（Readmoo 單一書城） | Chrome Extension + Flutter APP（多書城） |
| 維護狀態 | v1.0 基線凍結，不再新增 UC | 活躍維護，隨功能擴展新增 |
| 引用場景 | CLAUDE.md 里程碑 v1.0 驗收參考 | 新功能開發的規格依據、測試設計基礎 |

### 編號重疊對照表

v1 與 APP 版的 UC-01 ~ UC-07 編號相同但語意不同：

| 編號 | v1 基線（`docs/use-cases.md`） | APP 版（`docs/usecases/`） |
|------|-------------------------------|---------------------------|
| UC-01 | 首次安裝與設定 | 匯入 Chrome Extension 書庫資料 |
| UC-02 | 日常書籍資料提取 | 匯出書庫資料 |
| UC-03 | 資料匯出與備份 | ISBN 條碼掃描新增書籍 |
| UC-04 | 資料匯入與恢復 | 關鍵字搜尋補充書籍資訊 |
| UC-05 | 跨設備資料同步 | 雙模式書庫展示系統 |
| UC-06 | 書籍資料檢視與管理 | 借閱管理系統 |
| UC-07 | 錯誤處理與恢復 | 跨平台資料同步 |
| UC-08 | （不存在） | 系統錯誤處理與恢復 |
| UC-09 | （不存在） | 全自動化書庫提取 |
| UC-10 | （不存在） | 多書城偵測與切換 |
| UC-11 | （不存在） | 跨書城合併檢視 |
| UC-12 | （不存在） | 單一書城資料管理 |

### 引用時的區分方式

引用 UC 編號時須標明所屬系統，避免混淆：

| 引用格式 | 指向 |
|---------|------|
| `docs/use-cases.md` UC-01 | v1 基線「首次安裝與設定」 |
| `docs/usecases/UC-01-import.md` | APP 版「匯入 Chrome Extension 書庫資料」 |

doc CLI（`/doc`）的 `uc list` / `uc verify` 操作以 `docs/usecases/` 原子化檔案為 SSOT，不納管 v1 基線。

## 來源

原始用例文件：`../app-use-cases.md`（保留為歷史參考，內容已原子化至本目錄各 UC-*.md 檔案）
