#!/bin/bash
# Full-page screenshot tour via flutter drive (web-server) + CDP capture of
# the scenelex Chrome tab. Polls the code relay for SHOT-READY markers and
# captures the page at the exact device viewport (no system permissions
# needed: CDP + the relay are both local HTTP/WS).
# Usage: scripts/run-shots.sh [en|zh] [390|1440]
# Requires: local server on :8081, python3 (relay + websocket-client), Chrome.
set -e
cd "$(dirname "$0")/../app"
LANG="${1:-en}"
WIDTH="${2:-390}"
HEIGHT=$([ "$WIDTH" = "1440" ] && echo 900 || echo 844)
RELAY_PORT=9001
CDP_PORT=9222
WEB_PORT=8094
URL="http://localhost:$WEB_PORT"
OUT="/tmp/scenelex-shots"
mkdir -p "$OUT"

pkill -f "code-relay.py" 2>/dev/null || true
pkill -9 -f "flutter_tools.snapshot" 2>/dev/null || true
pkill -9 -f "chrome-shot-profile" 2>/dev/null || true
sleep 2

python3 ../scripts/code-relay.py > /tmp/code-relay.log 2>&1 &
RELAY_PID=$!
sleep 1
curl -s -m 3 "http://127.0.0.1:$RELAY_PORT/health" > /dev/null || { echo "relay failed to start"; exit 1; }

# Dedicated Chrome instance with CDP enabled (own profile; the user's Chrome
# is left untouched).
# Dedicated headless Chrome instance with CDP enabled (own profile; the
# user's Chrome is left untouched). Headless avoids background throttling
# that renders the Flutter canvas blank in windowed mode.
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new \
  --remote-debugging-port=$CDP_PORT \
  --remote-allow-origins=* \
  --user-data-dir=/tmp/chrome-shot-profile \
  --no-first-run --disable-default-apps \
  --window-size=1440,900 \
  "$URL" > /tmp/chrome-shot.log 2>&1 &
CHROME_PID=$!

EMAIL="shot-$LANG-$WIDTH-$(date +%s)@scenelex.app"
echo "== shots $LANG ${WIDTH}x${HEIGHT} ($EMAIL) =="
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/sync_flow_test.dart \
  -d web-server --web-port=$WEB_PORT \
  --dart-define=CHECKPOINT=5 \
  --dart-define=SHOT=tour \
  --dart-define=SHOT_LANG=$LANG \
  --dart-define=SHOT_WIDTH=$WIDTH \
  --dart-define=SHOT_HEIGHT=$HEIGHT \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --dart-define=TEST_EMAIL=$EMAIL > /tmp/shot-$LANG-$WIDTH.log 2>&1 &
DRIVE_PID=$!

captured=""
while kill -0 $DRIVE_PID 2>/dev/null || [ -n "$captured" ]; do
  for name in $(grep -o 'tour-[a-z-]*' /tmp/code-relay.log 2>/dev/null | sort -u || true); do
    case " $captured " in
      *" $name "*) ;;
      *)
        captured="$captured $name"
        sleep 2
        python3 ../scripts/cdp_shot.py "$WIDTH" "$HEIGHT" "$OUT/$LANG-$WIDTH-$name.png" $CDP_PORT \
          >> /tmp/cdp-shot.log 2>&1 || echo "capture failed for $name"
        ;;
    esac
  done
  if ! kill -0 $DRIVE_PID 2>/dev/null; then break; fi
  sleep 2
done

wait $DRIVE_PID 2>/dev/null || true
kill $RELAY_PID 2>/dev/null || true
kill $CHROME_PID 2>/dev/null || true
echo "=== shots done: $(ls $OUT/$LANG-$WIDTH-*.png 2>/dev/null | wc -l | tr -d ' ') ==="
