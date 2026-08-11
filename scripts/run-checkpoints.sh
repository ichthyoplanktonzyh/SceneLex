#!/bin/bash
# Runs the real-browser checkpoints via flutter drive -d web-server + a plain
# Chrome tab (avoids the flaky dwds/webdriver Chrome-launch handshake).
# Requires: local server on :8081, python3. Starts the code relay on :9001.
# Usage: scripts/run-checkpoints.sh [1|2|3|4|all]
set -e
cd "$(dirname "$0")/../app"
RELAY_PORT=9001
WEB_PORT=8093
URL="http://localhost:$WEB_PORT"
CP="${1:-all}"

# Stop any leftover relay / drive from previous runs.
pkill -f "code-relay.py" 2>/dev/null || true
pkill -9 -f "flutter_tools.snapshot" 2>/dev/null || true
pkill -9 -f "flutter_tools_chrome_device" 2>/dev/null || true
sleep 2

python3 ../scripts/code-relay.py > /tmp/code-relay.log 2>&1 &
RELAY_PID=$!
sleep 1
curl -s -m 3 "http://127.0.0.1:$RELAY_PORT/health" > /dev/null || { echo "relay failed to start"; exit 1; }
echo "relay up (pid $RELAY_PID)"

pass=0; fail=0

run_one() {
  local n=$1
  local email="cp$n-$(date +%s)@scenelex.app"
  echo "== checkpoint $n ($email) =="
  local log=/tmp/cp$n.log
  rm -f "$log"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/sync_flow_test.dart \
    -d web-server --web-port=$WEB_PORT \
    --dart-define=CHECKPOINT=$n \
    --dart-define=TEST_EMAIL=$email > "$log" 2>&1 &
  local drive_pid=$!

  # Wait for the dev server + debug service, then open the page in Chrome.
  for i in $(seq 1 60); do
    if grep -q "Debug service listening" "$log" 2>/dev/null; then break; fi
    if ! kill -0 $drive_pid 2>/dev/null; then break; fi
    sleep 2
  done
  open -a "Google Chrome" "$URL" 2>/dev/null || true

  # Wait for the run to finish.
  for i in $(seq 1 120); do
    if grep -qE "All tests passed|Some tests failed" "$log" 2>/dev/null; then break; fi
    if ! kill -0 $drive_pid 2>/dev/null; then break; fi
    sleep 5
  done
  wait $drive_pid 2>/dev/null || true

  if grep -q "All tests passed" "$log"; then
    echo "checkpoint $n: PASS"
    pass=$((pass + 1))
  else
    echo "checkpoint $n: FAIL"
    grep -E "condition not met|visible:|TestFailure|reason" "$log" | head -3
    fail=$((fail + 1))
  fi
  pkill -9 -f "flutter_tools.snapshot" 2>/dev/null || true
  sleep 2
}

if [ "$CP" = "all" ]; then
  for n in 1 2 3 4; do run_one $n; done
else
  run_one $CP
fi

kill $RELAY_PID 2>/dev/null || true
echo "=== pass=$pass fail=$fail ==="
