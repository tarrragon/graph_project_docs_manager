#!/bin/bash
# watch-verify.sh 自測（含 E2 正向對照：閘門紅／探針無事件必須回報不可驗證）
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/watch-verify.sh"; fail=0
T="$(mktemp -d)"
chk() { [ "$2" = "$3" ] && echo "ok   $1" || { echo "FAIL $1 (got $2, want $3)"; fail=1; }; }
WV_FAKE_CPU=99 "$S" --gate-only >"$T/1.out" 2>&1; chk "閘門紅 exit 3" $? 3
grep -q ENV_UNVERIFIABLE "$T/1.out"; chk "閘門紅訊息" $? 0
WV_FAKE_CPU=1 WV_CANARY_SKIP_WRITE=1 "$S" --gate-only >"$T/2.out" 2>&1; chk "探針無事件 exit 3" $? 3
grep -q "金絲雀" "$T/2.out"; chk "探針無事件訊息" $? 0
# trap：App 起不來取不到 URI，仍須殺 PID 並刪 experiment 檔
WV_FAKE_CPU=1 WV_WATCH_DIR="$T" WV_APP_CMD="sleep 300" WV_URI_WAIT=3 "$S" >"$T/3.out" 2>&1; chk "無 URI exit 4" $? 4
P=$(sed -n 's/^APP_PID=//p' "$T/3.out"); sleep 1
kill -0 "$P" 2>/dev/null; chk "App PID 已退出" $? 1
grep -q "exp_file_removed=yes" "$T/3.out"; chk "experiment 檔已刪" $? 0
# E2 正向對照：讀不到 workspace.path -> exit 3
WV_FAKE_CPU=1 WV_DEFAULTS_DOMAIN=com.invalid.nonexistent.wv "$S" >"$T/4.out" 2>&1; chk "讀不到 workspace.path exit 3" $? 3
grep -q "workspace.path" "$T/4.out"; chk "workspace.path 訊息" $? 0
# E2 正向對照：只有其他路徑事件、無 experiment 檔事件 -> exit 1，不得 PASS
printf '+1s seq=1 [W] L500 raw event type=add path=/x/docs/other.md root=/x\n+2s seq=2 [W] L500 raw event type=remove path=/x/docs/other.md root=/x\nTOTAL 2\n' >"$T/other.log"
WV_JUDGE_LOG="$T/other.log" WV_EXP_NAME=experiment-watch-verify-1.md "$S" >"$T/5.out" 2>&1; chk "僅他路徑事件 exit 1" $? 1
# 負向：add 與 remove 皆有 experiment 檔事件 -> exit 0
printf '+1s seq=1 [W] L500 raw event type=add path=/x/docs/experiment-watch-verify-1.md root=/x\n+2s seq=2 [W] L500 raw event type=remove path=/x/docs/experiment-watch-verify-1.md root=/x\nTOTAL 2\n' >"$T/ok.log"
WV_JUDGE_LOG="$T/ok.log" WV_EXP_NAME=experiment-watch-verify-1.md "$S" >"$T/6.out" 2>&1; chk "experiment add+remove exit 0" $? 0
# seq 缺號 -> exit 4
printf '+1s seq=1 [W] x\n+2s seq=3 [W] x\nTOTAL 2\n' >"$T/gap.log"
WV_JUDGE_LOG="$T/gap.log" "$S" >"$T/7.out" 2>&1; chk "seq 缺號 exit 4" $? 4
rm -rf "$T"
exit $fail
