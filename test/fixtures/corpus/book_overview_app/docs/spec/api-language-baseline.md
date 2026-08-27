---
id: SPEC-API-LANGUAGE-BASELINE
title: "書目 API language 欄位規格基線"
status: baseline
source_proposal: null
created: "2026-07-11"
updated: "2026-07-11"
version: "1.0"
owner: ""
domain: book_info
subdomain: multi_source
related_usecases: []
related_specs: []
---

# 書目 API language 欄位規格基線

**版本**: 1.0
**建立日期**: 2026-07-11
**最後更新**: 2026-07-11
**來源 Ticket**: 0.38.0-W9-006（ANA 盤點）→ 0.38.0-W9-009（本文件）

---

## 1. 概述

本文件記錄 `MultiSourceQueryService` 底下 5 個書目 API adapter 回傳的 `language` 欄位格式，作為未來 API 變更時的比對基線。5 個 API 的原始欄位路徑、格式標準、已知值域皆不一致（3 個用 ISO 639-2 三字母碼、1 個用 ISO 639-1 二字母碼、1 個未映射），下游經 `LanguageCodeNormalizer`（0.38.0-W9-007）統一轉換為 ISO 639-1 後才提供給版本比對、篩選、顯示等消費端使用。

**維護方式**：新增或修改任一 adapter 的 language 解析邏輯時，需同步更新本文件對應章節與「最後驗證日期」。

---

## 2. 各 API 語言欄位規格

### 2.1 Google Books API

| 項目 | 內容 |
|------|------|
| 原始欄位路徑 | `volumeInfo.language` |
| 格式標準 | ISO 639-1（2 字母） |
| 已知值域 | `ja`、`en`、`zh-TW`（含區域碼變體） |
| 轉換邏輯 | 無需轉換，直接讀取字串 |
| Adapter 原始碼 | `lib/infrastructure/google_books/google_books_source_client.dart:114` |
| 最後驗證日期 | 2026-07-11 |

### 2.2 openBD

| 項目 | 內容 |
|------|------|
| 原始欄位路徑 | `onix.DescriptiveDetail.Language[].LanguageCode`（`Language` 可能為單一物件或陣列，逐一嘗試取第一筆非空 `LanguageCode`） |
| 格式標準 | ISO 639-2（3 字母） |
| 已知值域 | `jpn`、`eng` |
| 轉換邏輯 | `_extractLanguageCode` 遍歷 `Language` 清單，回傳第一筆非空 `LanguageCode`（0.38.0-W9-002 補齊） |
| Adapter 原始碼 | `lib/infrastructure/open_bd/open_bd_api_client.dart:241` |
| 最後驗證日期 | 2026-07-11 |

### 2.3 NDL Search（国立国会図書館サーチ）

| 項目 | 內容 |
|------|------|
| 原始欄位路徑 | RSS `item` 下的 `dc:language` 元素 |
| 格式標準 | ISO 639-2（3 字母） |
| 已知值域 | `jpn` |
| 轉換邏輯 | 無需轉換，直接讀取元素文字（0.38.0-W9-003 補齊） |
| Adapter 原始碼 | `lib/infrastructure/ndl_search/ndl_search_api_client.dart:135` |
| 最後驗證日期 | 2026-07-11 |

### 2.4 NBINet Primo

| 項目 | 內容 |
|------|------|
| 原始欄位路徑 | `docs[].pnx.display.language`（`_firstString` 取第一筆值，`display.language` 可能為單一字串或陣列） |
| 格式標準 | 不定——依館藏編目來源而異，觀察到的實際值為 ISO 639-2 B 碼（3 字母），未見統一規範聲明 |
| 已知值域 | `chi`、`eng`、`jpn` |
| 轉換邏輯 | 無轉換，直接讀取字串；格式不穩定為已知風險，需 `LanguageCodeNormalizer` 的未知碼 fallback 處理 |
| Adapter 原始碼 | `lib/infrastructure/nbinet/nbinet_primo_api_client.dart:189` |
| 最後驗證日期 | 2026-07-11 |

### 2.5 Open Library

| 項目 | 內容 |
|------|------|
| 原始欄位路徑 | 未映射——`OpenLibraryDto`（`/isbn/{isbn}.json`）與 `OpenLibrarySearchDoc`（`/search.json`）皆未讀取任何語言相關欄位 |
| 格式標準 | 不適用（`BookEnrichmentData.language` 恆為 `null`） |
| 已知值域 | 不適用 |
| 轉換邏輯 | 無（尚未實作，見 0.38.0-W9-008） |
| Adapter 原始碼 | `lib/infrastructure/open_library/open_library_dto.dart`（`toBookEnrichmentData` 未賦值 `language`） |
| 最後驗證日期 | 2026-07-11 |

**備註**：Open Library 公開 API 文件描述 `/isbn/{isbn}.json` 含 `languages` 陣列（如 `{"key": "/languages/jpn"}`）、`/search.json` 含 `language` 陣列（ISO 639-2），但本文件僅記錄原始碼實際行為（未映射），未對外部 API 回傳格式做未驗證的假設；實際映射欄位與格式需在 0.38.0-W9-008 實作時以真實 API 回應驗證後回填本節。

---

## 3. 格式比較與歸一化基準

| API Source | 欄位路徑 | 格式標準 | 已映射到 `language` |
|-----------|---------|---------|-------------------|
| Google Books | `volumeInfo.language` | ISO 639-1（2 字母） | 是 |
| openBD | `onix.DescriptiveDetail.Language[].LanguageCode` | ISO 639-2（3 字母） | 是 |
| NDL Search | `dc:language` | ISO 639-2（3 字母） | 是 |
| NBINet Primo | `pnx.display.language` | 不定（觀察值為 639-2 B 碼） | 是 |
| Open Library | 無 | 不適用 | 否（恆為 `null`） |

**歸一化後統一格式：ISO 639-1（2 字母）**

依 0.38.0-W9-006 設計結論，`LanguageCodeNormalizer`（`lib/domains/book_info/services/language_code_normalizer.dart`）在 `MultiSourceQueryService` 單一注入點對上述 5 個 source 的 `BookEnrichmentData.language` 統一轉換為 ISO 639-1：

- 選用理由：Flutter `Locale` 原生使用 ISO 639-1（如 `Locale('ja')`），統一為 639-1 可消除 adapter 層到 UI/l10n 層的格式轉換。
- 轉換規則：2 字母碼直接小寫化；3 字母碼查 639-2 → 639-1 映射表（如 `jpn` → `ja`）；未知碼或映射表無對應時保留原值小寫化（graceful fallback）。
- `null`／空字串輸入回傳 `null`。

下游消費端（如 `version_comparison_sheet.dart` 的 `==` 語言相等性比對）應以 normalize 後的值為準，不應直接使用 adapter 回傳的原始 `language` 值比對。

---

## 4. 變更歷史

| 日期 | 版本 | 變更內容 | 觸發 Ticket |
|------|------|---------|------------|
| 2026-07-11 | 1.0 | 初版建立，記錄 5 個 API 的 language 欄位規格與歸一化基準 | 0.38.0-W9-006 → 0.38.0-W9-009 |

---

## 相關文件

- `.claude/error-patterns` — 若後續發現 language 欄位相關的跨專案錯誤模式，記錄於此
- `lib/domains/book_info/services/language_code_normalizer.dart`（0.38.0-W9-007 實作後生效）
- `lib/infrastructure/multi_source/multi_source_query_service.dart` — normalize 注入點
