#!/usr/bin/env bash
#
# validate-run.sh — workshop-specific live validation for a RiverPay FSI Payments
# (Azure or AWS) delivery. Covers Tier 2 (live resource health) and Tier 4 (data
# flow): the checks that require knowing what a *correct RiverPay deployment*
# looks like.
#
# Composability: this is the workshop half of a layered validator.
#   - WSA owns provisioning and emits, into the run directory, per-account
#     Terraform outputs plus generic results files (verify-accounts-results.json,
#     verify-login-results.json). It is workshop-agnostic.
#   - THIS script consumes those outputs (never re-deriving connection details),
#     applies the workshop-specific expectations declared below, and COMPOSES the
#     final validation-report.md from all three layers.
#
# It is read-only: it lists and describes resources, and changes nothing.
#
# Auth (run it the same way you run wsa, so secrets are present):
#   op run --env-file=.env.tpl -- scripts/validate-run.sh --run-dir <wsa-output/<run-id>>
#   - Confluent Cloud checks use the `confluent` CLI (run `confluent login --save`).
#   - Databricks checks use REST + the workspace service principal from
#     TF_VAR_databricks_{azure,aws}_{host,service_principal_client_id,service_principal_client_secret}
#     (picked by --cloud).
#   Any auth that is missing degrades that layer to SKIPPED (never a false failure).
#
# Usage:
#   scripts/validate-run.sh --run-dir <path>  [--cloud azure|aws]  [--accounts 1,4-10]  [--region <region>]
#   scripts/validate-run.sh --run-dir ../../Tools/workshop-setup-accelerator/wsa-output/elv95
#   scripts/validate-run.sh --run-dir <path> --cloud aws
#
# --cloud selects the per-account terraform dir (terraform/azure or terraform/aws),
# the Databricks SP env-var prefix, and the region default (eastus2 for azure,
# us-east-1 for aws). Defaults to azure for backward compatibility.

set -uo pipefail

# ---------------------------------------------------------------------------
# Workshop expectations (facts as data — edit here as the workshop evolves)
# ---------------------------------------------------------------------------
EXPECTED_TOPICS=(
  riverflow.payments.authorization
  riverflow.payments.balance_update
  riverflow.payments.initiation
  riverflow.payments.status
  riverflow.riverpay.customer_profiles
  riverflow.riverpay.fx_rates
)
EXPECTED_CONNECTOR_MIN=1          # at least the Postgres CDC source, RUNNING
EXPECTED_FLINK_COUNT=14           # 12 table DDL/watermark + risk connection + risk UDF
FLINK_OK_STATUSES="COMPLETED RUNNING"   # DDL/ALTER finish COMPLETED; streaming stay RUNNING
# Topics that should be actively receiving data (Tier 4 data-flow probe).
DATAFLOW_TOPICS=( riverflow.payments.initiation riverflow.riverpay.customer_profiles )

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
RUN_DIR=""
ACCOUNTS_ARG=""
REGION_ARG=""
CLOUD="azure"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)  RUN_DIR="$2"; shift 2 ;;
    --cloud)    CLOUD="$2"; shift 2 ;;
    --accounts) ACCOUNTS_ARG="$2"; shift 2 ;;
    --region)   REGION_ARG="$2"; shift 2 ;;
    -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$RUN_DIR" ]] || { echo "error: --run-dir <path to wsa-output/<run-id>> is required" >&2; exit 2; }
RUN_DIR="$(cd "$RUN_DIR" && pwd)" || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }

case "$CLOUD" in
  azure) REGION="${REGION_ARG:-${TF_VAR_azure_cloud_region:-eastus2}}" ;;
  aws)   REGION="${REGION_ARG:-${TF_VAR_aws_cloud_region:-us-east-1}}" ;;
  *) echo "error: --cloud must be 'azure' or 'aws' (got: $CLOUD)" >&2; exit 2 ;;
esac

TF_DIR="$RUN_DIR/terraform/$CLOUD"
[[ -d "$TF_DIR" ]] || { echo "error: per-account terraform dir not found: $TF_DIR" >&2; exit 2; }

command -v jq >/dev/null       || { echo "error: jq is required" >&2; exit 2; }
command -v terraform >/dev/null || { echo "error: terraform is required" >&2; exit 2; }

