// line-board Pane 的「各 session」區塊。
// Text 由 register.tsx 的 ui.render 以 $.ui.resolve(e) 取得後傳入；解析經 parse.ts 匯出。

import type { ElementConstructor, TextProps } from 'claude-code'

import type { SessionState, SessionsResult } from '../types'
import { SESSIONS_DIR, formatAge } from './parse'

export function renderSessions(Text: ElementConstructor<TextProps>, readAtMs: number, sessions: SessionsResult) {
  if (sessions.kind === 'error') {
    return <Text color="red">讀取 ~/{SESSIONS_DIR} 失敗（{sessions.message}）</Text>
  }
  const rows = sessions.sessions.map(session => renderSession(Text, readAtMs, session))
  const ended =
    sessions.endedCount === 0 ? [] : [<Text dimColor>另有 {sessions.endedCount} 個狀態檔的 pid 已結束，未列出</Text>]
  if (rows.length === 0) return [<Text dimColor>（本 repo 沒有執行中的 session）</Text>, ...ended]
  return [...rows, ...ended]
}

function renderSession(Text: ElementConstructor<TextProps>, readAtMs: number, session: SessionState) {
  const waitingFor = session.waitingFor === null ? '' : `：${session.waitingFor}`
  const line = `${session.name}｜${session.status}${waitingFor}｜${formatAge(readAtMs, session.statusUpdatedAt)}`
  return session.status === 'waiting' ? (
    <Text color="yellow" bold>
      {line}
    </Text>
  ) : (
    <Text>{line}</Text>
  )
}
