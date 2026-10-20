#!/bin/bash
set -euo pipefail
echo "=== LANZANDO RELEASE CORRUPTO (v2.0.0-broken) EN PRODUCCION ==="
kubectl set image deployment/notes-backend backend=redis:alpine-nonexistent -n production
echo "Kubernetes intenta levantar el pod nuevo sin apagar los viejos"
