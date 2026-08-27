---
id: PROP-006
title: "Container 部署 — Dockerfile + Docker Compose"
status: draft
source: development
proposed_by: "部署便利性需求"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.2.0
priority: P1
evaluation_level: standard

outputs:
  spec_refs: []
  usecase_refs: [UC-08]
  ticket_refs: []

related_proposals: [PROP-001]
supersedes: null
---

# PROP-006: Container 部署 — Dockerfile + Docker Compose

## 需求來源

教學模組四 [Container 部署設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/container-deployment.md) 定義了 Docker 部署 collector 的完整設計。開源使用者需要 `docker run` 一行部署，不需要安裝 Go 或管理 binary 版本。

教學依據：
- [模組四：Container 部署設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/container-deployment.md) — Dockerfile、volume mount、graceful shutdown、資源限制、效能對照

## 問題描述

目前 collector 只能從原始碼編譯執行。開源使用者需要安裝 Go toolchain 才能使用，部署門檻高。Container image 讓使用者一行命令啟動，且隔離於 host 環境。

## 範圍界定

### 本提案要做的（In Scope）

**Dockerfile**：

1. Multi-stage build — build stage 編譯、runtime stage 只含 binary
   - `CGO_ENABLED=0`（pure Go，跨平台）
   - 非 root user（UID 1000）
   - Image 大小目標 < 25MB

**Docker Compose**：

2. 完整的 `docker-compose.yml` 範例
   - Volume mount：`/data`（read-write，SQLite DB）、`/config`（read-only，設定檔）
   - Port mapping：`8080:8080`
   - Resource limits：memory 256M、CPU 0.5
   - `restart: unless-stopped`
   - `stop_grace_period: 30s`（WAL checkpoint 需要時間）
   - Healthcheck：`wget --spider http://localhost:8080/health`

**Graceful Shutdown**：

3. SIGTERM handler 序列
   - 停止接受新 request → 等待 in-flight → flush pending writes → WAL checkpoint → close DB → exit

**文件**：

4. `collector/README.md` 的 Docker 快速啟動段
5. Volume mount 權限設定指引（`chown 1000:1000`）

### 本提案不做的（Out of Scope）

- Container image 發佈到 Docker Hub / GHCR（需 CI/CD pipeline）
- Kubernetes manifest（Helm chart / kustomize）
- ARM image（multi-arch build，第二階段）
- Container 內的 HTTPS termination（用 reverse proxy）

## 驗收條件

- [ ] `docker build -t monitor-collector .` 成功，image < 25MB
- [ ] `docker run -v ./data:/data -p 8080:8080 monitor-collector` 啟動成功
- [ ] `GET /health` 回傳正常狀態
- [ ] `docker stop` 後 SQLite DB 完整（WAL checkpoint 完成）
- [ ] Volume mount 後寫入效能降幅 < 15%（vs 同機 binary）
- [ ] 非 root user 執行（`docker exec ... whoami` 回傳 `monitor`）
- [ ] Docker Compose `up -d` 啟動、`down` 關閉皆正常
- [ ] Container crash 後自動重啟（`restart: unless-stopped`）

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Overlay fs 寫入效能降 40% | 寫入吞吐受限 | Volume mount 繞過 overlay（教學已量化） |
| SIGKILL 時 channel 中事件遺失 | 少量事件丟失 | WAL crash recovery 保護已寫入部分；增加 stop_grace_period |
| alpine base 缺少 debug 工具 | 排錯困難 | 保留 alpine（有 shell）不用 scratch |

## PaaS 部署延伸

教學的[部署光譜](https://github.com/tarrragon/blog/blob/main/content/monitoring/06-commercial-comparison/deployment-spectrum.md)定義的路徑 C（PaaS）跑的是和本提案相同的 container image、部署到 Railway / Fly.io / Render。PaaS 平台管 server provisioning 和 TLS，collector 程式碼不需修改。

PaaS 特定考量：
- Persistent volume：Railway Hobby 含 1GB、Fly.io Free 含 1GB（限單 region）— SQLite WAL 需要持久化
- Render 免費方案無 persistent disk、不適合 SQLite backend
- 部署方式從 `docker compose up` 改為 `git push` 觸發
