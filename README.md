# TP09 - Kubernetes: Pods, Deployments y Services

App de notas (Flask + Postgres + Nginx) del TP06 desplegada en un cluster k3d de 3 nodos.

## Arquitectura

    Namespace: devops-portfolio
    |-- Deployment: postgres  (1 replica)   <- Service ClusterIP postgres-service :5432 (PVC 1Gi)
    |-- Deployment: backend   (2 replicas)  <- Service ClusterIP backend :5000
    |-- Deployment: frontend  (2 replicas)  <- Service NodePort frontend-service :30080

El frontend (Nginx) llama al backend por el nombre "backend", por eso el Service del backend se llama asi.

## Recursos Kubernetes usados

| Recurso | Para que sirve |
|---|---|
| Namespace | Aislar todos los recursos del proyecto |
| Secret | Credenciales de Postgres (no se sube a GitHub, ver abajo) |
| ConfigMap | Variables de entorno no sensibles del backend |
| PersistentVolumeClaim | Almacenamiento persistente para la base (1Gi, local-path) |
| Deployment | Pods y replicas con rolling update (maxUnavailable 0) |
| Service ClusterIP | Comunicacion interna entre pods |
| Service NodePort | Exposicion al exterior del cluster (30080) |
| initContainer | Espera a que Postgres este listo antes de arrancar el backend |
| readinessProbe y livenessProbe | Trafico solo a pods listos y reinicio de pods colgados |
| resources | Requests y limits de CPU y memoria por pod |

## Cluster e imagenes

    k3d cluster create mi-cluster --api-port 127.0.0.1:6550 -p "30080:30080@agent:0" -p "30081:30081@agent:0" -p "30082:30082@agent:0" --agents 2
    docker tag devops-tp08-backend:latest notes-backend:v1.0.0
    docker tag devops-tp08-frontend:latest notes-frontend:v1.0.0
    k3d image import notes-backend:v1.0.0 notes-frontend:v1.0.0 -c mi-cluster

Las imagenes se cargan al cluster con k3d (no se usa Docker Hub) y los Deployments usan imagePullPolicy IfNotPresent.

## Secret

El Secret real (manifests/db/secret.yml) esta en el .gitignore. Para crearlo:

    cp manifests/db/secret.yml.example manifests/db/secret.yml
    # editar POSTGRES_PASSWORD

## Deploy y verificacion

    bash scripts/deploy.sh
    bash scripts/verificar.sh

App disponible en http://localhost:30080

## Comandos utiles

    kubectl get all -n devops-portfolio
    kubectl scale deployment backend --replicas=3 -n devops-portfolio
    kubectl logs -l app=backend -n devops-portfolio --tail=20
    kubectl rollout history deployment/backend -n devops-portfolio
    kubectl rollout undo deployment/backend -n devops-portfolio

## TP09B - Resiliencia: namespaces, rolling update y rollback

Mismo cluster, ahora con dos entornos aislados por namespace. Los manifiestos de k8s/base se
aplican a cada namespace con -n, por eso no llevan namespace adentro.

| Entorno | Namespace | Acceso (NodePort) |
|---|---|---|
| Staging | staging | http://localhost:30081 |
| Produccion | production | http://localhost:30082 |

Cada namespace tiene su propia base de datos: una nota creada en staging no aparece en production.

### Secret e imagenes

    cp k8s/base/01-secret.yml.example k8s/base/01-secret.yml
    # editar las claves (el archivo real esta en el .gitignore)
    k3d image import postgres:16-alpine busybox:1.36 -c mi-cluster

### Despliegue

    ./scripts/deploy-env.sh staging
    ./scripts/deploy-env.sh production

### Release roto y rollback

    ./scripts/simular-fallo-prod.sh
    kubectl get pods -n production -l app=notes-backend
    kubectl rollout history deployment/notes-backend -n production
    kubectl rollout undo deployment/notes-backend -n production

Con maxUnavailable 0 los pods viejos no se apagan hasta que el nuevo esta listo: la app siguio
respondiendo 200 durante el release roto.

### Auditoria

    ./scripts/verificar-k8s-resiliencia.sh
