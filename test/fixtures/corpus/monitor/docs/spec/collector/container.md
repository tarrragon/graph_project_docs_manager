---
id: SPEC-012
title: "Container 部署"
status: draft
source_proposal: PROP-006
created: "2026-06-22"
updated: "2026-06-22"
version: "1.0"
owner: ""

domain: collector
subdomain: deployment

related_usecases: [UC-08]
related_specs: [SPEC-007, SPEC-002]
implements_requirements: []
depends_on_domains: [core]
---

# Container 部署

## 概述

定義 Collector 的 Docker 部署規格：multi-stage Dockerfile、Docker Compose 範例、volume mount 設計、graceful shutdown 序列、資源限制。目標是開源使用者 `docker run` 一行部署，不需安裝 Go toolchain。

教學依據：[模組四：Container 部署設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/container-deployment.md)

## 功能需求

### FR-01: Multi-stage Dockerfile

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-006 |
| 對應用例 | - |

**描述**：Dockerfile 使用 multi-stage build。Build stage 用 `golang:1.22-alpine` 編譯 binary（`CGO_ENABLED=0` pure Go），runtime stage 用 `alpine:3.20` 只包含 binary + CA 憑證 + timezone 資料。

**規格**：

| 項目 | 值 |
|------|-----|
| Build base | `golang:1.22-alpine` |
| Runtime base | `alpine:3.20` |
| CGO | `CGO_ENABLED=0` |
| 執行使用者 | `monitor`（UID 1000，非 root） |
| Exposed port | 8080 |
| Entrypoint | `["collector"]` |
| Image 大小目標 | < 25MB |

**驗收標準**：

- [ ] `docker build -t monitor-collector .` 成功
- [ ] 最終 image 大小 < 25MB
- [ ] `docker exec <container> whoami` 回傳 `monitor`
- [ ] Container 內無 Go toolchain（只有 binary）

### FR-02: Volume Mount 設計

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-006 |
| 對應用例 | - |

**描述**：兩個 mount point 分離資料和設定，職責和權限不同。

| Mount | Container 路徑 | Host 路徑範例 | 權限 | 內容 |
|-------|---------------|-------------|------|------|
| 資料 | `/data` | `./monitor-data` | read-write | SQLite DB + WAL + JSONL 匯出檔 |
| 設定 | `/config` | `./monitor-config` | read-only | `collector.yaml` + `rules.yaml` |

**環境變數對應**：

| 環境變數 | 預設值 | 說明 |
|---------|--------|------|
| `MONITOR_STORAGE` | `sqlite` | Storage backend |
| `MONITOR_DB_PATH` | `/data/events.db` | SQLite 檔案路徑 |
| `MONITOR_CONFIG` | `/config/collector.yaml` | 設定檔路徑 |
| `MONITOR_PORT` | `8080` | HTTP 監聽 port |

環境變數覆蓋 YAML 設定檔，CLI flag 覆蓋環境變數。三層優先級：CLI flag > 環境變數 > YAML 設定檔 > 預設值。

**驗收標準**：

- [ ] `docker run -v ./data:/data -p 8080:8080 monitor-collector` 啟動成功
- [ ] SQLite DB 寫入 host 的 `./data/` 目錄
- [ ] Container 刪除後資料保留在 host volume
- [ ] `/config` mount 為 read-only，collector 不嘗試寫入

### FR-03: Graceful Shutdown 序列

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-006 |
| 對應用例 | - |

**描述**：`docker stop` 送 SIGTERM，collector 收到後按序列執行 shutdown。序列保證已接收的事件不丟失、SQLite 資料庫完整。

**Shutdown 序列**：

| 步驟 | 動作 | 超時 |
|------|------|------|
| 1 | 停止接受新的 HTTP request（listener close） | 立即 |
| 2 | 等待 in-flight request 完成 | 5 秒 |
| 3 | Flush pending writes（channel 中排隊的事件） | 5 秒 |
| 4 | 停止定期 job（downsample / purge / rule eval） | 立即 |
| 5 | SQLite WAL checkpoint（TRUNCATE mode） | 15 秒 |
| 6 | 關閉 DB connection | 立即 |
| 7 | 退出（exit 0） | - |

**總超時**：步驟 2-5 合計不超過 25 秒，搭配 Docker Compose `stop_grace_period: 30s` 留有餘量。

**SIGKILL 恢復**：若 SIGKILL 在 shutdown 序列中發生（超過 `stop_grace_period`），SQLite WAL 設計保證 DB 一致性——下次開啟時自動 replay WAL。但 channel 中尚未寫入的事件（已回 HTTP 202 但還在 buffer 中）會丟失。

