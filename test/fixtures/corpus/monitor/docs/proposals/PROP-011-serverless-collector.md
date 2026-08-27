---
id: PROP-011
title: "Serverless Collector 變體 — BaaS + Serverless 部署路徑"
status: draft
source: development
proposed_by: "APP 上線初期零成本部署需求"
proposed_date: "2026-06-24"
confirmed_date: null
target_version: v0.5.0
priority: P3
evaluation_level: standard

outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

related_proposals: [PROP-001, PROP-006, PROP-007]
supersedes: null
---

# PROP-011: Serverless Collector 變體

## 需求來源

教學模組六 [部署光譜](https://github.com/tarrragon/blog/blob/main/content/monitoring/06-commercial-comparison/deployment-spectrum.md) 定義了四條部署路徑。路徑 B（BaaS + Serverless）用 Supabase + Vercel/CF Workers 搭監控後端，APP 上線初期零成本運作。這是和 PROP-001 的 Go binary collector 平行的另一條實作路線。

教學依據：
- [模組六：部署光譜](https://github.com/tarrragon/blog/blob/main/content/monitoring/06-commercial-comparison/deployment-spectrum.md) — 路徑 B 架構差異、免費方案限額、撞牆訊號
- [Backend：交付形態選型](https://github.com/tarrragon/blog/blob/main/content/backend/00-service-selection/delivery-mode-selection.md) — BaaS 在交付形態光譜的定位

## 問題描述

PROP-001 的 Go binary collector 假設單機部署（VPS / bare metal）。APP 上線初期的開發者可能不想管 server — 用 Supabase（managed PostgreSQL）+ Vercel serverless function 可以零成本起步，但 collector 邏輯需要重新設計（無 channel、無 single-writer、無 in-memory buffer）。

## 範圍界定

### 本提案要做的（In Scope）

**1. Serverless ingestion function**

- Vercel Serverless Function 或 Cloudflare Worker 接收 SDK HTTP POST
- JSON Schema 驗證（和 Go collector 共用同一份 event.schema.json）
- 驗證通過後直接寫入 Supabase PostgreSQL
- 回應格式和 Go collector 一致（200/207/400/503）

**2. 背壓替代方案**

- 無 channel → 用 PostgreSQL advisory lock 或 Supabase rate limiting
- 或用 Upstash Redis 做 serverless-friendly 的 rate limiter
- SDK 端 429 處理不變（SDK 不知道 collector 是 Go binary 還是 serverless）

**3. Downsample / purge 的外部 cron**

- Supabase pg_cron 或 Vercel Cron 觸發
- 和 Go collector 的 downsample / purge SQL 邏輯可共用

**4. Storage schema 共用**

- 和 Go collector 的 PostgreSQL backend 用同一套 DDL
- Events 表、error_groups 表、hourly_summary 表結構一致
- 未來從 serverless 遷到 Go collector 時只需改 ingestion 層、storage 不動

### 本提案不做的（Out of Scope）

- Go collector 的任何修改（本提案是平行實作、不改既有 Go collector）
- Dashboard（先用 Supabase Studio 直接查 PostgreSQL）
- SDK 端修改（SDK 的 endpoint 指向不同 URL、其他行為不變）
- Device attestation / HMAC signing（屬 PROP-010、serverless collector 可後續整合）

## 驗收條件

- [ ] Serverless function 接收 SDK 事件、schema 驗證、寫入 Supabase PostgreSQL
- [ ] 回應格式和 Go collector 一致（200 / 207 / 400）
- [ ] 同時 3 個 SDK flush 不出現連線耗盡（connection pooling 有效）
- [ ] pg_cron 觸發 downsample / purge 成功
- [ ] SDK 不需任何修改（只改 endpoint URL）
- [ ] 在 Supabase Free + Vercel Hobby 免費額度內完成驗收

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Cold start 延遲 | 首次 request ~200ms | 監控 ingestion 可接受、非使用者面向 |
| 連線數瓶頸 | Supabase Free ~20 concurrent | PgBouncer 緩解、高併發時需升級方案 |
| 無 background state | 無法用 in-memory 做即時聚合 | 聚合移到 PostgreSQL 層（SQL aggregation） |
| Vendor 鎖定 | 依賴 Supabase + Vercel 平台 | Storage schema 共用讓遷出只需改 ingestion 層 |
