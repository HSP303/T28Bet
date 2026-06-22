#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v terraform >/dev/null 2>&1 || {
  echo "terraform não encontrado no PATH" >&2
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl não encontrado no PATH" >&2
  exit 1
}

"$ROOT_DIR/scripts/update-kubeconfig.sh"

kubectl apply -f "$ROOT_DIR/k8s/namespace.yaml"
kubectl apply -f "$ROOT_DIR/k8s/configmap.yaml"
kubectl apply -f "$ROOT_DIR/k8s/secret.yaml"
kubectl apply -f "$ROOT_DIR/k8s/backend/serviceaccount.yaml"
kubectl apply -f "$ROOT_DIR/k8s/mongo/service.yaml"
kubectl apply -f "$ROOT_DIR/k8s/mongo/statefulset.yaml"
kubectl apply -f "$ROOT_DIR/k8s/backend/service.yaml"
kubectl apply -f "$ROOT_DIR/k8s/backend/hpa.yaml"
kubectl apply -f "$ROOT_DIR/k8s/backend/deployment.yaml"
kubectl apply -f "$ROOT_DIR/k8s/frontend/service.yaml"
kubectl apply -f "$ROOT_DIR/k8s/frontend/deployment.yaml"
kubectl apply -f "$ROOT_DIR/k8s/ingress.yaml"

kubectl set image deployment/backend \
  backend="$(terraform -chdir="$ROOT_DIR/infra" output -raw backend_image_uri)" \
  -n t28bet

kubectl set image deployment/frontend \
  frontend="$(terraform -chdir="$ROOT_DIR/infra" output -raw frontend_image_uri)" \
  -n t28bet

kubectl rollout status deployment/backend -n t28bet --timeout=5m
kubectl rollout status deployment/frontend -n t28bet --timeout=5m
