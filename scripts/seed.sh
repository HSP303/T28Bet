#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_JOB_NAME="${SEED_JOB_NAME:-t28bet-seed}"
NAMESPACE="${NAMESPACE:-t28bet}"
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

BACKEND_IMAGE_URI="$(terraform -chdir="$ROOT_DIR/infra" output -raw backend_image_uri)"

kubectl delete job "$SEED_JOB_NAME" -n "$NAMESPACE" --ignore-not-found

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${SEED_JOB_NAME}
  namespace: ${NAMESPACE}
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: backend
      containers:
        - name: seed
          image: ${BACKEND_IMAGE_URI}
          imagePullPolicy: Always
          command: ["node", "dist/scripts/seed.js"]
          envFrom:
            - configMapRef:
                name: t28bet-config
            - secretRef:
                name: t28bet-secret
EOF

kubectl wait --for=condition=complete job/"$SEED_JOB_NAME" -n "$NAMESPACE" --timeout=10m
kubectl logs job/"$SEED_JOB_NAME" -n "$NAMESPACE" --tail=200
