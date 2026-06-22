#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-t28bet}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl não encontrado no PATH" >&2
  exit 1
}

"$ROOT_DIR/scripts/update-kubeconfig.sh"

kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"
kubectl get hpa -n "$NAMESPACE"
kubectl describe deployment/backend -n "$NAMESPACE"
kubectl describe deployment/frontend -n "$NAMESPACE"
