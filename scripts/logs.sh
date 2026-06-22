#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-backend}"
shift || true
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl não encontrado no PATH" >&2
  exit 1
}

"$ROOT_DIR/scripts/update-kubeconfig.sh"

case "$TARGET" in
  backend|frontend)
    kubectl logs -n t28bet "deployment/${TARGET}" --tail=200 "$@"
    ;;
  seed)
    kubectl logs -n t28bet "job/t28bet-seed" --tail=200 "$@"
    ;;
  *)
    echo "Uso: $0 [backend|frontend|seed] [kubectl logs flags...]" >&2
    exit 1
    ;;
esac
