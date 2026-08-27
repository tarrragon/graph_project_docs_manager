---
id: SPEC-011
title: "BookRepository 介面契約"
status: draft
source_proposal: null
created: "2026-07-16"
updated: "2026-07-16"
version: "1.0"
owner: ""

domain: library
subdomain: null

related_usecases: [UC-02, UC-05]
related_specs: [SPEC-003, SPEC-006]
implements_requirements: []
depends_on_domains: []
---

# BookRepository 介面契約

## 概述

定義 library domain 書籍資料存取的介面契約，涵蓋介面組成、契約型別語言約束，與 `watchBooks()` 資料變更觀測出口的行為語意。本規格為 repository 契約的 canonical 載體；「資料變更傳播 vs 領域事件」的職責邊界見 `docs/event-driven-architecture-design.md`「資料變更傳播（State Propagation）」章。

撰寫原則：機制寫語意不寫實作——本規格定義可觀測、可測試的行為語意（emit 時機、初始值、資源釋放），不約束實作選擇。

---

## 介面組成

`BookRepository`（`lib/domains/library/repository/book_repository.dart`）為組合介面：

| 組成 | 職責 |
|------|------|
| `BaseBookRepository` | 基礎 CRUD（addBook / updateBook / deleteBook / getAllBooks / findById 等） |
| `ExtendedBookRepository` | 擴展查詢與批次操作 |
| `BookQueryPort` | Service 層精簡查詢介面（ISP） |
| 相容性方法 | `saveBook` / `getBookById` / `deleteBookById`（委派至對應基礎方法） |
| 交換格式方法 | `importInterchange` / `readTagTree`（book-interchange-v1 匯入匯出支援） |
| 觀測出口 | `watchBooks()`（本規格核心，見下節） |

## 契約型別語言約束

介面簽名僅允許以下型別語言，禁止框架與基礎設施型別洩漏進 domain 介面：

| 型別 | 是否允許 |
|------|---------|
| Dart 標準庫（`dart:async` 的 `Future` / `Stream` 等） | 允許 |
| Domain entity 與 value object（`Book`、`BookId` 等） | 允許 |
| Riverpod 型別（`StreamProvider` / `Ref` / `AsyncValue`） | 禁止 |
| SQLite / sqflite 型別（`Database` 等） | 禁止 |

## watchBooks 觀測出口契約 (BR)

### BR-1：全部寫入方法觸發 emit

任何透過 repository 完成的書庫寫入操作（addBook、updateBook、deleteBook、addBooks、importInterchange、markBooksAsEnriched 等，含既有與未來新增的寫入方法），完成後必須向 `watchBooks()` 的訂閱者推送最新完整書單。

- 推送內容為當前完整書單（`List<Book>`），非增量差異。
- 新增寫入路徑時自動納入此契約，禁止出現「寫入成功但訂閱者收不到變更」的路徑。

### BR-2：訂閱者先收到當前書單

訂閱資料變更流的消費者，必須在收到後續變更前，先收到訂閱當下的完整書單（初始值），避免衍生視圖在首次寫入前呈現空白或 stale 狀態。

初始值語意的落點分層：repository 的 `watchBooks()` 本體為變更通知流（寫入觸發推送）；「訂閱先收當前書單」由組裝層（DI 層的 Stream 包裝 Provider，先取得當前書單推送、再接續轉發變更流）保證。消費端（ViewModel `ref.watch`）觀察到的整體語意為：訂閱即得當前書單，之後隨每次寫入收到最新書單。

### BR-3：支援多訂閱者

`watchBooks()` 為可多訂閱的廣播流：多個消費者可同時訂閱，同一次資料變更所有訂閱者皆收到相同的最新書單。

### BR-4：close 釋放資源

repository 關閉（`close()`）時必須釋放觀測出口資源：

- close 後不得再向訂閱者推送任何事件。
- close 後既有訂閱可安全取消，不拋出例外。
- close 後的寫入操作不得因觀測出口已釋放而中斷（觀測推送靜默略過，不影響寫入本身的成敗語意）。

## 驗證依據

| 契約 | 驗證測試 |
|------|---------|
| BR-1（寫入後收到最新書單） | `test/unit/infrastructure/database/sqlite_book_repository_watch_test.dart`「寫入後 stream 收到最新書單」 |
| BR-3（多訂閱者） | 同上「多訂閱者同時收到最新書單」 |
| BR-4（close 釋放） | 同上「dispose 後無洩漏，close 後 stream 不再送出事件」 |

---

## 相關規格

- `docs/event-driven-architecture-design.md` — 資料變更傳播 vs 領域事件職責邊界、衍生視圖 reactive 通則
- SPEC-003：`docs/spec/export/library-export.md` — BR-10 衍生統計 reactive 一致性（引用本契約與 App-wide 通則）
- SPEC-006：`docs/spec/library/dual-mode-display.md` — 書庫展示（watchBooks 的主要消費場景之一）

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-02：匯出書庫資料（E1 資料管理頁統計即時更新）
- UC-05：雙模式書庫展示

---

**Last Updated**: 2026-07-16 | **Version**: 1.0 — 初始建立：BookRepository 介面組成、契約型別語言約束、watchBooks 觀測出口契約 BR-1~4（依 0.38.1-W1-102 實作與測試），依 W1-101 方案 A 定向（0.38.1-W1-105）