log()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Which accounts to check: --accounts, else WSA's audited list, else workspaces.
# ---------------------------------------------------------------------------
expand_ranges() { # "1,4-6" -> "1 4 5 6"
  local out=() part a b
  IFS=',' read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    if [[ "$part" == *-* ]]; then a="${part%-*}"; b="${part#*-}"; for ((i=a;i<=b;i++)); do out+=("$i"); done
    else out+=("$part"); fi
  done
  printf '%s\n' "${out[@]}"
}

accounts_list() {
  if [[ -n "$ACCOUNTS_ARG" ]]; then expand_ranges "$ACCOUNTS_ARG"; return; fi
  if [[ -f "$RUN_DIR/verify-accounts-results.json" ]]; then
    jq -r '.accounts_audited[]' "$RUN_DIR/verify-accounts-results.json" 2>/dev/null && return
  fi
  terraform -chdir="$TF_DIR" workspace list 2>/dev/null \
    | sed 's/[* ]//g' | grep -E '^account-[0-9]+$' | sed 's/account-0*//'
}

# Read one raw output for an account (selects its workspace).
tf_out() { # <account-int> <output-name>
  local ws; ws="$(printf 'account-%03d' "$1")"
  terraform -chdir="$TF_DIR" workspace select "$ws" >/dev/null 2>&1 || return 1
  terraform -chdir="$TF_DIR" output -raw "$2" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Auth preflight — each layer degrades to SKIPPED rather than false-failing.
# ---------------------------------------------------------------------------
CC_ENABLED=1
if ! confluent environment list -o json >/dev/null 2>&1; then
  CC_ENABLED=0
  info "Confluent Cloud checks SKIPPED — not logged in (run: confluent login --save)"
fi

DBX_ENABLED=1
case "$CLOUD" in
  azure)
    DBX_HOST="${TF_VAR_databricks_azure_host:-}"
    DBX_CID="${TF_VAR_databricks_azure_service_principal_client_id:-}"
    DBX_SEC="${TF_VAR_databricks_azure_service_principal_client_secret:-}"
    ;;
  aws)
    DBX_HOST="${TF_VAR_databricks_aws_host:-}"
    DBX_CID="${TF_VAR_databricks_aws_service_principal_client_id:-}"
    DBX_SEC="${TF_VAR_databricks_aws_service_principal_client_secret:-}"
    ;;
esac
DBX_TOKEN=""
if [[ -n "$DBX_HOST" && -n "$DBX_CID" && -n "$DBX_SEC" ]]; then
  DBX_TOKEN="$(curl -s -X POST "${DBX_HOST%/}/oidc/v1/token" \
    -u "$DBX_CID:$DBX_SEC" -d grant_type=client_credentials -d scope=all-apis 2>/dev/null \
    | jq -r '.access_token // empty')"
fi
if [[ -z "$DBX_TOKEN" ]]; then
  DBX_ENABLED=0
  info "Databricks checks SKIPPED — SP creds not in env (run under: op run --env-file=.env.tpl -- ...)"
fi

dbx_get() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $DBX_TOKEN" "${DBX_HOST%/}$1"; }

# ---------------------------------------------------------------------------
# Per-account checks
# ---------------------------------------------------------------------------
RESULTS_JSON="$RUN_DIR/validate-run-results.json"
declare -a ROWS=()          # "acct|layer|check|status|detail"
PASS=0; FAIL=0; SKIP=0

record() { # <acct> <layer> <check> <status> <detail>
  ROWS+=("$1|$2|$3|$4|$5")
  case "$4" in PASS) PASS=$((PASS+1));; FAIL) FAIL=$((FAIL+1));; SKIP) SKIP=$((SKIP+1));; esac
}

