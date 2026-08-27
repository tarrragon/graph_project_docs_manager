# 跨專案交換格式驗證協議

**版本**: 1.0.0
**建立日期**: 2026-06-18
**適用格式**: book-interchange-v1 v3.0.0+
**相關 spec**: `docs/spec/book-interchange-v1.md`

---

## 1. 目的

V1（Chrome Extension）與 APP（Flutter）共用 `book-interchange-v1` canonical 格式進行雙向資料交換。任何欄位變更（新增/修改/移除 tag category、readingStatus 態、cover 結構等）都必須經過跨端 round-trip 驗證，確認雙向互通無損（spec C1 約束）。

本協議定義可重複的雙向驗證流程，使格式演化時有標準化的驗證手段。

---

## 2. 雙向驗證架構

```
V1 端                          APP 端
┌─────────────┐                ┌─────────────┐
│ V1 books    │                │ APP books   │
│   ↓ export  │                │   ↓ export  │
│ canonical   │ ──(fixture)──→ │ import+DB   │
│   JSON      │                │   ↓ export  │
│             │ ←─(fixture)── │ canonical   │
│ import      │                │   JSON      │
│   ↓ diff    │                │   ↓ diff    │
│ 比對原始    │                │ 比對原始    │
└─────────────┘                └─────────────┘
```

兩端各自負責：
- **提供** canonical fixture 供對方消費
- **消費** 對方的 canonical fixture 並驗證 round-trip 無損

---

## 3. V1 端職責

### 3.1 提供 fixture 給 APP

| 項目 | 路徑 |
|------|------|
| 生成腳本 | `scripts/generate-v1-canonical-fixture.js` |
| 輸出 fixture | `tests/integration/fixtures/v1-canonical-v3-round-trip.json` |
| 執行指令 | `npm run fixture:v1-canonical` |

**Fixture 內容要求**（涵蓋所有成功標準）：
- 至少 6 本書，涵蓋 readingStatus 六態（SC-2）
- 至少 1 本多 author（SC-3）
- 至少 1 本含 ISBN（SC-3）
- 至少 1 本含 custom tag（SC-4 passthrough）
- format/formatVersion 正確（SC-5）

**更新時機**：spec 欄位變更時重新生成。

### 3.2 消費 APP fixture

| 項目 | 路徑 |
|------|------|
| APP fixture | `tests/integration/fixtures/app-canonical-from-v1-round-trip.json` |
| 測試檔 | `tests/integration/cross-project-round-trip.test.js` |
| 執行指令 | `npm run test:cross-project` |

**測試涵蓋**（23 tests）：
- SC-1：id/title/source 必要欄位無損
- SC-2：readingStatus 六態雙向映射
- SC-3：多 author/ISBN round-trip
- SC-4：_passthrough 保留
- SC-5：formatVersion semver
- 完整 diff：逐本比對原始 vs round-trip 還原

---

## 4. APP 端職責

### 4.1 提供 fixture 給 V1

| 項目 | 路徑 |
|------|------|
| 輸出 fixture | `test/fixtures/output/app-canonical-from-v1.json`（測試副產物） |
| 測試檔 | `test/integration/import_export/v1_canonical_cross_project_test.dart` |
| 執行指令 | `flutter test test/integration/import_export/v1_canonical_cross_project_test.dart` |

APP 端的 fixture 由測試自動生成（SC-5 測試中 `File.writeAsStringSync`）。

### 4.2 消費 V1 fixture

| 項目 | 路徑 |
|------|------|
| V1 fixture | `test/fixtures/import_data/v1-canonical-v3-round-trip.json` |
| 測試檔 | `test/integration/import_export/v1_canonical_cross_project_test.dart` |

**測試涵蓋**（7 tests）：
- SC-1：6 本書全數匯入
- SC-2：readingStatus 六態映射
- SC-3：多 author / ISBN 保留
- SC-5：canonical 結構正確 + round-trip 重匯入無損

---

## 5. 驗證流程（SOP）

### 5.1 格式變更時的完整驗證流程

| 步驟 | 操作 | 產出 |
|------|------|------|
| 1 | V1 端：`npm run fixture:v1-canonical` | 更新 V1 canonical fixture |
| 2 | 複製 V1 fixture 到 APP 端：`cp tests/integration/fixtures/v1-canonical-v3-round-trip.json ~/project/book_overview_app/test/fixtures/import_data/` | APP 端 fixture 更新 |
| 3 | APP 端：`flutter test test/integration/import_export/v1_canonical_cross_project_test.dart` | APP 匯入驗證 + 產出 APP canonical fixture |
| 4 | 複製 APP fixture 回 V1 端：`cp ~/project/book_overview_app/test/fixtures/output/app-canonical-from-v1.json tests/integration/fixtures/app-canonical-from-v1-round-trip.json` | V1 端 fixture 更新 |
| 5 | V1 端：`npm run test:cross-project` | V1 匯入驗證 + 完整 diff |
| 6 | 兩端全綠 → 格式變更通過 | round-trip 驗證完成 |

### 5.2 快速驗證（無格式變更，僅確認現狀）

```bash
# V1 端
npm run test:cross-project

# APP 端
flutter test test/integration/import_export/v1_canonical_cross_project_test.dart
```

### 5.3 觸發條件

以下任一變更必須跑完整驗證流程（§5.1）：

- book-interchange-v1 spec 欄位新增/修改/移除
- tags category 新增/重命名
- readingStatus 態新增
- cover/progress 結構變更
- V1 `book-interchange-v1-adapter.js` 映射邏輯變更
- APP `InterchangeExportService` / `Book.toInterchangeJson()` / 匯入邏輯變更

---

## 6. 成功標準（W5-001 定義，永久適用）

| 標準 | 內容 | 驗證方式 |
|------|------|---------|
| SC-1 | 必要欄位無損（id/title/source） | 逐本 diff = 0 |
| SC-2 | readingStatus 所有態雙向映射正確 | 每態各一本驗證 |
| SC-3 | 多值 metadata round-trip 無損 | 多 author/ISBN 驗證 |
| SC-4 | _passthrough 保留 | APP 不認識的欄位不丟棄 |
| SC-5 | formatVersion semver 正確 | 兩端 parse 版本號成功 |

---

## 7. Fixture 共享慣例

| 方向 | V1 端路徑 | APP 端路徑 |
|------|----------|-----------|
| V1 → APP | `tests/integration/fixtures/v1-canonical-v3-round-trip.json` | `test/fixtures/import_data/v1-canonical-v3-round-trip.json` |
| APP → V1 | `tests/integration/fixtures/app-canonical-from-v1-round-trip.json` | `test/fixtures/output/app-canonical-from-v1.json` |

Fixture 以手動複製方式同步（兩個獨立 repo，無共用 submodule）。

---

**Last Updated**: 2026-06-18 | **Version**: 1.0.0 — 初始建立（W5-002 驗證流程固化）
