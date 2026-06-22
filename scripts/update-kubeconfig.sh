#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v terraform >/dev/null 2>&1 || {
  echo "terraform não encontrado no PATH" >&2
  exit 1
}

command -v aws >/dev/null 2>&1 || {
  echo "aws CLI não encontrado no PATH" >&2
  exit 1
}

AWS_REGION="$(terraform -chdir="$ROOT_DIR/infra" output -raw aws_region)"
CLUSTER_NAME="$(terraform -chdir="$ROOT_DIR/infra" output -raw eks_cluster_name)"

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
