#!/bin/bash
# End-to-end sync protocol verification against a running server on :8080.
set -e
BASE=http://127.0.0.1:8081/v1
EMAIL="sync-$(date +%s)@scenelex.app"

echo "== auth =="
curl -s -X POST $BASE/auth/send-code -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\"}" -o /dev/null
CODE=$(grep -o "code=[0-9]\{8\}" /tmp/scenelex-server.log | tail -1 | cut -d= -f2)
TOKEN=$(curl -s -X POST $BASE/auth/verify-code -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
WS=$(curl -s $BASE/me -H "Authorization: Bearer $TOKEN" | python3 -c "import json,sys; print(json.load(sys.stdin)['selectedWorkspaceId'])")
INST=$(python3 -c "import uuid; print(uuid.uuid4())")
echo "workspace: $WS"

AUTH="Authorization: Bearer $TOKEN"
CT="Content-Type: application/json"

echo "== 1. bootstrap (empty remote) =="
curl -s -X POST $BASE/workspaces/$WS/sync/bootstrap -H "$AUTH" -H "$CT" -d "{\"mode\":\"pull\",\"installationId\":\"$INST\",\"platform\":\"web\"}" | python3 -m json.tool

echo "== 2. push: new learning_state + list =="
python3 - "$WS" "$INST" <<'EOF' > /tmp/push1.json
import json, sys, uuid
ws, inst = sys.argv[1], sys.argv[2]
ls_id = str(uuid.uuid4())
sense = "22222222-2222-2222-2222-222222222222"
list_id = str(uuid.uuid4())
now = "2026-08-10T15:00:00.000Z"
print(json.dumps({
  "installationId": inst, "platform": "web",
  "operations": [
    {"operationId": str(uuid.uuid4()), "entityType": "learning_state", "entityId": sense,
     "action": "upsert", "clientUpdatedAt": now,
     "payload": {
       "learningStateId": ls_id, "wordSenseId": sense,
       "dueAt": None, "reps": 0, "lapses": 0,
       "fsrsStability": None, "fsrsDifficulty": None,
       "fsrsLastReviewedAt": None, "fsrsScheduledDays": None,
       "fsrsCardState": "new", "fsrsStepIndex": None,
       "clientUpdatedAt": now, "lastModifiedByReplicaId": "44444444-4444-4444-4444-444444444444",
       "lastOperationId": "55555555-5555-5555-5555-555555555555",
       "deletedAt": None}},
    {"operationId": str(uuid.uuid4()), "entityType": "list", "entityId": list_id,
     "action": "upsert", "clientUpdatedAt": now,
     "payload": {
       "listId": list_id, "name": "常用词", "filterDefinition": {"tag": "common"},
       "clientUpdatedAt": now, "lastModifiedByReplicaId": "44444444-4444-4444-4444-444444444444",
       "lastOperationId": "66666666-6666-6666-6666-666666666666",
       "deletedAt": None}}
  ]
}))
EOF
curl -s -X POST $BASE/workspaces/$WS/sync/push -H "$AUTH" -H "$CT" -d @/tmp/push1.json | python3 -m json.tool

echo "== 3. pull (after 0) =="
curl -s -X POST $BASE/workspaces/$WS/sync/pull -H "$AUTH" -H "$CT" -d "{\"installationId\":\"$INST\",\"platform\":\"web\",\"afterHotChangeId\":0,\"limit\":100}" | python3 -m json.tool

echo "== 4. push same ops again (idempotency) =="
curl -s -X POST $BASE/workspaces/$WS/sync/push -H "$AUTH" -H "$CT" -d @/tmp/push1.json | python3 -c "import json,sys; print([(o['entityType'], o['status']) for o in json.load(sys.stdin)['operations']])"

echo "== 5. submit review (review_event + FSRS state) =="
python3 - "$WS" "$INST" <<'EOF' > /tmp/push2.json
import json, sys, uuid
ws, inst = sys.argv[1], sys.argv[2]
sense = "22222222-2222-2222-2222-222222222222"
unit = "77777777-7777-7777-7777-777777777777"
now = "2026-08-10T15:05:00.000Z"
due = "2026-08-10T15:06:00.000Z"
ev_id = str(uuid.uuid4())
op_card = str(uuid.uuid4())
print(json.dumps({
  "installationId": inst, "platform": "web",
  "operations": [
    {"operationId": ev_id, "entityType": "review_event", "entityId": sense,
     "action": "append", "clientUpdatedAt": now,
     "payload": {
       "reviewEventId": ev_id, "wordSenseId": sense, "programVersion": 1,
       "experienceUnitId": unit, "clientEventId": ev_id,
       "rating": 2, "reviewedAtClient": now, "reviewedTimeZone": "Asia/Shanghai"}},
    {"operationId": op_card, "entityType": "learning_state", "entityId": sense,
     "action": "upsert", "clientUpdatedAt": now,
     "payload": {
       "learningStateId": str(uuid.uuid4()), "wordSenseId": sense,
       "dueAt": due, "reps": 1, "lapses": 0,
       "fsrsStability": 0.212, "fsrsDifficulty": 6.4133,
       "fsrsLastReviewedAt": now, "fsrsScheduledDays": 0,
       "fsrsCardState": "learning", "fsrsStepIndex": 0,
       "clientUpdatedAt": now, "lastModifiedByReplicaId": "44444444-4444-4444-4444-444444444444",
       "lastOperationId": op_card,
       "deletedAt": None}}
  ]
}))
EOF
curl -s -X POST $BASE/workspaces/$WS/sync/push -H "$AUTH" -H "$CT" -d @/tmp/push2.json | python3 -m json.tool

echo "== 6. review-history pull =="
curl -s -X POST $BASE/workspaces/$WS/sync/review-history/pull -H "$AUTH" -H "$CT" -d "{\"installationId\":\"$INST\",\"platform\":\"web\",\"afterReviewSequenceId\":0,\"limit\":100}" | python3 -m json.tool

echo "== 7. pull delta =="
curl -s -X POST $BASE/workspaces/$WS/sync/pull -H "$AUTH" -H "$CT" -d "{\"installationId\":\"$INST\",\"platform\":\"web\",\"afterHotChangeId\":2,\"limit\":100}" | python3 -m json.tool

echo "== 8. bootstrap again (full hydration) =="
curl -s -X POST $BASE/workspaces/$WS/sync/bootstrap -H "$AUTH" -H "$CT" -d "{\"mode\":\"pull\",\"installationId\":\"$INST\",\"platform\":\"web\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('entries:', [(e['entityType']) for e in d['entries']], 'hasMore:', d['hasMore'])"

echo "ALL DONE"
