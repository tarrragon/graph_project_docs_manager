---
id: EVT-DIAGNOSTICS-001
name: "GapsDetected"
canonical_name: "Diagnostics.Gaps.Detected"
category: domain_event
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['Diagnostics']
consumers: ['Presentation']
---

# EVT-DIAGNOSTICS-001: GapsDetected

## 事實

一輪破洞偵測完成。

## 負載結構

`gaps: List<Gap>`（各帶 `category`、`severity`、`target`）

> 具體型別待 SPEC 產出後定案。

## 設計註記

**本節是「破洞」一詞的權威定義。** 全批他處（`domain-map.md` §7、UC-02、UC-06、
PROP-004）使用該詞時皆以此為準，不另立外延。

破洞來源有**四**類：

| 類別 | 內容 | 判定輸入 |
|------|------|---------|
| `parseFailure` | 解析失敗 | `EVT-CORPUS-003`：YAML 錯誤，或落在節點 carrier 路徑下卻缺 frontmatter |
| `graphDefect` | 圖結構缺陷 | 斷邊（指向不存在節點）、孤島、缺必要邊 |
| `traceGap` | 追溯缺口 | 無 SPEC 的 PROP、無測試的 UC |
| `unlocatable` | ticket 無法定位 | `where.files` 對應不到任何 domain（PROP-004「以 ticket 切入」模式） |

> 第四類先前散落在 UC-02 例外場景與 PROP-004 §已否決 兩處，未被收進本清單，
> 使「破洞」在批內有三種互不相容的外延。2026-08-27 的多輪審查（frame 2-B⁶
> 術語探針）指出後併入。

**各類別下的具體項目與嚴重度仍待列舉**——UC-06 的驗收條件（依類別分節）
依賴該清單，見 `docs/domain-map.md` §9。

`category` 的值域即上表四個鍵。`severity` 是否與 `EVT-CORPUS-003` 的兩級
（`edgeAffecting` / `detailOnly`）共用同一值域，待定。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
