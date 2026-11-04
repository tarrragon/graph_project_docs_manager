// 檔案監看實機驗證：VM service Logging 收集器。直接寫檔、不經 pipe。
// 用法：node vm_log.mjs <ws-uri> <out-file> <seconds> [--resume]
import fs from 'fs';
import { fullText } from './vm_log_lib.mjs';
const [,, uri, out, secs, flag] = process.argv;
const ws = new WebSocket(uri); const t0 = Date.now(); let n = 0;
const w = (s) => fs.appendFileSync(out, s + '\n');
const call = (id, method, params = {}) => ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
// valueAsStringIsTruncated=true 時以 getObject 取完整字串；逾時 3 秒視為失敗（由 fullText 標註）
let queue = Promise.resolve(); let isoId; let gid = 0; const pend = new Map();
const getFull = (objectId) => new Promise((res, rej) => {
  const id = 'g' + (gid++);
  const tm = setTimeout(() => { pend.delete(id); rej(new Error('timeout')); }, 3000);
  pend.set(id, (d) => { clearTimeout(tm); d.error ? rej(new Error(d.error.message)) : res(d.result?.valueAsString); });
  call(id, 'getObject', { objectId, isolateId: isoId });
});
ws.onopen = () => { call('listen', 'streamListen', { streamId: 'Logging' }); call('vm', 'getVM'); };
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); return; }
  if (d.id === 'vm' && flag === '--resume') {
    // start-paused：先訂閱 Logging（已送出）再 resume，避免漏掉啟動 log
    for (const iso of d.result.isolates ?? []) call('r' + iso.id, 'resume', { isolateId: iso.id });
    w('RESUMED');
  }
  if (d.method === 'streamNotify' && d.params?.event?.kind === 'Logging') {
    n++; const e = d.params.event, r = e.logRecord; isoId = e.isolate?.id;
    const ts = ((Date.now() - t0) / 1000).toFixed(2);
    // 串成佇列，確保截斷還原的非同步等待不改變輸出順序（seq 判讀依賴順序）
    queue = queue.then(() => fullText(r.message, getFull)).then(({ text, note }) =>
      w(`+${ts}s seq=${r.sequenceNumber} [${r.loggerName?.valueAsString}] L${r.level} ${text}${note}`));
  }
};
ws.onerror = (e) => { w('WS_ERROR ' + (e.message ?? '')); };
setTimeout(async () => { await queue; w(`TOTAL ${n}`); process.exit(0); }, Number(secs) * 1000);
