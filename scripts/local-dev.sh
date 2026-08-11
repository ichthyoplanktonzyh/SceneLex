#!/usr/bin/env bash
# Local full-stack dev launcher: Postgres + server + content import + web.
# Usage:
#   scripts/local-dev.sh          # everything (web at :8090)
#   scripts/local-dev.sh --no-web # server only (curl / manual testing)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== 1/4 Postgres (docker compose)"
docker compose -f docker/docker-compose.yml up -d

echo "== 2/4 server (:8081)"
if ! curl -s -m 2 http://127.0.0.1:8081/v1/health > /dev/null 2>&1; then
  (cargo run -p scenelex-server > /tmp/scenelex-server.log 2>&1 &)
  for _ in $(seq 1 30); do
    curl -s -m 2 http://127.0.0.1:8081/v1/health > /dev/null 2>&1 && break
    sleep 1
  done
  curl -s http://127.0.0.1:8081/v1/health
  echo
fi

echo "== 3/4 content import (idempotent)"
.venv/bin/python scripts/import_content.py

if [[ "${1:-}" == "--no-web" ]]; then
  echo "== server ready at http://127.0.0.1:8081 (web skipped)"
  exit 0
fi

echo "== 4/4 web app (:8090)"
cd app
flutter run -d chrome --web-port 8090
