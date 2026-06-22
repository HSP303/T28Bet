#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-t28bet}"
SERVICE="${2:-mongo-lb-svc}"

hostname="$(kubectl -n "${NAMESPACE}" get svc "${SERVICE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

if [[ -z "${hostname}" ]]; then
  hostname=""
fi

printf '{"hostname":"%s"}\n' "${hostname}"
