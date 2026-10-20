#!/bin/bash
set -uo pipefail
ERRORS=0
ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS+1)); }
info() { echo ""; echo "=== $1 ==="; }
jp() { kubectl get "$1" "$2" -n "$3" -o jsonpath="$4" 2>/dev/null; }
info "1. Aislamiento de namespaces"
for ns in staging production; do
    kubectl get namespace "$ns" >/dev/null 2>&1 && ok "Namespace $ns presente" || fail "Namespace $ns no encontrado"
done
IP_S=$(jp svc backend staging '{.spec.clusterIP}')
IP_P=$(jp svc backend production '{.spec.clusterIP}')
if [ -n "$IP_S" ] && [ -n "$IP_P" ] && [ "$IP_S" != "$IP_P" ]; then
    ok "Service backend con IP propia por namespace (staging $IP_S, production $IP_P)"
else
    fail "Service backend sin IP propia por namespace"
fi
info "2. Replicas y salud del backend"
for ns in staging production; do
    DESIRED=$(jp deployment notes-backend "$ns" '{.spec.replicas}')
    READY=$(jp deployment notes-backend "$ns" '{.status.readyReplicas}')
    READY=${READY:-0}
    if [ "$DESIRED" = "$READY" ] && [ "$READY" -ge 2 ]; then
        ok "$ns: $READY/$DESIRED replicas listas"
    else
        fail "$ns: $READY/${DESIRED:-?} replicas listas"
    fi
done
info "3. Estrategia y sondas (production)"
STRATEGY=$(jp deployment notes-backend production '{.spec.strategy.type}')
MAX_UNAVAIL=$(jp deployment notes-backend production '{.spec.strategy.rollingUpdate.maxUnavailable}')
if [ "$STRATEGY" = "RollingUpdate" ] && [ "$MAX_UNAVAIL" = "0" ]; then
    ok "Zero-Downtime: RollingUpdate con maxUnavailable 0"
else
    fail "Estrategia suboptima ($STRATEGY, maxUnavailable $MAX_UNAVAIL)"
fi
PROBE=$(jp deployment notes-backend production '{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')
[ "$PROBE" = "/health" ] && ok "Sonda de disponibilidad en /health" || fail "Sonda de disponibilidad: $PROBE"
info "4. Imagen en uso (production)"
IMG=$(jp deployment notes-backend production '{.spec.template.spec.containers[0].image}')
[ "$IMG" = "notes-backend:v1.0.0" ] && ok "production usa $IMG" || fail "production usa $IMG"
info "5. Respuesta HTTP por entorno"
for par in staging:30081 production:30082; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:${par#*:}/health")
    [ "$CODE" = "200" ] && ok "${par%:*}: HTTP $CODE" || fail "${par%:*}: HTTP $CODE"
done
echo ""
[ "$ERRORS" -eq 0 ] && echo "Auditoria de resiliencia finalizada con exito" || echo "Auditoria finalizada con $ERRORS checks fallidos"
