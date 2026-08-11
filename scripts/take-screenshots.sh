#!/bin/bash
# Captures verification screenshots through the real-browser harness
# (flutter drive -d web-server + plain Chrome, like run-checkpoints.sh).
# Shots: review-en, review-zh (review card head with tags + reps badge) and
# cards-filter (Cards page tag filter sheet). Frames are captured by the
# test through the driver channel (app/screenshots/<name>.png), the same
# browser session that proves the checkpoints.
# Requires: local server on :8081, python3.
# Usage: scripts/take-screenshots.sh [out-dir]
set -e
cd "$(dirname "$0")/../app"
RELAY_PORT=9001
WEB_PORT=8093
URL="http://localhost:$WEB_PORT"
OUT="${1:-/tmp/scenelex-shots}"
mkdir -p "$OUT"

pkill -f "code-relay.py" 2>/dev/null || true
pkill -9 -f "flutter_tools.snapshot" 2>/dev/null || true
pkill -9 -f "flutter_tools_chrome_device" 2>/dev/null || true
sleep 2

python3 ../scripts/code-relay.py > /tmp/code-relay.log 2>&1 &
RELAY_PID=$!
sleep 1
curl -s -m 3 "http://127.0.0.1:$RELAY_PORT/health" > /dev/null || { echo "relay failed"; exit 1; }

shot_one() {
  local name=$1 lang=$2
  local email="shot-$(date +%s)-$name@scenelex.app"
  local log=/tmp/shot-$name.log
  echo "== shot $name (lang=$lang) =="
  rm -f "$log"
  rm -f "screenshots/$name.png"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/sync_flow_test.dart \
    -d web-server --web-port=$WEB_PORT \
    --dart-define=CHECKPOINT=5 \
    --dart-define=SHOT=$name \
    --dart-define=SHOT_LANG=$lang \
    --dart-define=TEST_EMAIL=$email > "$log" 2>&1 &
  local drive_pid=$!

  for i in $(seq 1 60); do
    if grep -q "Debug service listening" "$log" 2>/dev/null; then break; fi
    if ! kill -0 $drive_pid 2>/dev/null; then break; fi
    sleep 2
  done
  open -a "Google Chrome" "$URL" 2>/dev/null || true

  wait $drive_pid 2>/dev/null || true
  if grep -q "All tests passed" "$log"; then
    if [ -f "screenshots/$name.png" ]; then
      cp "screenshots/$name.png" "$OUT/$name.png"
      echo "shot $name: PASS ($(wc -c < "$OUT/$name.png") bytes)"
    else
      echo "shot $name: PASS but no screenshot file"
    fi
  else
    echo "shot $name: FAIL"
    grep -E "TestFailure|driver-null" "$log" | head -3
  fi
  pkill -9 -f "flutter_tools.snapshot" 2>/dev/null || true
  sleep 2
}

shot_one review-en en
shot_one review-zh zh
shot_one cards-filter en

kill $RELAY_PID 2>/dev/null || true
ls -la "$OUT"