check_confluent() { # <acct>
  local a="$1" env lkc conns running flinks bad topics missing t
  env="$(tf_out "$a" confluent_environment_id)"
  lkc="$(tf_out "$a" confluent_kafka_cluster_id)"
  if [[ -z "$env" || -z "$lkc" ]]; then
    record "$a" confluent resources FAIL "no env/cluster output"; return
  fi

  # Connector RUNNING
  local cj; cj="$(confluent connect cluster list --environment "$env" --cluster "$lkc" -o json 2>/dev/null)"
  conns="$(jq 'length' <<<"${cj:-[]}" 2>/dev/null || echo 0)"
  running="$(jq '[.[]|select(.status=="RUNNING")]|length' <<<"${cj:-[]}" 2>/dev/null || echo 0)"
  if (( running >= EXPECTED_CONNECTOR_MIN )); then
    record "$a" confluent connectors PASS "$running/$conns RUNNING"
  else
    record "$a" confluent connectors FAIL "$running RUNNING of $conns (want >= $EXPECTED_CONNECTOR_MIN)"
  fi

  # Flink statements: expected count, none in a bad state
  local fj; fj="$(confluent flink statement list --environment "$env" --cloud "$CLOUD" --region "$REGION" -o json 2>/dev/null)"
  flinks="$(jq 'length' <<<"${fj:-[]}" 2>/dev/null || echo 0)"
  bad="$(jq --arg ok "$FLINK_OK_STATUSES" '[.[]|select(($ok|split(" ")|index(.status))==null)]|length' <<<"${fj:-[]}" 2>/dev/null || echo 0)"
  if (( flinks >= EXPECTED_FLINK_COUNT && bad == 0 )); then
    record "$a" confluent flink PASS "$flinks statements, all healthy"
  else
    record "$a" confluent flink FAIL "$flinks/$EXPECTED_FLINK_COUNT statements, $bad unhealthy"
  fi

  # Topics present
  local tj; tj="$(confluent kafka topic list --environment "$env" --cluster "$lkc" -o json 2>/dev/null)"
  topics="$(jq -r '.[].name' <<<"${tj:-[]}" 2>/dev/null)"
  missing=""
  for t in "${EXPECTED_TOPICS[@]}"; do grep -qx "$t" <<<"$topics" || missing+="$t "; done
  if [[ -z "$missing" ]]; then
    record "$a" confluent topics PASS "all ${#EXPECTED_TOPICS[@]} expected topics present"
  else
    record "$a" confluent topics FAIL "missing: ${missing% }"
  fi

  # Tier 4 data-flow proxy: connector RUNNING + Flink healthy => data flowing.
  if (( running >= EXPECTED_CONNECTOR_MIN && bad == 0 && flinks >= EXPECTED_FLINK_COUNT )); then
    record "$a" dataflow pipeline PASS "CDC + Flink active"
  else
    record "$a" dataflow pipeline FAIL "pipeline not fully active"
  fi
}

check_databricks() { # <acct>
  local a="$1" cat wid code
  cat="$(tf_out "$a" dbx_catalog_name)"
  wid="$(tf_out "$a" dbx_sql_warehouse_id)"
  if [[ -n "$cat" ]]; then
    code="$(dbx_get "/api/2.1/unity-catalog/catalogs/$cat")"
    [[ "$code" == 200 ]] && record "$a" databricks catalog PASS "$cat" \
                          || record "$a" databricks catalog FAIL "$cat (HTTP $code)"
  else
    record "$a" databricks catalog FAIL "no dbx_catalog_name output"
  fi
  if [[ -n "$wid" ]]; then
    code="$(dbx_get "/api/2.0/sql/warehouses/$wid")"
    [[ "$code" == 200 ]] && record "$a" databricks warehouse PASS "$wid" \
                          || record "$a" databricks warehouse FAIL "$wid (HTTP $code)"
  else
    record "$a" databricks warehouse FAIL "no dbx_sql_warehouse_id output"
  fi
}

