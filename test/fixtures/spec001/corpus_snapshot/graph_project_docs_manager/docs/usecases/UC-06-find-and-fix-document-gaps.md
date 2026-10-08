```yaml
flow:
  - id: "enter-gap-report"
    name: "進入破洞報告"
    next: ["view-categories"]
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-003"]
    traverses: ["diagnostics"]
  - id: "view-categories"
    name: "檢視分類"
    next: ["locate-item"]
    branch_from: null
    return_to: null
    emits: ["EVT-DIAGNOSTICS-001"]
    consumes: []
    traverses: ["diagnostics"]
  - id: "locate-item"
    name: "定位單項"
    next: ["open-source-file"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["diagnostics"]
  - id: "open-source-file"
    name: "開啟原始檔"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["workspace"]
  - id: "rescan"
    name: "重新掃描"
    next: ["view-categories"]
    branch_from: "open-source-file"
    return_to: "view-categories"
    emits: ["EVT-CORPUS-002"]
    consumes: []
    traverses: ["corpus"]
  - id: "no-gaps"
    name: "無破洞"
    next: []
    branch_from: "view-categories"
    return_to: null
    emits: []
    consumes: []
    traverses: ["diagnostics"]
  - id: "gaps-undeterminable"
    name: "無法判定破洞"
    next: []
    branch_from: "view-categories"
    return_to: null
    emits: []
    consumes: []
    traverses: ["diagnostics"]
```
