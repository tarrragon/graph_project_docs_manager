// vm_log_lib 自測（E2 正向對照：截斷輸入必須取回全文；getObject 失敗必須標註）
import { fullText } from './vm_log_lib.mjs';
let fail = 0;
const chk = (n, ok) => { console.log((ok ? 'ok   ' : 'FAIL ') + n); if (!ok) fail = 1; };
const full = 'x'.repeat(5000);
let r = await fullText({ id: 'o1', valueAsString: 'xxx', valueAsStringIsTruncated: true }, async () => full);
chk('截斷輸入取回全文', r.text === full && r.note === '');
r = await fullText({ id: 'o1', valueAsString: 'abc', valueAsStringIsTruncated: false }, async () => { throw new Error('不應呼叫'); });
chk('未截斷不呼叫 getObject', r.text === 'abc' && r.note === '');
r = await fullText({ id: 'o1', valueAsString: 'xxx', valueAsStringIsTruncated: true }, async () => { throw new Error('boom'); });
chk('失敗退回截斷值並標註', r.text === 'xxx' && r.note.includes('TRUNCATED') && r.note.includes('boom'));
process.exit(fail);
