#!/bin/bash
# Manual screenshot session: flutter drive walks the tour (one page every
# ~90 seconds on web), the relay announces the current page name, and you
# capture each page in Chrome yourself (Cmd+Shift+4 selection, or
# Cmd+Shift+3 full screen). No automation of the capture itself.
# Usage: scripts/manual-shots.sh [en|zh] [390|1440]
# Requires: local server on :8081, python3 (relay), Chrome.
set -e
cd "$(dirname "$0")/../app"
LANG="${1:-en}"
WIDTH="${2:-390}"
HEIGHT=$([ "$WIDTH" = "1440" ] && echo 900 || echo 844)
RELAY_PORT=9001
WEB_PORT=8094
URL="http://localhost:$WEB_PORT"
OUT="/tmp/scenelex-shots"
mkdir -p "$OUT"

pkill -f "code-relay.py" 2>/dev/null || true
pkill -9 -f "flutter_tools.snapshot" 2>/dev/null || true
sleep 2

python3 ../scripts/code-relay.py > /tmp/code-relay.log 2>&1 &
RELAY_PID=$!
sleep 1
curl -s -m 3 "http://127.0.0.1:$RELAY_PORT/health" > /dev/null || { echo "relay failed to start"; exit 1; }

EMAIL="shot-$LANG-$WIDTH-$(date +%s)@scenelex.app"
echo "== manual shots $LANG ${WIDTH}x${HEIGHT} ($EMAIL) =="
echo "Chrome 将打开页面。每页停留 ~90 秒，终端会提示当前页名。"
echo "请用 Cmd+Shift+4 选区截图，保存到: $OUT/en-390-<页名>.png 或任意位置。"
echo "页面顺序: learn-answered → learn-reveal → home → content → notes"
echo "          → review → profile → settings"
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/sync_flow_test.dart \
  -d web-server --web-port=$WEB_PORT \
  --dart-define=CHECKPOINT=5 \
  --dart-define=SHOT=tour \
  --dart-define=SHOT_LANG=$LANG \
  --dart-define=SHOT_WIDTH=$WIDTH \
  --dart-define=SHOT_HEIGHT=$HEIGHT \
  --dart-define=TEST_EMAIL=$EMAIL > /tmp/shot-$LANG-$WIDTH.log 2>&1 &
DRIVE_PID=$!

# Wait for the debug service, then bring the page up in Chrome.
for i in $(seq 1 60); do
  if grep -q "Debug service listening" /tmp/shot-$LANG-$WIDTH.log 2>/dev/null; then break; fi
  if ! kill -0 $DRIVE_PID 2>/dev/null; then break; fi
  sleep 2
done
open -a "Google Chrome" "$URL" 2>/dev/null || true
echo ""
echo ">>> 页面已打开。开始截屏，每次看到 '>>> 请截图' 就截当前页。"

seen=""
while kill -0 $DRIVE_PID 2>/dev/null; do
  for name in $(grep -o 'tour-[a-z-]*' /tmp/code-relay.log 2>/dev/null | sort -u || true); do
    case " $seen " in
      *" $name "*) ;;
      *)
        seen="$seen $name"
        echo ""
        echo ">>> 请截图: $name  （保存为 $OUT/$LANG-$WIDTH-$name.png，90 秒窗口）"
        ;;
    esac
  done
  if ! kill -0 $DRIVE_PID 2>/dev/null; then break; fi
  sleep 3
done

wait $DRIVE_PID 2>/dev/null || true
kill $RELAY_PID 2>/dev/null || true
echo ""
echo "=== tour 结束 ==="
