#!/usr/bin/env bash
# Smoke-test the shared RiverPay Risk Scoring API (local or Azure Container Apps HTTPS).
# Usage:
#   ./smoke.sh https://riverpay-risk-api.xxx.azurecontainerapps.io [api-key]
#   RISK_API_URL=... RISK_API_KEY=... ./smoke.sh

set -euo pipefail

BASE_URL="${1:-${RISK_API_URL:-}}"
API_KEY="${2:-${RISK_API_KEY:-riverpay-workshop-risk}}"

if [[ -z "$BASE_URL" ]]; then
  echo "Usage: $0 <base-url> [api-key]"
  echo "  e.g. $0 https://riverpay-risk-api.xxx.azurecontainerapps.io"
  exit 1
fi

BASE_URL="${BASE_URL%/}"

echo "==> GET $BASE_URL/health"
curl -fsS "$BASE_URL/health"
echo

echo "==> GET $BASE_URL/v1/risk (Bearer)"
curl -fsS -H "Authorization: Bearer $API_KEY" \
  "$BASE_URL/v1/risk?amount=12000&segment=retail&account_tier=standard"
echo
echo "OK"
