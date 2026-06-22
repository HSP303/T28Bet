#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform não encontrado no PATH" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI não encontrado no PATH" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker não encontrado no PATH" >&2
  exit 1
fi

BACKEND_IMAGE_URI="$(terraform -chdir="$ROOT_DIR/infra" output -raw backend_image_uri)"
FRONTEND_IMAGE_URI="$(terraform -chdir="$ROOT_DIR/infra" output -raw frontend_image_uri)"
AWS_REGION="$(terraform -chdir="$ROOT_DIR/infra" output -raw aws_region)"
ECR_REGISTRY="${BACKEND_IMAGE_URI%%/*}"

echo "Fazendo login no ECR: ${ECR_REGISTRY}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Build backend -> ${BACKEND_IMAGE_URI}"
docker build -t "$BACKEND_IMAGE_URI" "$ROOT_DIR/backend"

echo "Build frontend -> ${FRONTEND_IMAGE_URI}"
docker build -t "$FRONTEND_IMAGE_URI" "$ROOT_DIR/frontend"

echo "Push backend -> ${BACKEND_IMAGE_URI}"
docker push "$BACKEND_IMAGE_URI"

echo "Push frontend -> ${FRONTEND_IMAGE_URI}"
docker push "$FRONTEND_IMAGE_URI"

echo "Imagens publicadas com sucesso."
