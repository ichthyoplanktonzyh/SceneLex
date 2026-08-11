#!/bin/bash
# End-to-end sync protocol verification against a running server on :8080.
set -e
BASE=http://127.0.0.1:8081/v1
EMAIL="sync-$(date +%s)@scenelex.app"

echo "== auth =="
curl -s -X POST $BASE/auth/send-code -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\"}" -o /dev/null
CODE=$(grep -o "code=[0-9]\{8\}" /tmp/scenelex-server.log | tail -1 | cut -d= -f2)
VERIFY=$(curl -s -X POST $BASE/auth/verify-code -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\"}")
TOKEN=$(echo "$VERIFY" | python3 -c "import json,sys; print(json.load(sys.stdin)['idToken'])")
REFRESH=$(echo "$VERIFY" | python3 -c "import json,sys; print(json.load(sys.stdin)['refreshToken'])")
echo "idToken+refreshToken issued (expiresIn: $(echo "$VERIFY" | python3 -c "import json,sys; print(json.load(sys.stdin)['expiresIn'])"))"

AUTH="Authorization: Bearer $TOKEN"
CT="Content-Type: application/json"

echo "== 0. session renewal: refresh-token / revoke-token =="
WS=$(curl -s $BASE/me -H "$AUTH" | python3 -c "import json,sys; print(json.load(sys.stdin)['selectedWorkspaceId'])")
echo "workspace: $WS"
ID2=$(curl -s -X POST $BASE/auth/refresh-token -H "$CT" -d "{\"refreshToken\":\"$REFRESH\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['idToken'])")
echo "refresh-token -> new idToken (expiresIn: $(curl -s -X POST $BASE/auth/refresh-token -H "$CT" -d "{\"refreshToken\":\"$REFRESH\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['expiresIn'])"))"
curl -s $BASE/me -H "Authorization: Bearer $ID2" | python3 -c "import json,sys; d=json.load(sys.stdin); print('new idToken works, workspace:', d['selectedWorkspaceId'])"
curl -s -X POST $BASE/auth/revoke-token -H "$CT" -d "{\"refreshToken\":\"$REFRESH\"}" | python3 -m json.tool
echo -n "refresh with revoked token -> HTTP "
curl -s -o /tmp/revoked_refresh.json -w "%{http_code}\n" -X POST $BASE/auth/refresh-token -H "$CT" -d "{\"refreshToken\":\"$REFRESH\"}"
cat /tmp/revoked_refresh.json
echo
echo -n "revoke again (idempotent) -> HTTP "
curl -s -o /dev/null -w "%{http_code}\n" -X POST $BASE/auth/revoke-token -H "$CT" -d "{\"refreshToken\":\"$REFRESH\"}"
echo -n "refresh with missing token -> HTTP "
curl -s -o /tmp/missing_refresh.json -w "%{http_code}\n" -X POST $BASE/auth/refresh-token -H "$CT" -d "{}"
cat /tmp/missing_refresh.json

INST=$(python3 -c "import uuid; print(uuid.uuid4())")

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

echo "== 9. workspace rename =="
curl -s -X POST $BASE/workspaces/$WS/rename -H "$AUTH" -H "$CT" -d "{\"name\":\"Renamed WS\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('name:', d['name'])"

echo "== 10. reset-progress (wrong confirmation -> 400) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST $BASE/workspaces/$WS/reset-progress -H "$AUTH" -H "$CT" -d "{\"confirmationText\":\"nope\"}"

echo "== 11. reset-progress (correct confirmation) =="
curl -s -X POST $BASE/workspaces/$WS/reset-progress -H "$AUTH" -H "$CT" -d "{\"confirmationText\":\"reset all progress for all cards in this workspace\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('cardsResetCount:', d['cardsResetCount'])"

echo "== 12. bootstrap after reset (learning_state gone, list/settings remain) =="
curl -s -X POST $BASE/workspaces/$WS/sync/bootstrap -H "$AUTH" -H "$CT" -d "{\"mode\":\"pull\",\"installationId\":\"$INST\",\"platform\":\"web\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('entries:', [(e['entityType']) for e in d['entries']])"

echo "== 13. workspace delete (wrong confirmation -> 400) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST $BASE/workspaces/$WS/delete -H "$AUTH" -H "$CT" -d "{\"confirmationText\":\"nope\"}"

echo "== 14. workspace delete (correct confirmation) =="
curl -s -X POST $BASE/workspaces/$WS/delete -H "$AUTH" -H "$CT" -d "{\"confirmationText\":\"delete workspace\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('deletedCardsCount:', d['deletedCardsCount'])"

echo "== 15. /me re-bootstraps a new Personal workspace =="
WS2=$(curl -s $BASE/me -H "$AUTH" | python3 -c "import json,sys; print(json.load(sys.stdin)['selectedWorkspaceId'])")
echo "new workspace: $WS2"

echo "== 16. account delete (wrong confirmation -> 400) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST $BASE/account/delete -H "$AUTH" -H "$CT" -d "{\"confirmationText\":\"nope\"}"

echo "== 17. account delete (correct confirmation) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST $BASE/account/delete -H "$AUTH" -H "$CT" -d "{\"confirmationText\":\"delete my account\"}"

echo "== 18. stale token -> 410 ACCOUNT_DELETED =="
curl -s -o /tmp/after_delete.json -w "%{http_code}\n" $BASE/me -H "$AUTH"
cat /tmp/after_delete.json

echo "== 19. deleted email cannot re-register (send-code -> 410) =="
curl -s -o /dev/null -w "%{http_code}\n" -X POST $BASE/auth/send-code -H "$CT" -d "{\"email\":\"$EMAIL\"}"

echo "ALL DONE"
