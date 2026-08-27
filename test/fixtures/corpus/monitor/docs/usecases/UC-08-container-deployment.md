---
id: UC-08
title: "Container 部署"
status: draft
source_proposal: PROP-006
created: "2026-06-23"
updated: "2026-06-23"
version: "1.0"

primary_actor: "開源使用者 / 運維"
secondary_actors: ["Docker Engine", "SQLite Storage (Go)"]

platform: "both"
extension_status: "not-applicable"

related_specs: [SPEC-012, SPEC-007, SPEC-002]
related_usecases: [UC-01]
ticket_refs: [0.2.0-W1-003.3, 0.2.0-W3-003]
---

# UC-08: Container 部署

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-08 |
| 用例名稱 | Container 部署 |
| 主要行為者 | 開源使用者 / 運維 |
| 利益關係人 | 開源使用者（一行 docker run 部署，免裝 Go toolchain）；運維（資料持久化於 host volume、優雅關閉不丟資料） |
| 前置條件 | host 已安裝 Docker；已準備 `monitor-data`（rw）與 `monitor-config`（ro）目錄 |
| 成功保證 | collector 以非 root 容器運行、SQLite 資料寫入 host volume、`docker stop` 觸發優雅關閉使 DB 完整、healthcheck 正確反映可用性 |

## 主要成功場景

1. **建置 image（build）**
   - 使用者執行 `docker build -t monitor-collector ./collector`
   - 系統 multi-stage 編譯（`golang:1.22-alpine` build，`CGO_ENABLED=0` pure Go），runtime 為 `alpine:3.20` 僅含 binary + CA + tzdata，最終 image < 25MB

2. **啟動容器（run + volume）**
   - 使用者執行 `docker run -v ./monitor-data:/data -v ./monitor-config:/config:ro -p 8080:8080 monitor-collector`
   - 容器以非 root user `monitor`（UID 1000）運行，SQLite 寫入 host 的 `./monitor-data/`

3. **環境變數覆蓋設定**
   - 使用者以 `-e MONITOR_DB_PATH=/data/events.db` 等覆蓋設定
   - 系統依三層優先級解析：CLI flag > 環境變數 > YAML 設定檔 > 預設值

4. **優雅關閉（graceful shutdown）**
   - 使用者執行 `docker stop`，Docker 送 SIGTERM
   - 系統按 7 步驟序列關閉：停止接受新請求 → 等待 in-flight → flush pending writes → 停止定期 job → SQLite WAL checkpoint(TRUNCATE) → 關閉 DB connection → exit 0，每步驟一行 log

5. **健康檢查（healthcheck）**
   - Docker 依 compose healthcheck 定期呼叫 `GET /health`
   - 啟動後轉為 healthy；collector 停止回應時標記 unhealthy

## 替代場景

### 08a: Docker Compose 一鍵部署

| 步驟 | 行為 |
|------|------|
| 1 | 使用者執行 `docker compose up -d`（含 volume / port / resource limits / healthcheck / restart policy） |
| 2 | 系統啟動，`docker compose ps` 顯示 healthy |
| 3 | Container crash 時依 `restart: unless-stopped` 自動重啟 |
| 4 | `docker compose down` 觸發優雅關閉 |

### 08b: 容器刪除後資料保留

| 步驟 | 行為 |
|------|------|
| 1 | 使用者刪除容器（`docker rm`） |
| 2 | SQLite DB 仍保留在 host 的 `./monitor-data/` volume |
| 3 | 重新 run 容器掛回同 volume，資料延續 |

## 例外場景

### EX-08-01: SIGKILL 在優雅關閉期間發生

| 項目 | 值 |
|------|-----|
| 觸發條件 | 關閉序列超過 `stop_grace_period`（30s），Docker 送 SIGKILL |
| 處理方式 | SQLite WAL 設計保證 DB 一致性，下次開啟自動 replay WAL |
| 使用者提示 | 重啟後 DB recovery 日誌 |
| 恢復策略 | 接受 channel 中已回 202 但未落盤的事件遺失（極端情境） |

### EX-08-02: Config volume 被嘗試寫入

| 項目 | 值 |
|------|-----|
| 觸發條件 | `/config` mount 為 read-only，collector 嘗試寫入 |
| 處理方式 | collector 不寫入 `/config`，僅讀取設定 |
| 使用者提示 | 文件明示 `/config` 為唯讀 |
| 恢復策略 | 設定變更改 host 端 `monitor-config/` 後重啟容器 |

### EX-08-03: 未掛 volume 直接運行

| 項目 | 值 |
|------|-----|
| 觸發條件 | 使用者 `docker run` 未指定 `-v` volume |
| 處理方式 | 資料寫入容器內層，容器刪除即遺失 |
| 使用者提示 | 文件與啟動 log 明確警告需掛 volume |
| 恢復策略 | 改用 volume 重新部署 |

## 驗收條件

### 功能驗收

- [ ] `docker build` 成功且 image < 25MB、容器內以 `monitor`（非 root）運行
- [ ] `docker run` 掛 volume 後 SQLite 寫入 host 目錄，容器刪除資料保留
- [ ] `docker stop` 觸發完整 7 步驟優雅關閉，DB 完整
- [ ] healthcheck 正確反映 healthy / unhealthy

### 邊界條件

- [ ] 環境變數三層優先級正確（CLI flag > env > YAML > 預設）
- [ ] SIGKILL 後重啟，WAL 自動 recovery 不損壞
- [ ] `/config` mount 唯讀，collector 不嘗試寫入

### 資訊鏈整合測試（核心要求）

| 資訊鏈 | 整合測試 |
|--------|---------|
| docker build → run + volume → 運行接收事件 → docker stop 優雅關閉 → 資料完整性驗證 | IT-08-01（待建，Phase 2 BDD 整合測試 ticket） |

### 效能要求

| 指標 | 目標值 |
|------|--------|
| Volume mount 寫入吞吐降幅 | < 15%（vs 同機 binary；overlay 降幅 ~40% 故強制 volume） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-23 | 初始版本，從 SPEC-012 + PROP-006 + 教學 container-deployment.md 萃取（v0.1.0 BDD 模式對齊，0.2.0-W1-006） |