**驗收標準**：

- [ ] `docker stop` 後 SQLite DB 完整（WAL checkpoint 完成）
- [ ] Shutdown 日誌顯示完整序列（每步驟一行 log）
- [ ] In-flight request 在 shutdown 期間完成回應（不被中斷）
- [ ] SIGKILL 後重啟，DB 自動 recovery 不損壞

### FR-04: Docker Compose 範例

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-006 |
| 對應用例 | - |

**描述**：提供完整的 `docker-compose.yml` 範例，包含 volume mount、port mapping、resource limits、healthcheck、restart policy。

**規格**：

```yaml
services:
  collector:
    image: tarrragon/monitor:latest
    ports:
      - "8080:8080"
    volumes:
      - ./monitor-data:/data
      - ./monitor-config:/config:ro
    environment:
      - MONITOR_STORAGE=sqlite
      - MONITOR_DB_PATH=/data/events.db
    restart: unless-stopped
    stop_grace_period: 30s
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

**驗收標準**：

- [ ] `docker compose up -d` 啟動成功
- [ ] `docker compose down` 關閉正常（graceful shutdown）
- [ ] Container crash 後自動重啟（`restart: unless-stopped`）
- [ ] Healthcheck 正常回報（`docker compose ps` 顯示 healthy）

### FR-05: Healthcheck 規格

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-006 |
| 對應用例 | - |

**描述**：Container 的 healthcheck 呼叫 `GET /health`（SPEC-002 FR-03）。Docker 用此判斷 container 是否真正可用（不只 process alive）。

| 參數 | 值 | 說明 |
|------|-----|------|
| interval | 30s | 檢查間隔 |
| timeout | 5s | 單次檢查超時 |
| retries | 3 | 連續失敗次數後標記 unhealthy |
| start_period | 10s | 啟動後等待期（首次檢查前） |

**驗收標準**：

- [ ] Container 啟動後 healthcheck 轉為 healthy
- [ ] Collector 停止回應 `/health` 時，Docker 標記 unhealthy

## 非功能需求

### NFR-01: Volume Mount 效能

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | Volume mount 寫入吞吐降幅 < 15%（vs 同機 binary） |

**描述**：Volume mount 繞過 overlay filesystem，寫入效能接近同機 binary。教學量化數據：volume mount 降幅 ~10%，overlay 降幅 ~40%。

**驗收方式**：在同一機器上分別跑 `collector benchmark write`（binary 直接執行 vs container + volume mount），比較 throughput 差異。

### NFR-02: Image 安全

| 項目 | 值 |
|------|-----|
| 類型 | 安全性 |
| 指標 | 非 root 執行 + 最小 base image |

**描述**：Container 以非 root user（UID 1000）執行。Alpine base image 最小化攻擊面。不含 Go toolchain、不含非必要套件。

## 介面規格

### Dockerfile 位置

```
collector/Dockerfile
```

### Docker Compose 位置

```
collector/docker-compose.yml
```

### Host 目錄準備

使用者首次部署前需執行：

```bash
mkdir -p monitor-data monitor-config
chown 1000:1000 monitor-data
```

`monitor-config/` 放置 `collector.yaml`（可選，不放則使用預設值）和 `rules.yaml`（可選）。

### 環境變數與 Config 對照

| 環境變數 | collector.yaml 路徑 | CLI flag | 預設值 |
|---------|---------------------|----------|--------|
| `MONITOR_STORAGE` | `storage.backend` | `--storage` | `sqlite` |
| `MONITOR_DB_PATH` | `storage.sqlite.path` | `--db-path` | `/data/events.db` |
| `MONITOR_CONFIG` | - | `--config` | `/config/collector.yaml` |
| `MONITOR_PORT` | `server.port` | `--port` | `8080` |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| Pure Go build | `CGO_ENABLED=0`，無 CGO 依賴 | 跨平台 image，但 SQLite 效能為 pure Go 等級 |
| 單一 binary | 無外部 runtime 依賴 | Image 最小化 |
| Non-root execution | UID 1000 `monitor` user | Host volume 需對應 ownership |
| Volume mount 強制建議 | 不用 volume = 資料隨 container 刪除 | 文件和 log 需明確警告 |
| stop_grace_period 30s | 給 WAL checkpoint 足夠時間 | Docker Compose 設定 |
| 本 Spec 不含 ARM/multi-arch | 第二階段 | 初版僅 amd64 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本，從 PROP-006 + 教學 container-deployment.md 萃取 |
