```yaml
flow:
  - id: "select-proposal"
    name: "展開提案"
    next: ["expand-downstream"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "expand-downstream"
    name: "展開下游"
    next: ["inspect-status"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "inspect-status"
    name: "檢視狀態"
    next: ["jump-to-detail"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "jump-to-detail"
    name: "跳轉細節"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph", "ticketdetail"]
  - id: "reverse-trace"
    name: "反向追溯"
    next: ["inspect-status"]
    branch_from: "select-proposal"
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "chain-broken"
    name: "鏈路中斷"
    next: []
    branch_from: "expand-downstream"
    return_to: "expand-downstream"
    emits: []
    consumes: []
    traverses: ["graph"]
```
