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

read -r -p "Isso vai destruir a infraestrutura do laboratório. Digite 'destroy' para continuar: " confirmation
if [[ "$confirmation" != "destroy" ]]; then
  echo "Operação cancelada."
  exit 1
fi

"$ROOT_DIR/scripts/update-kubeconfig.sh"

kubectl delete -f "$ROOT_DIR/k8s/ingress.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/frontend/deployment.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/frontend/service.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/backend/deployment.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/backend/hpa.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/backend/service.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/backend/serviceaccount.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/mongo/statefulset.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/mongo/service.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/secret.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/configmap.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/namespace.yaml" --ignore-not-found

terraform -chdir="$ROOT_DIR/infra" destroy -auto-approve
