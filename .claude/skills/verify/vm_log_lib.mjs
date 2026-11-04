// vm_log.mjs 的純邏輯：截斷字串還原。與 WebSocket 解耦以便測試。
// inst: VM service Instance（valueAsString / valueAsStringIsTruncated / id）
// getFull(id): Promise<string>，由呼叫端以 getObject 實作
export async function fullText(inst, getFull) {
  const v = inst?.valueAsString;
  if (!inst?.valueAsStringIsTruncated) return { text: v, note: '' };
  try {
    const full = await getFull(inst.id);
    if (typeof full !== 'string') throw new Error('getObject 未回傳字串');
    return { text: full, note: '' };
  } catch (e) {
    // 退回截斷值並標註，不靜默吞掉（quality-baseline 規則 4）
    return { text: v, note: ` [TRUNCATED: getObject failed: ${e?.message ?? e}]` };
  }
}
