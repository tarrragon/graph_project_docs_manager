```yaml
flow:
  - id: "select-uc"
    name: "選定 UC"
    next: ["view-steps"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "view-steps"
    name: "檢視步驟序列"
    next: ["jump-to-node"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["layout"]
    implements: ["FR-06"]
  - id: "jump-to-node"
    name: "跳轉節點"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "jump-to-domain"
    name: "跳回 domain"
    next: []
    branch_from: "view-steps"
    return_to: null
    emits: []
    consumes: []
    traverses: ["layout"]
  - id: "inspect-event-flow"
    name: "檢視事件流"
    next: []
    branch_from: "view-steps"
    return_to: "view-steps"
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "flow-block-absent"
    name: "UC 無結構化 flow"
    next: []
    branch_from: "select-uc"
    return_to: "select-uc"
    emits: []
    consumes: []
    traverses: ["corpus"]
    implements: ["FR-06"]
```
