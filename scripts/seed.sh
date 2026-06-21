#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-t28bet}"
LOCAL_MONGO_PORT="${LOCAL_MONGO_PORT:-27018}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v terraform >/dev/null 2>&1 || {
  echo "terraform não encontrado no PATH" >&2
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl não encontrado no PATH" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || {
  echo "docker não encontrado no PATH" >&2
  exit 1
}

"$ROOT_DIR/scripts/update-kubeconfig.sh"

echo "Aguardando o Mongo do cluster via port-forward em 127.0.0.1:${LOCAL_MONGO_PORT}..."
kubectl -n "$NAMESPACE" port-forward svc/mongo-svc "${LOCAL_MONGO_PORT}:27017" >/tmp/t28bet-mongo-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!

cleanup() {
  kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
  wait "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 30); do
  if (echo >"/dev/tcp/127.0.0.1/${LOCAL_MONGO_PORT}") >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! (echo >"/dev/tcp/127.0.0.1/${LOCAL_MONGO_PORT}") >/dev/null 2>&1; then
  echo "Port-forward do Mongo não ficou pronto. Veja /tmp/t28bet-mongo-port-forward.log" >&2
  exit 1
fi

export MONGO_URI="mongodb://127.0.0.1:${LOCAL_MONGO_PORT}/t28bet"
BACKEND_IMAGE_URI="$(terraform -chdir="$ROOT_DIR/infra" output -raw backend_image_uri)"

DOCKER_RUN=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER_RUN=(sudo docker)
fi

echo "Executando seed localmente contra ${MONGO_URI}"
"${DOCKER_RUN[@]}" run --rm --network host \
  -e MONGO_URI="$MONGO_URI" \
  "$BACKEND_IMAGE_URI" \
  node dist/scripts/seed.js
