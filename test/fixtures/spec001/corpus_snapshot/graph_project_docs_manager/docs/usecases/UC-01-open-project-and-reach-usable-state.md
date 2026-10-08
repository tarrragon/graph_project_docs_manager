```yaml
flow:
  - id: "select-folder"
    name: "選擇資料夾"
    next: ["load-schema"]
    branch_from: null
    return_to: null
    emits: ["EVT-WORKSPACE-001"]
    consumes: []
    traverses: ["workspace"]
  - id: "load-schema"
    name: "載入型別表"
    next: ["parse-nodes"]
    branch_from: null
    return_to: null
    emits: ["EVT-SCHEMA-001"]
    consumes: ["EVT-WORKSPACE-001"]
    traverses: ["schema"]
  - id: "parse-nodes"
    name: "解析節點"
    next: ["reach-domain-view"]
    branch_from: null
    return_to: null
    emits: ["EVT-CORPUS-001"]
    consumes: ["EVT-SCHEMA-001"]
    traverses: ["corpus"]
  - id: "reach-domain-view"
    name: "抵達 Domain 視圖"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-001"]
    traverses: ["corpus"]
  - id: "folder-unavailable"
    name: "資料夾不可用"
    next: []
    branch_from: "select-folder"
    return_to: "select-folder"
    emits: []
    consumes: []
    traverses: ["workspace"]
  - id: "empty-graph"
    name: "空專案"
    next: []
    branch_from: "parse-nodes"
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "schema-rejected"
    name: "版本不符拒絕渲染"
    next: []
    branch_from: "load-schema"
    return_to: "select-folder"
    emits: ["EVT-SCHEMA-002"]
    consumes: []
    traverses: ["schema"]
    implements: ["FR-04"]
```
