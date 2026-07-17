#!/usr/bin/env bash
# Wait for Schema Registry subjects required by Flink (Avro wire format).
# Env: SR_URL, SR_KEY, SR_SECRET
set -euo pipefail

echo "Waiting for Schema Registry subjects (Avro)..."
subjects=(
  "riverflow.riverpay.customer_profiles-value"
  "riverflow.payments.initiation-value"
  "riverflow.payments.authorization-value"
  "riverflow.payments.balance_update-value"
  "riverflow.payments.status-value"
)
max_attempts=60

for subject in "${subjects[@]}"; do
  attempt=0
  while [ "$attempt" -lt "$max_attempts" ]; do
    code=$(curl -s -o /dev/null -w "%{http_code}" \
      -u "${SR_KEY}:${SR_SECRET}" \
      "${SR_URL}/subjects/${subject}/versions/latest" || true)
    if [ "$code" = "200" ]; then
      echo "✅ ${subject} ready"
      break
    fi
    attempt=$((attempt + 1))
    echo "   ${subject} not ready (HTTP ${code}), attempt ${attempt}/${max_attempts}..."
    sleep 10
  done
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "❌ Timed out waiting for Schema Registry subject: ${subject}"
    echo "List subjects:"
    curl -s -u "${SR_KEY}:${SR_SECRET}" "${SR_URL}/subjects" || true
    exit 1
  fi
done

echo "All required schemas present."
