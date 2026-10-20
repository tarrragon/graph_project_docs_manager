// 各 domain 共用的小工具：票號前綴與票檔位置、票檔 frontmatter 狀態解析、checkout 路徑判定、距今時間的顯示。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；讀檔與執行命令由 register.tsx 負責。

/** 佇列票號的前綴：現行佇列行只寫短票號，補上前綴才是完整票號。 */
export const TICKET_PREFIX = '0.5.0-W1-'

/** 票檔所在目錄，相對 repo root。 */
export const TICKETS_DIR = 'docs/work-logs/v0/v0.5/v0.5.0/tickets'

/** 票檔讀不到或沒有 status 欄時顯示的狀態。 */
export const UNKNOWN_STATUS = 'unknown'

/** 讀票檔 frontmatter（第一個 `---` 區塊）的 `status:` 值；沒有 frontmatter 或沒有該欄時回傳 null。 */
export function parseFrontmatterStatus(text: string): string | null {
  const lines = text.split('\n')
  if (lines[0]?.trim() !== '---') return null
  for (const line of lines.slice(1)) {
    if (line.trim() === '---') return null
    const match = /^status:\s*['"]?([\w-]+)['"]?\s*$/.exec(line)
    if (match !== null) return match[1] ?? null
  }
  return null
}

/**
 * 從 `git worktree list --porcelain` 取所有 checkout 路徑：第一筆為主 checkout，其後各 worktree；空輸出回傳空陣列。
 * 票狀態只讀主 checkout：ticket CLI 在 linked worktree 執行時也把票務寫回主 repo，
 * worktree 內的票檔是分支開出當下的舊副本，讀它會顯示過時的狀態。全部路徑用來判定 session 是否屬於本 repo。
 */
export function parseWorktreePaths(porcelain: string): string[] {
  return porcelain
    .split('\n')
    .filter(line => line.startsWith('worktree '))
    .map(line => line.slice('worktree '.length).trim())
}

/** 距上次更新的時間：未滿 1 分鐘以秒計，其後依序以分、小時、天計；未來時間視為 0 秒；缺少時間為「時間不明」。 */
export function formatAge(nowMs: number, thenMs: number | null): string {
  if (thenMs === null) return '時間不明'
  const seconds = Math.max(0, Math.floor((nowMs - thenMs) / 1000))
  if (seconds < 60) return `${seconds} 秒前`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} 分前`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours} 小時前`
  return `${Math.floor(hours / 24)} 天前`
}
