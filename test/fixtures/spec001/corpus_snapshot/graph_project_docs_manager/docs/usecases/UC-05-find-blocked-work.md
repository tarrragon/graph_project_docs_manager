```yaml
flow:
  - id: "enter-ticket-list"
    name: "進入 ticket 清單"
    next: ["trigger-load"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
    implements: ["FR-02"]
  - id: "trigger-load"
    name: "觸發載入"
    next: ["switch-to-topic"]
    branch_from: null
    return_to: null
    emits: ["EVT-CORPUS-001"]
    consumes: []
    traverses: ["corpus"]
  - id: "switch-to-topic"
    name: "切換至主題模式"
    next: ["locate-blocked"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "locate-blocked"
    name: "定位阻擋"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "filter-in-list-mode"
    name: "列表模式篩選"
    next: []
    branch_from: "switch-to-topic"
    return_to: "switch-to-topic"
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "cancel-loading"
    name: "載入期間離開"
    next: []
    branch_from: "trigger-load"
    return_to: "enter-ticket-list"
    emits: []
    consumes: []
    traverses: ["corpus"]
    implements: ["FR-02"]
  - id: "damaged-tickets"
    name: "含損壞票"
    next: []
    branch_from: "trigger-load"
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-003"]
    traverses: ["corpus", "diagnostics"]
    implements: ["FR-05"]
```
