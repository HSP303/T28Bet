#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-t28bet}"
SERVICE="${2:-mongo-lb-svc}"

hostname=""
for _ in $(seq 1 60); do
  hostname="$(kubectl -n "${NAMESPACE}" get svc "${SERVICE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -n "${hostname}" ]]; then
    break
  fi
  sleep 5
done

printf '{"hostname":"%s"}\n' "${hostname}"
