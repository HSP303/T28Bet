#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl não encontrado no PATH" >&2
  exit 1
}

"$ROOT_DIR/scripts/update-kubeconfig.sh"

echo "Removendo webhooks do AWS Load Balancer Controller que podem travar o cluster..."
kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration -o name \
  | grep -E 'aws-load-balancer|elbv2' \
  | xargs -r kubectl delete

echo "Limpando recursos do controller que costumam sobrar em releases falhados..."
kubectl -n kube-system delete deployment aws-load-balancer-controller --ignore-not-found
kubectl -n kube-system delete service aws-load-balancer-webhook-service --ignore-not-found

echo "Limpeza concluída."
