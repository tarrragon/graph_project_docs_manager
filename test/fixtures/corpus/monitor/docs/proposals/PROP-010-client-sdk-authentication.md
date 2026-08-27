---
id: PROP-010
title: "Client-side SDK 認證與偽造流量防護"
status: draft
source: development
proposed_by: "公開 endpoint 安全需求"
proposed_date: "2026-06-24"
confirmed_date: null
target_version: v0.4.0
priority: P3
evaluation_level: standard

outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

related_proposals: [PROP-001, PROP-007, PROP-009]
supersedes: null
---

# PROP-010: Client-side SDK 認證與偽造流量防護

## 需求來源

教學模組七 [Client-side SDK 認證的根本限制](https://github.com/tarrragon/blog/blob/main/content/monitoring/07-security-privacy/client-sdk-authentication.md) 定義了 client-side credential 必然可被提取的前提下的多層緩解策略。當 collector 的 ingestion endpoint 暴露在公開網路（VPS / 雲端部署），需要超出 PROP-001 basic auth 的防護。

教學依據：
- [模組七：Client-side SDK 認證的根本限制](https://github.com/tarrragon/blog/blob/main/content/monitoring/07-security-privacy/client-sdk-authentication.md) — 五層緩解策略、商業方案對照
- [模組七：Collector Access Control](https://github.com/tarrragon/blog/blob/main/content/monitoring/07-security-privacy/collector-access-control.md) — 既有 API key + role 分離
- [模組二：event.schema.json 完整欄位解說](https://github.com/tarrragon/blog/blob/main/content/monitoring/02-log-schema/event-schema-fields.md) — `_flags` metadata 定義

## 問題描述

PROP-001 的 collector 用 basic auth 或 API key 做認證，前提是 credential 被妥善保管。Client-side SDK（瀏覽器 / APK / Python script）的 credential 嵌在使用者可存取的程式碼中，必然可被提取。需要在「credential 已暴露」的前提下降低偽造流量的影響。

## 範圍界定

### 本提案要做的（In Scope）

按實作成本遞增排列，各層漸進啟用。

**1. Event schema `_flags` 擴充**：

- Collector 在寫入時可對事件附加 `_flags` metadata（底線前綴，和 SDK 業務欄位區隔）
- `_flags.suspicious = true` + `reason` 欄位
- Dashboard 預設排除 `_flags.suspicious` 事件

**2. Origin check middleware**（Web SDK 場景）：

- 檢查 HTTP request 的 `Origin` header 是否在白名單中
- 白名單可設定（config.yaml）
- 只對 Web SDK 有效，Mobile SDK 不帶 Origin

**3. HMAC request signing**：

- SDK 用 HMAC-SHA256 對 request 簽章（input = timestamp + SHA256(body)）
- Collector 驗證簽章 + timestamp 窗口（5 分鐘，防 replay）
- 簽章值為 hex 編碼，放在 `X-Signature` / `X-Timestamp` header
- HMAC secret 在 config 中管理

**4. 行為分析異常偵測**：

- 統計每個 API key 的事件模式（類型分布、事件間隔、payload 結構）
- 偏離 baseline 的流量標記 `_flags.suspicious`（不丟棄）
- 搭配 PROP-007 的 rule engine 偵測異常 pattern

### 本提案不做的（Out of Scope）

- Device attestation（App Check / SafetyNet / reCAPTCHA）
- Intake proxy 架構
- mTLS（已在 collector-access-control spec 中定義）
- IP reputation / WAF（基礎設施層，不在 collector 程式碼中）

## 驗收條件

- [ ] `_flags` metadata 在 collector 寫入時可附加到事件
- [ ] Origin check：白名單外的 Origin 被拒絕（403）
- [ ] HMAC：無簽章或簽章錯誤的 request 被拒絕（401）
- [ ] HMAC：timestamp 超過 5 分鐘的 request 被拒絕
- [ ] 行為分析：事件量突增 10 倍的 API key 被標記 `_flags.suspicious`
- [ ] Dashboard：`_flags.suspicious` 事件預設不顯示、可切換顯示

## 風險與權衡

| 風險                           | 影響                         | 緩解措施                                                   |
| ------------------------------ | ---------------------------- | ---------------------------------------------------------- |
| HMAC secret 在 client 端可被提取 | 攻擊者可偽造合法簽章         | HMAC 增加攻擊成本而非理論安全性；搭配行為分析偵測         |
| 行為分析誤判                   | 行銷活動的真實流量暴增被標記 | 標記而非丟棄、可事後取消標記                               |
| Origin 可偽造                  | curl 可自設 Origin           | Origin 只擋瀏覽器跨域呼叫，非完整防護                     |
| `_flags` 增加 storage 開銷     | 每筆事件多一個 JSON 欄位     | 只對可疑事件附加，正常事件不帶 `_flags`                    |

## 規模漸進

| 部署場景                   | 啟用的層級                                                   |
| -------------------------- | ------------------------------------------------------------ |
| 自用（同機 / 同網段）      | basic auth + HTTPS（PROP-001 已有）                          |
| 小型團隊（VPN 內）         | API key + rate limit（PROP-007）                             |
| 公開 endpoint              | 本提案全部啟用                                               |
| 商業產品                   | 本提案 + device attestation + intake proxy（未來提案）       |
