#!/usr/bin/env bash
# Create RiverPulse Genie views in Databricks after Tableflow publishes base tables.
# Required env: DB_HOST, DB_CLIENT_ID, DB_CLIENT_SECRET, DB_WAREHOUSE_ID, DB_CATALOG, DB_SCHEMA
set -euo pipefail

: "${DB_HOST:?}"
: "${DB_CLIENT_ID:?}"
: "${DB_CLIENT_SECRET:?}"
: "${DB_WAREHOUSE_ID:?}"
: "${DB_CATALOG:?}"
: "${DB_SCHEMA:?}"

DB_HOST="${DB_HOST%/}"
# After Tableflow reaches RUNNING, UC schema/table publish can still lag.
# Default ~60 minutes (was 15) so cold-start applies do not false-fail.
TABLE_WAIT_ATTEMPTS="${TABLE_WAIT_ATTEMPTS:-60}"
TABLE_WAIT_SECONDS="${TABLE_WAIT_SECONDS:-60}"
STMT_WAIT_ATTEMPTS="${STMT_WAIT_ATTEMPTS:-12}"
STMT_WAIT_SECONDS="${STMT_WAIT_SECONDS:-10}"

log() { echo "$*"; }

get_token() {
  local token
  token=$(curl -sf -X POST "$DB_HOST/oidc/v1/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=$DB_CLIENT_ID&client_secret=$DB_CLIENT_SECRET&scope=all-apis" \
    | jq -r '.access_token')
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "ERROR: Failed to obtain Databricks OAuth token" >&2
    exit 1
  fi
  printf '%s' "$token"
}

# Run one SQL statement; poll through PENDING; print error body on failure.
run_sql() {
  local token="$1"
  local label="$2"
  local statement="$3"
  local payload response status statement_id error_msg i

  payload=$(jq -n \
    --arg warehouse_id "$DB_WAREHOUSE_ID" \
    --arg catalog "$DB_CATALOG" \
    --arg schema "$DB_SCHEMA" \
    --arg statement "$statement" \
    '{
      warehouse_id: $warehouse_id,
      catalog: $catalog,
      schema: $schema,
      statement: $statement,
      wait_timeout: "50s",
      on_wait_timeout: "CONTINUE"
    }')

  response=$(curl -s -X POST "$DB_HOST/api/2.0/sql/statements" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$payload")

  status=$(echo "$response" | jq -r '.status.state // empty')
  statement_id=$(echo "$response" | jq -r '.statement_id // empty')

  for i in $(seq 1 "$STMT_WAIT_ATTEMPTS"); do
    case "$status" in
      SUCCEEDED)
        log "  OK  $label"
        return 0
        ;;
      FAILED|CANCELED|CLOSED)
        error_msg=$(echo "$response" | jq -c '.status.error // .')
        log "  FAIL $label (status=$status) error=$error_msg"
        return 1
        ;;
      PENDING|RUNNING|"")
        if [[ -z "$statement_id" || "$statement_id" == "null" ]]; then
          error_msg=$(echo "$response" | jq -c '.')
          log "  FAIL $label (no statement_id) response=$error_msg"
          return 1
        fi
        log "  ... $label still $status (poll $i/$STMT_WAIT_ATTEMPTS, id=$statement_id)"
        sleep "$STMT_WAIT_SECONDS"
        response=$(curl -s -H "Authorization: Bearer $token" \
          "$DB_HOST/api/2.0/sql/statements/$statement_id")
        status=$(echo "$response" | jq -r '.status.state // empty')
        ;;
      *)
        error_msg=$(echo "$response" | jq -c '.')
        log "  FAIL $label (unexpected status=$status) response=$error_msg"
        return 1
        ;;
    esac
  done

  error_msg=$(echo "$response" | jq -c '.status.error // .')
  log "  FAIL $label timed out waiting (last status=$status) error=$error_msg"
  return 1
}

