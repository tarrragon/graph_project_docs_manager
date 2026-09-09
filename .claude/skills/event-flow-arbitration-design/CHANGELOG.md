# event-flow-arbitration-design 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.1.0 — 多輪審查 Round 1 修正。可變計數去實例化：〈六步流程〉標題改〈執行流程〉、「六份範本」「七項欄位」「每步 3-5 題」改引用權威名稱（規則 10，步數與欄位集合各自的權威是方法論〈執行步驟〉與〈可觀測性〉）。`worked-examples.md` 整檔重寫：刪去「初稿／定稿／審查」的過程敘事改條件視角（該敘事在 sync 至其他 consumer 後無對應歷史）、段標「當時卡住處」改「易誤套形態」、場景 (b) 標題移除產品身分與平台限定詞。`templates.md` 修兩處範例——級別標定依據由產生方視角改接收方丟棄後果（原值與〈級別〉的鍵相反，照抄即違反判準）、卸載閾值範例補來源標註並要求填表者寫出數字怎麼來；新增〈產出物落地〉節，補各產出物的落點與容量失敗訊號的交接內容。`interview-questions.md` 步驟 4 首問補齊自發型不可棄格（原宣告三格只交付兩格）。分工表對 domain-map 的路由補明確路徑與權威歸屬。

**Version**: 1.0.0 — 初版建立。SKILL.md 定位（方法論管判準、本 skill 管流程）、觸發條件、六步流程（對應事件流負載仲裁方法論〈執行步驟〉）、與 saas-tech-selection／foundation-design／doc domain-map 的分工；`references/interview-questions.md` 六步各 3-5 題訪談問句附「為什麼問」；`references/worked-examples.md` 三場景（HTTP API 共用連線池、Flutter 多 isolate、訊息消費者混流）各含套用結果／當時卡住處／方法論現行對應判準三段，改寫自方法論定稿前的高負載工程視角審查材料；`references/templates.md` 六份產出物範本，欄位與方法論條文一致。同時把 `saas-tech-selection` 的 async-queue／capacity-performance／observability 三維度與 `event-architect-reference` 的既有路由句改為同時指向方法論（判準）與本 skill（流程）。