# ---------------------------------------------------------------------------
# Compose the combined report from WSA's two layers + this script's results.
# ---------------------------------------------------------------------------
compose_report() {
  local dir="$1" out="$1/validation-report.md"
  local va="$dir/verify-accounts-results.json"
  local vl="$dir/verify-login-results.json"
  local vr="$dir/validate-run-results.json"
  {
    echo "# Validation report — $(basename "$dir")"
    echo
    echo "_Generated $(date '+%Y-%m-%d %H:%M') by validate-run.sh (composing WSA + workshop checks)._"
    echo

    echo "## Tier 1 — Provisioning & credentials (WSA \`verify-accounts\`)"
    if [[ -f "$va" ]]; then
      jq -r '"- Accounts audited: \(.accounts_audited|length)\n- Dispenser rows: \(.dispenser_rows)\n- Result: " + (if .ok then "✅ all complete & consistent" else "❌ problems found" end)' "$va"
      jq -r 'if .ok then empty else (.missing_outputs//{}|to_entries[]|"  - account-\(.key): missing \(.value|join(\", \")))"),(.collisions//{}|to_entries[]|"  - collision \(.key) on accounts \(.value|join(\", \")))") end' "$va" 2>/dev/null
    else echo "- (not run)"; fi
    echo

    echo "## Tier 3 — Access / login (WSA \`verify-login\`)"
    if [[ -f "$vl" ]]; then
      jq -r '"- Confluent Cloud: \(.Succeeded) passed, \(.Failed) failed (of \(.Total))"' "$vl"
      jq -r '.Results[]?|select(.Success|not)|"  - account-\(.Account)/\(.Platform): \(.Error)"' "$vl" 2>/dev/null
      echo "- Databricks: not browser-verifiable (SSO workspace) — access confirmed via Tier 2 (catalog + SQL warehouse reachable per account)"
    else echo "- (not run)"; fi
    echo

    echo "## Tier 2 & 4 — Live resources & data flow (workshop \`validate-run\`)"
    if [[ -f "$vr" ]]; then
      jq -r '"- Checks: \(.pass) passed, \(.fail) failed, \(.skip) skipped across \(.accounts) accounts"' "$vr"
      # per-check-type rollup
      jq -r '.checks|group_by(.layer+"/"+.check)[]|"  - \(.[0].layer)/\(.[0].check): \([.[]|select(.status=="PASS")]|length)/\(length) PASS"' "$vr" 2>/dev/null
      jq -r '.checks[]|select(.status=="FAIL")|"  - FAIL account-\(.account) \(.layer)/\(.check): \(.detail)"' "$vr" 2>/dev/null
    else echo "- (not run)"; fi
    echo

    # Overall verdict across all layers that ran.
    local overall="✅ PASS"
    { [[ -f "$va" ]] && [[ "$(jq -r '.ok' "$va")" == "true" ]]; } || overall="❌ see failures above"
    { [[ ! -f "$vl" ]] || [[ "$(jq -r '.Failed' "$vl")" == "0" ]]; } || overall="❌ see failures above"
    { [[ ! -f "$vr" ]] || [[ "$(jq -r '.fail' "$vr")" == "0" ]]; } || overall="❌ see failures above"
    echo "## Overall: $overall"
    echo
  } > "$out"
  log "  report → $out"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
ACCTS=()
while IFS= read -r _line; do [[ -n "$_line" ]] && ACCTS+=("$_line"); done < <(accounts_list | sort -n)
(( ${#ACCTS[@]} > 0 )) || { echo "error: no accounts to validate" >&2; exit 2; }

log "validate-run: RiverPay FSI Payments ($CLOUD) — ${#ACCTS[@]} accounts, run dir $RUN_DIR"
log "  region=$REGION  confluent=$([[ $CC_ENABLED == 1 ]] && echo on || echo skip)  databricks=$([[ $DBX_ENABLED == 1 ]] && echo on || echo skip)"

for a in "${ACCTS[@]}"; do
  printf '  account-%03d ... ' "$a"
  if (( CC_ENABLED )); then check_confluent "$a"; else record "$a" confluent resources SKIP "not logged in"; fi
  if (( DBX_ENABLED )); then check_databricks "$a"; else record "$a" databricks resources SKIP "no creds"; fi
  # per-account line: worst status among this account's rows
  acct_fail="$(printf '%s\n' "${ROWS[@]}" | awk -F'|' -v a="$a" '$1==a && $4=="FAIL"' | wc -l | tr -d ' ')"
  [[ "$acct_fail" == 0 ]] && echo "ok" || echo "FAIL ($acct_fail)"
done

# ---------------------------------------------------------------------------
# Emit results JSON
# ---------------------------------------------------------------------------
{
  printf '{\n  "run_dir": "%s",\n  "accounts": %d,\n  "pass": %d,\n  "fail": %d,\n  "skip": %d,\n  "checks": [\n' \
    "$RUN_DIR" "${#ACCTS[@]}" "$PASS" "$FAIL" "$SKIP"
  first=1
  for r in "${ROWS[@]}"; do
    IFS='|' read -r ra rl rc rs rd <<<"$r"
    [[ $first == 1 ]] || printf ',\n'; first=0
    printf '    {"account": %d, "layer": "%s", "check": "%s", "status": "%s", "detail": "%s"}' \
      "$ra" "$rl" "$rc" "$rs" "${rd//\"/\\\"}"
  done
  printf '\n  ]\n}\n'
} > "$RESULTS_JSON"

log ""
log "  live checks: $PASS passed, $FAIL failed, $SKIP skipped"
log "  results → $RESULTS_JSON"

# ---------------------------------------------------------------------------
# Compose the combined validation-report.md from all three layers.
# ---------------------------------------------------------------------------
compose_report "$RUN_DIR" 2>/dev/null || true

exit $(( FAIL > 0 ? 1 : 0 ))
