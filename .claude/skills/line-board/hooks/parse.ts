// 看板資料純函式的匯出彙總：register.tsx 只從這裡取用，各 domain 的實作分在下列模組。
// - shared.ts：票號前綴與票檔位置、票檔 frontmatter 狀態、checkout 路徑判定、距今時間
// - lanes.ts：協調票現行佇列行與線目標行解析、票序拆分與格式化
// - sessions.ts：session 狀態檔篩選與解析、pid 存活比對、本 repo 判定、排序、線列 session 狀態
// - mergeGate.ts：合併閘門紀錄篩選與欄位解析、短分支名、閘門持有者
// - dispatch.ts：派發紀錄解析、流程階段推導、派發列
// - layout.ts：以線分組的群組、活動計數、預設展開與手動切換、群組的顯示文字與佇列列分段
// - statusColor.ts：五種狀態（輪到誰處理）的判定與顏色
// - continuity.ts：各線接續狀態（line_status 工具）：來源紀錄解析、接續狀態判定、過期偵測、等用戶偵測與輸出文字
// - userTodos.ts：協調票的用戶待辦行與完成行配對、「用戶待辦」群組的各行
// - contextUsage.ts：各 session 的 context 用量檔（session.measure 寫入）：何時寫、路徑、記錄內容

export * from './shared'
export * from './lanes'
export * from './sessions'
export * from './mergeGate'
export * from './dispatch'
export * from './layout'
export * from './statusColor'
export * from './continuity'
export * from './userTodos'
export * from './contextUsage'