tables_ready() {
  local token="$1"
  local response state data
  # Prefer Unity Catalog REST — works even before a SQL warehouse schema context exists.
  response=$(curl -s -H "Authorization: Bearer $token" \
    "$DB_HOST/api/2.1/unity-catalog/tables?catalog_name=$DB_CATALOG&schema_name=$DB_SCHEMA")
  if echo "$response" | jq -e '.tables' >/dev/null 2>&1; then
    data=$(echo "$response" | jq -r '[.tables[].name] | join(",")')
    log "  UC tables in $DB_CATALOG.$DB_SCHEMA: ${data:-<none>}"
    echo "$response" | jq -e \
      --arg p "riverflow_payments" \
      --arg r "riverflow_payments_risk_score" \
      '[.tables[].name] | index($p) and index($r)' >/dev/null
    return $?
  fi

  # Fallback: SQL SHOW TABLES (needs schema to exist)
  response=$(curl -s -X POST "$DB_HOST/api/2.0/sql/statements" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg warehouse_id "$DB_WAREHOUSE_ID" \
      --arg catalog "$DB_CATALOG" \
      --arg schema "$DB_SCHEMA" \
      '{warehouse_id:$warehouse_id,catalog:$catalog,schema:$schema,statement:"SHOW TABLES",wait_timeout:"50s",on_wait_timeout:"CONTINUE"}')")
  state=$(echo "$response" | jq -r '.status.state // empty')
  if [[ "$state" != "SUCCEEDED" ]]; then
    log "  SHOW TABLES not ready: $(echo "$response" | jq -c '.status.error // .status.state')"
    return 1
  fi
  data=$(echo "$response" | jq -r '[.result.data_array[]?[0]] | join(",")')
  log "  SHOW TABLES: ${data:-<none>}"
  echo "$response" | jq -e \
    --arg p "riverflow_payments" \
    --arg r "riverflow_payments_risk_score" \
    '[.result.data_array[]?[0]] | index($p) and index($r)' >/dev/null
}

TOKEN=$(get_token)
log "Waiting for Tableflow tables in $DB_CATALOG.$DB_SCHEMA ..."
ready=0
for i in $(seq 1 "$TABLE_WAIT_ATTEMPTS"); do
  if tables_ready "$TOKEN"; then
    ready=1
    break
  fi
  log "  tables not ready yet (attempt $i/$TABLE_WAIT_ATTEMPTS); sleeping ${TABLE_WAIT_SECONDS}s"
  sleep "$TABLE_WAIT_SECONDS"
  # refresh token periodically (OAuth tokens can expire on long waits)
  if (( i % 10 == 0 )); then
    TOKEN=$(get_token)
  fi
done

if [[ "$ready" -ne 1 ]]; then
  echo "ERROR: Timed out waiting for riverflow_payments + riverflow_payments_risk_score in $DB_CATALOG.$DB_SCHEMA" >&2
  echo "Check Tableflow catalog sync / S3 materialization in Confluent Cloud, then re-apply." >&2
  exit 1
fi

log "Creating RiverPulse views (one statement each)..."

# Statement Execution API accepts a single statement per request.
run_sql "$TOKEN" "riverpulse_high_risk_payments" \
"CREATE OR REPLACE VIEW riverpulse_high_risk_payments AS
SELECT payment_id, customer_id, segment, account_tier, amount, currency,
       risk_score, risk_reason, enrichment_timestamp
FROM riverflow_payments_risk_score
WHERE risk_score >= 0.5"

run_sql "$TOKEN" "riverpulse_customer_risk_7d" \
"CREATE OR REPLACE VIEW riverpulse_customer_risk_7d AS
SELECT customer_id, segment, account_tier,
       COUNT(*) AS payment_count,
       AVG(risk_score) AS avg_risk_score,
       MAX(risk_score) AS max_risk_score
FROM riverflow_payments_risk_score
WHERE enrichment_timestamp >= current_timestamp() - INTERVAL 7 DAYS
GROUP BY customer_id, segment, account_tier"

# Phase 1 proxy: risk_score rows ≈ initiated+enriched; riverflow_payments ≈ fully completed.
run_sql "$TOKEN" "riverpulse_lifecycle_completion" \
"CREATE OR REPLACE VIEW riverpulse_lifecycle_completion AS
SELECT
  (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) AS initiated_enriched,
  (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments) AS completed,
  CASE
    WHEN (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) = 0 THEN NULL
    ELSE CAST((SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments) AS DOUBLE)
         / CAST((SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) AS DOUBLE)
  END AS completion_rate"

log "RiverPulse views created successfully"
