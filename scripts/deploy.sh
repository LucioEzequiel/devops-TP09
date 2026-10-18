#!/bin/bash
# deploy.sh - Aplica todos los manifests en orden
# TP09 - Plan DevOps
set -euo pipefail
NAMESPACE="devops-portfolio"
MANIFEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/manifests"
log()  { echo "[$(date '+%H:%M:%S')] $1"; }
ok()   { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; exit 1; }
log "=== Deploy Kubernetes - DevOps Portfolio ==="
log "Aplicando namespace..."
kubectl apply -f "$MANIFEST_DIR/base/"
ok "Namespace listo"
log "Aplicando base de datos..."
kubectl apply -f "$MANIFEST_DIR/db/"
log "Esperando que Postgres este listo..."
kubectl rollout status deployment/postgres -n "$NAMESPACE" --timeout=90s
ok "Postgres listo"
log "Aplicando backend..."
kubectl apply -f "$MANIFEST_DIR/backend/"
kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=90s
ok "Backend listo"
log "Aplicando frontend..."
kubectl apply -f "$MANIFEST_DIR/frontend/"
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=60s
ok "Frontend listo"
log ""
log "=== Estado final ==="
kubectl get all -n "$NAMESPACE"
log ""
HOST_IP=$(hostname -I | awk '{print $1}')
log "App disponible en: http://localhost:30080 (desde el servidor) o http://$HOST_IP:30080 (desde la red)"
