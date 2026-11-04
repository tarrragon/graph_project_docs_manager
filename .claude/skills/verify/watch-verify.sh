#!/bin/bash
# 檔案監看實機驗證配方。退出碼：0 通過 / 1 App 失敗 / 3 環境不可驗證 / 4 觀測不完整
# 用法：watch-verify.sh [--gate-only]
# 環境變數：WV_APP_DIR(預設 cwd) WV_EVENT_PATTERN(保留) WV_CPU_LIMIT(預設 50)
#   WV_WATCH_DIR：experiment 檔所在。預設為 App 保存的 workspace.path 加 /docs
#     （defaults read $WV_DEFAULTS_DOMAIN flutter.workspace.path），讀不到 -> exit 3
#   WV_APP_CMD(預設 fvm flutter run -d macos --start-paused) WV_URI_WAIT(預設 120)
#   自測用：WV_FAKE_CPU WV_CANARY_SKIP_WRITE WV_JUDGE_LOG(只判讀既有 log) WV_EXP_NAME WV_DEFAULTS_DOMAIN
HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${WV_APP_DIR:-$PWD}"; WATCH_DIR="${WV_WATCH_DIR:-}"
LIMIT="${WV_CPU_LIMIT:-50}"
WORK="$(mktemp -d)"; EXP=""; EXP_NAME="experiment-watch-verify-$$.md"
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
  [ -n "$EXP" ] && rm -f "$EXP"
  rm -rf "$WORK"
  echo "CLEANUP app_pid=${APP_PID:-none} exp_file_removed=$([ -n "$EXP" ] && [ -e "$EXP" ] && echo no || echo yes)"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

unverifiable() { echo "ENV_UNVERIFIABLE: $1（環境不可驗證，不判 App 失敗）"; exit 3; }

# 判讀：PASS 必須有路徑含 experiment 檔名的 add 與 remove 事件，其他路徑事件不計
judge() { # $1=log
  local total gaps adds rems
  gaps=$(awk -F'seq=' '/seq=/ {split($2,a," "); s=a[1]; if (p!="" && s!=p+1) g++; p=s} END {print g+0}' "$1")
  total=$(awk '/^TOTAL/ {print $2}' "$1")
  adds=$(grep "raw event type=add " "$1" | grep -c -F "$EXP_NAME")
  rems=$(grep "raw event type=remove " "$1" | grep -c -F "$EXP_NAME")
  echo "RESULT total=$total seq_gaps=$gaps exp_add=$adds exp_remove=$rems"
  [ "${total:-0}" -gt 0 ] && [ "$gaps" -eq 0 ] || { echo "OBS_INCOMPLETE: log 為空或 sequenceNumber 不連續"; exit 4; }
  if [ "$adds" -ge 1 ] && [ "$rems" -ge 1 ]; then echo "PASS"; exit 0; fi
  echo "FAIL: 閘門綠燈、觀測完整，但無 $EXP_NAME 的 add／remove 事件（App 失敗；其他路徑事件不計）"; exit 1
}
if [ -n "$WV_JUDGE_LOG" ]; then EXP_NAME="${WV_EXP_NAME:-$EXP_NAME}"; judge "$WV_JUDGE_LOG"; fi

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

# 監看目錄：App 監看的是它保存的工作區，不是 cwd
if [ -z "$WATCH_DIR" ]; then
  WS_PATH="$(defaults read "${WV_DEFAULTS_DOMAIN:-com.example.graphProjectDocsManager}" flutter.workspace.path 2>/dev/null)"
  { [ -n "$WS_PATH" ] && [ -d "$WS_PATH/docs" ]; } || unverifiable "讀不到 App 的 workspace.path"
  WATCH_DIR="$WS_PATH/docs"
fi
EXP="$WATCH_DIR/$EXP_NAME"
echo "WATCH_DIR=$WATCH_DIR"

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

# 步驟 3：experiment 檔觸發（新建、追加、刪除）
echo "x" > "$EXP"; sleep 4
echo "y" >> "$EXP"; sleep 4
rm -f "$EXP"; sleep 4
wait "$VM_PID" 2>/dev/null; VM_PID=""

# 步驟 4：sequenceNumber 連續判讀 + experiment 檔事件判讀
[ -n "$WV_KEEP_LOG" ] && cp "$WORK/vm.log" "$WV_KEEP_LOG"
judge "$WORK/vm.log"
