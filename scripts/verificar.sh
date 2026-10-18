#!/bin/bash
set -uo pipefail
NS="devops-portfolio"
ERRORS=0
ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS+1)); }
check_http() {
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$1" 2>/dev/null)
    [ "$CODE" = "200" ] && ok "$1 -> HTTP $CODE" || fail "$1 -> HTTP $CODE"
}
echo "=== Verificacion Kubernetes - TP09 ==="
echo ""
echo "--- Nodos del cluster ---"
while read -r NAME STATUS _; do
    [ "$STATUS" = "Ready" ] && ok "Nodo $NAME -> $STATUS" || fail "Nodo $NAME -> $STATUS"
done < <(kubectl get nodes --no-headers)
echo ""
echo "--- Pods (deben estar Running) ---"
while read -r NAME READY STATUS _; do
    [ "$STATUS" = "Running" ] && [ "${READY%/*}" = "${READY#*/}" ] && ok "$NAME -> $STATUS ($READY)" || fail "$NAME -> $STATUS ($READY)"
done < <(kubectl get pods -n "$NS" --no-headers)
echo ""
echo "--- Deployments ---"
while read -r NAME READY _; do
    [ "${READY%/*}" = "${READY#*/}" ] && ok "$NAME -> $READY replicas listas" || fail "$NAME -> $READY (faltan replicas)"
done < <(kubectl get deployments -n "$NS" --no-headers)
echo ""
echo "--- Services ---"
while read -r NAME TYPE _ _ PORT _; do
    ok "$NAME -> $TYPE ($PORT)"
done < <(kubectl get svc -n "$NS" --no-headers)
echo ""
echo "--- PVC (debe estar Bound) ---"
while read -r NAME STATUS _ SIZE _; do
    [ "$STATUS" = "Bound" ] && ok "$NAME -> $STATUS ($SIZE)" || fail "$NAME -> $STATUS"
done < <(kubectl get pvc -n "$NS" --no-headers)
echo ""
echo "--- Healthcheck HTTP (NodePort 30080) ---"
check_http "http://localhost:30080/"
check_http "http://localhost:30080/health"
check_http "http://localhost:30080/api/notes"
echo ""
[ "$ERRORS" -eq 0 ] && echo "Cluster OK - todos los checks pasaron" || echo "$ERRORS checks fallaron"
