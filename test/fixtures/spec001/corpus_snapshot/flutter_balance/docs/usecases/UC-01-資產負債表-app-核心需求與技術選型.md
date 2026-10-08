```yaml
flow:
  # --- 主要成功場景 ---
  - id: create-accounts
    name: "建立項目"
    next: [first-inventory]
    branch_from: null
    return_to: null
    implements: [FR-01]
    emits: [EVT-BALANCE-005]
    consumes: []

  - id: first-inventory
    name: "首次盤點"
    next: [view-net-worth]
    branch_from: null
    return_to: null
    implements: [FR-02]
    emits: [EVT-BALANCE-001]
    consumes: []

  - id: view-net-worth
    name: "檢視淨資產"
    next: [assess-leverage]
    branch_from: null
    return_to: null
    implements: [FR-04, FR-13]
    emits: []
    consumes: []

  - id: assess-leverage
    name: "評估槓桿風險"
    next: [periodic-inventory]
    branch_from: null
    return_to: null
    implements: [FR-06]
    emits: []
    consumes: []

  - id: periodic-inventory
    name: "定期盤點看趨勢"
    next: []
    branch_from: null
    return_to: null
    implements: [FR-07, FR-14]
    emits: [EVT-BALANCE-001]
    consumes: []

  # --- 替代場景 ---
  - id: currency-switch
    name: "顯示層幣別切換（含離線）"
    next: []
    branch_from: view-net-worth
    return_to: view-net-worth
    implements: [FR-18]
    emits: []
    consumes: [EVT-BALANCE-004]

  - id: cashflow-runway
    name: "現金流與 runway"
    next: []
    branch_from: view-net-worth
    return_to: view-net-worth
    implements: [FR-08, FR-15]
    emits: []
    consumes: []

  - id: backup-restore
    name: "備份與還原"
    next: []
    branch_from: create-accounts
    return_to: create-accounts
    implements: [FR-22, FR-23]
    emits: [EVT-BALANCE-002, EVT-BALANCE-003]
    consumes: []

  - id: reject-invalid-input
    name: "輸入驗證攔截"
    next: []
    branch_from: first-inventory
    return_to: first-inventory
    implements: [FR-24]
    emits: []
    consumes: []
```
