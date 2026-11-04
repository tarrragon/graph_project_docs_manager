#!/bin/bash
# 檔案監看實機驗證配方。退出碼：0 通過 / 1 App 失敗 / 3 環境不可驗證 / 4 觀測不完整
# 用法：watch-verify.sh [--gate-only]
# 環境變數：WV_APP_DIR(預設 cwd) WV_WATCH_DIR(experiment 檔所在，預設 docs) WV_EVENT_PATTERN(預設 DirectoryWatchSource)
#   WV_CPU_LIMIT(預設 50) WV_APP_CMD(預設 fvm flutter run -d macos --start-paused) WV_URI_WAIT(預設 120)
#   自測用：WV_FAKE_CPU WV_CANARY_SKIP_WRITE
HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${WV_APP_DIR:-$PWD}"; WATCH_DIR="${WV_WATCH_DIR:-$APP_DIR/docs}"
PATTERN="${WV_EVENT_PATTERN:-DirectoryWatchSource}"; LIMIT="${WV_CPU_LIMIT:-50}"
WORK="$(mktemp -d)"; EXP="$WATCH_DIR/experiment-watch-verify-$$.md"
APP_PID=""; VM_PID=""

kill_tree() { # 只用 kill <PID>，不用 pkill／killall
  local p="$1" c
  [ -n "$p" ] || return 0
  for c in $(pgrep -P "$p" 2>/dev/null); do kill_tree "$c"; done
  kill "$p" 2>/dev/null
}
cleanup() { # trap：任何路徑都走到
  [ -n "$VM_PID" ] && kill "$VM_PID" 2>/dev/null
  kill_tree "$APP_PID"
  rm -f "$EXP"; rm -rf "$WORK"
  echo "CLEANUP app_pid=${APP_PID:-none} exp_file_removed=$([ -e "$EXP" ] && echo no || echo yes)"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

unverifiable() { echo "ENV_UNVERIFIABLE: $1（環境不可驗證，不判 App 失敗）"; exit 3; }

# 步驟 0：前置健康閘門
gate() {
  local i cpu
  for i in 1 2 3; do
    cpu="${WV_FAKE_CPU:-$(ps -axo pcpu=,comm= | awk '/fseventsd/ {print int($1); exit}')}"
    cpu="${cpu:-0}"
    echo "GATE fseventsd_cpu=$cpu limit=$LIMIT sample=$i"
    [ "$cpu" -lt "$LIMIT" ] || unverifiable "fseventsd CPU ${cpu}% 超過 ${LIMIT}%"
    sleep 1
  done
  # 金絲雀：即時事件正向對照
  if ! node "$HERE/canary.mjs" "$WORK" 8 >"$WORK/canary.out" 2>&1; then
    unverifiable "金絲雀探針收不到即時事件"
  fi
  echo "GATE canary=CANARY_EVENT"
}
gate
[ "$1" = "--gate-only" ] && { echo "GATE_OK"; exit 0; }

# 步驟 1：start-paused 啟動
APP_CMD="${WV_APP_CMD:-fvm flutter run -d macos --start-paused}"
( cd "$APP_DIR" && exec $APP_CMD ) >"$WORK/app.out" 2>&1 &
APP_PID=$!
echo "APP_PID=$APP_PID"
URI=""
for _ in $(seq 1 "${WV_URI_WAIT:-120}"); do
  URI="$(sed -n 's#.*\(http://127\.0\.0\.1:[0-9]*/[^/ ]*/\).*#\1#p' "$WORK/app.out" | head -1)"
  [ -n "$URI" ] && break
  kill -0 "$APP_PID" 2>/dev/null || break
  sleep 1
done
[ -n "$URI" ] || { echo "OBS_INCOMPLETE: 取不到 VM service URI"; exit 4; }
WS="ws${URI#http}ws"

# 步驟 2：收 log（直接寫檔，不經 pipe），先訂閱再 resume
node "$HERE/vm_log.mjs" "$WS" "$WORK/vm.log" 40 --resume &
VM_PID=$!
sleep 12  # 等啟動與首輪掃描 log
BASE=$(grep -c "$PATTERN" "$WORK/vm.log")

# 步驟 3：experiment 檔觸發（新建、追加、刪除）
echo "x" > "$EXP"; sleep 4
echo "y" >> "$EXP"; sleep 4
rm -f "$EXP"; sleep 4
wait "$VM_PID" 2>/dev/null; VM_PID=""

# 步驟 4：sequenceNumber 連續判讀
[ -n "$WV_KEEP_LOG" ] && cp "$WORK/vm.log" "$WV_KEEP_LOG"
GAPS=$(awk -F'seq=' '/seq=/ {split($2,a," "); s=a[1]; if (p!="" && s!=p+1) g++; p=s} END {print g+0}' "$WORK/vm.log")
TOTAL=$(awk '/^TOTAL/ {print $2}' "$WORK/vm.log")
AFTER=$(grep -c "$PATTERN" "$WORK/vm.log")
echo "RESULT total=$TOTAL seq_gaps=$GAPS pattern_before=$BASE pattern_after=$AFTER"
[ "${TOTAL:-0}" -gt 0 ] && [ "$GAPS" -eq 0 ] || { echo "OBS_INCOMPLETE: log 為空或 sequenceNumber 不連續"; exit 4; }
if [ "$AFTER" -gt "$BASE" ]; then echo "PASS"; exit 0; fi
echo "FAIL: 閘門綠燈、觀測完整，但 experiment 檔操作後無 $PATTERN 事件（App 失敗）"; exit 1
