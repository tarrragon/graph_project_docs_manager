// 檔案監看實機驗證：VM service Logging 收集器。直接寫檔、不經 pipe。
// 用法：node vm_log.mjs <ws-uri> <out-file> <seconds> [--resume]
import fs from 'fs';
const [,, uri, out, secs, flag] = process.argv;
const ws = new WebSocket(uri); const t0 = Date.now(); let n = 0;
const w = (s) => fs.appendFileSync(out, s + '\n');
const call = (id, method, params = {}) => ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
ws.onopen = () => { call('listen', 'streamListen', { streamId: 'Logging' }); call('vm', 'getVM'); };
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (d.id === 'vm' && flag === '--resume') {
    // start-paused：先訂閱 Logging（已送出）再 resume，避免漏掉啟動 log
    for (const iso of d.result.isolates ?? []) call('r' + iso.id, 'resume', { isolateId: iso.id });
    w('RESUMED');
  }
  if (d.method === 'streamNotify' && d.params?.event?.kind === 'Logging') {
    n++; const e = d.params.event, r = e.logRecord;
    w(`+${((Date.now() - t0) / 1000).toFixed(2)}s seq=${r.sequenceNumber} [${r.loggerName?.valueAsString}] L${r.level} ${r.message?.valueAsString}`);
  }
};
ws.onerror = (e) => { w('WS_ERROR ' + (e.message ?? '')); };
setTimeout(() => { w(`TOTAL ${n}`); process.exit(0); }, Number(secs) * 1000);
