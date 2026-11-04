// 金絲雀探針：fs.watch（macOS 走 FSEvents）在暫存目錄寫檔，應於時限內收到即時事件。
// 用法：node canary.mjs <dir> <timeout-sec>；收到事件 exit 0，否則 exit 1。
// WV_CANARY_SKIP_WRITE=1 時不寫檔（自測用：模擬事件不投遞，作為正向對照）。
import fs from 'fs'; import path from 'path';
const [,, dir, secs] = process.argv;
const f = path.join(dir, 'canary.txt');
const watcher = fs.watch(dir, () => { console.log('CANARY_EVENT'); watcher.close(); process.exit(0); });
// 在 0.5／2／4 秒各寫一次，吸收 watcher 啟動競態造成的偶發漏收
for (const ms of [500, 2000, 4000]) {
  setTimeout(() => { if (process.env.WV_CANARY_SKIP_WRITE !== '1') fs.writeFileSync(f, 'x' + ms); }, ms);
}
setTimeout(() => { console.log('CANARY_NO_EVENT'); process.exit(1); }, Number(secs) * 1000);
