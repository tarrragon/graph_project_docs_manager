```yaml
flow:
  - id: "locate-domain"
    name: "定位 domain"
    next: ["read-traversal-count"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "read-traversal-count"
    name: "讀取貫穿數"
    next: ["switch-to-swimlane"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "switch-to-swimlane"
    name: "切換至泳道"
    next: ["inspect-steps"]
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-LAYOUT-001"]
    traverses: ["layout"]
  - id: "inspect-steps"
    name: "檢視步驟"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "matrix-overview-only"
    name: "僅檢視全貌"
    next: []
    branch_from: "read-traversal-count"
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "enter-from-ticket"
    name: "由 ticket 切入"
    next: ["read-traversal-count"]
    branch_from: "locate-domain"
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph", "ticketdetail"]
  - id: "flow-not-structured"
    name: "flow 未結構化"
    next: []
    branch_from: "switch-to-swimlane"
    return_to: "locate-domain"
    emits: []
    consumes: []
    traverses: ["corpus"]
    implements: ["FR-06"]
```
