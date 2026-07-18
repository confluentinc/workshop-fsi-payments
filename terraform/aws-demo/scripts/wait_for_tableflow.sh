#!/usr/bin/env bash
# Poll Confluent Tableflow until topic materialization is RUNNING (and catalog
# integration is CONNECTED when present). Replaces a fixed sleep — cold starts
# often stay PENDING for 30–60+ minutes before the first S3/UC publish.
#
# Required env:
#   TABLEFLOW_API_KEY, TABLEFLOW_API_SECRET
#   ENVIRONMENT_ID, KAFKA_CLUSTER_ID
#   PAYMENTS_TOPIC, RISK_SCORE_TOPIC
#
# Optional env:
#   TABLEFLOW_WAIT_ATTEMPTS (default 90)
#   TABLEFLOW_WAIT_SECONDS  (default 60)  → ~90 minutes max
set -euo pipefail

: "${TABLEFLOW_API_KEY:?}"
: "${TABLEFLOW_API_SECRET:?}"
: "${ENVIRONMENT_ID:?}"
: "${KAFKA_CLUSTER_ID:?}"
: "${PAYMENTS_TOPIC:?}"
: "${RISK_SCORE_TOPIC:?}"

TABLEFLOW_WAIT_ATTEMPTS="${TABLEFLOW_WAIT_ATTEMPTS:-90}"
TABLEFLOW_WAIT_SECONDS="${TABLEFLOW_WAIT_SECONDS:-60}"
API="https://api.confluent.cloud/tableflow/v1"

log() { echo "$*"; }

fetch_topics() {
  curl -sf -u "${TABLEFLOW_API_KEY}:${TABLEFLOW_API_SECRET}" \
    "${API}/tableflow-topics?environment=${ENVIRONMENT_ID}&spec.kafka_cluster=${KAFKA_CLUSTER_ID}"
}

fetch_catalogs() {
  curl -sf -u "${TABLEFLOW_API_KEY}:${TABLEFLOW_API_SECRET}" \
    "${API}/catalog-integrations?environment=${ENVIRONMENT_ID}&spec.kafka_cluster=${KAFKA_CLUSTER_ID}" \
    || true
}

topic_phase() {
  local body="$1" name="$2"
  echo "$body" | jq -r --arg n "$name" \
    '.data[]? | select(.spec.display_name == $n) | .status.phase // empty' | head -1
}

topic_error() {
  local body="$1" name="$2"
  echo "$body" | jq -r --arg n "$name" \
    '.data[]? | select(.spec.display_name == $n) | .status.error_message // "none"' | head -1
}

catalog_ready() {
  local body="$1"
  # No catalog integrations → skip (storage-only / Iceberg paths).
  local count
  count=$(echo "$body" | jq '.data | length' 2>/dev/null || echo 0)
  if [[ -z "$count" || "$count" == "0" || "$count" == "null" ]]; then
    return 0
  fi
  # All listed integrations must be CONNECTED.
  local bad
  bad=$(echo "$body" | jq '[.data[] | select((.status.phase // "") != "CONNECTED")] | length')
  [[ "$bad" == "0" ]]
}

log "Waiting for Tableflow topics RUNNING: ${PAYMENTS_TOPIC}, ${RISK_SCORE_TOPIC}"
log "  (up to $((TABLEFLOW_WAIT_ATTEMPTS * TABLEFLOW_WAIT_SECONDS / 60)) minutes; cold starts can take 30–60+)"

for i in $(seq 1 "$TABLEFLOW_WAIT_ATTEMPTS"); do
  topics_json=$(fetch_topics) || {
    log "  Tableflow topics API not ready (attempt $i/$TABLEFLOW_WAIT_ATTEMPTS); sleeping ${TABLEFLOW_WAIT_SECONDS}s"
    sleep "$TABLEFLOW_WAIT_SECONDS"
    continue
  }

  payments_phase=$(topic_phase "$topics_json" "$PAYMENTS_TOPIC")
  risk_phase=$(topic_phase "$topics_json" "$RISK_SCORE_TOPIC")
  payments_err=$(topic_error "$topics_json" "$PAYMENTS_TOPIC")
  risk_err=$(topic_error "$topics_json" "$RISK_SCORE_TOPIC")

  catalogs_json=$(fetch_catalogs)
  catalog_ok=0
  if catalog_ready "$catalogs_json"; then
    catalog_ok=1
  fi
  catalog_phases=$(echo "$catalogs_json" | jq -r '[.data[]? | .status.phase // "?"] | join(",")' 2>/dev/null || echo "")

  log "  attempt $i/$TABLEFLOW_WAIT_ATTEMPTS: ${PAYMENTS_TOPIC}=${payments_phase:-missing} err=${payments_err:-n/a}; ${RISK_SCORE_TOPIC}=${risk_phase:-missing} err=${risk_err:-n/a}; catalog=[${catalog_phases:-none}]"

  if [[ "$payments_phase" == "RUNNING" && "$risk_phase" == "RUNNING" && "$catalog_ok" -eq 1 ]]; then
    log "Tableflow materialization RUNNING and catalog integration CONNECTED."
    exit 0
  fi

  # Fail fast on hard errors; ignore PENDING and error_message=none.
  fail_if_bad() {
    local name="$1" phase="$2" err="$3"
    if [[ "$phase" == "FAILED" || "$phase" == "SUSPENDED" ]]; then
      echo "ERROR: Tableflow topic $name is $phase (error_message=$err)" >&2
      exit 1
    fi
  }
  fail_if_bad "$PAYMENTS_TOPIC" "$payments_phase" "$payments_err"
  fail_if_bad "$RISK_SCORE_TOPIC" "$risk_phase" "$risk_err"

  sleep "$TABLEFLOW_WAIT_SECONDS"
done

echo "ERROR: Timed out waiting for Tableflow topics to reach RUNNING (+ catalog CONNECTED)." >&2
echo "Check Tableflow / provider integration / S3 in Confluent Cloud, then re-apply." >&2
exit 1
