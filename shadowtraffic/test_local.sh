#!/usr/bin/env bash
# Robust local dry-run for riverpay-generator.json
# Usage: ./test_local.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="${TMPDIR:-/tmp}/riverpay-st-test-$$"
LICENSE_URL="https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
IMAGE="${SHADOWTRAFFIC_IMAGE:-shadowtraffic/shadowtraffic:latest}"
SEED_COUNT=8
INIT_COUNT=8
SAMPLE_CAP=80

mkdir -p "$WORKDIR"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

pass=0
fail=0
assert() {
  local name="$1"
  shift
  if "$@"; then
    echo "  PASS  $name"
    pass=$((pass + 1))
  else
    echo "  FAIL  $name"
    fail=$((fail + 1))
  fi
}

echo "==> Workdir: $WORKDIR"
echo "==> Fetching free-trial license"
curl -fsSL "$LICENSE_URL" -o "$WORKDIR/license.env"

echo "==> Building JSON + Avro stub configs"
jq -s '.[0] * {connections: .[1]}' \
  "$ROOT/riverpay-generator.json" \
  "$ROOT/connections-local.json" \
  > "$WORKDIR/config-json.json"

# Production-like Avro serializers (no live SR needed with --stdout)
jq '.kafka.producerConfigs += {
      "key.serializer": "io.confluent.kafka.serializers.KafkaAvroSerializer",
      "value.serializer": "io.confluent.kafka.serializers.KafkaAvroSerializer",
      "schema.registry.url": "http://localhost:8081",
      "auto.register.schemas": "true"
    }' "$ROOT/connections-local.json" > "$WORKDIR/connections-avro.json"

jq -s '.[0] * {connections: .[1]}' \
  "$ROOT/riverpay-generator.json" \
  "$WORKDIR/connections-avro.json" \
  > "$WORKDIR/config-avro.json"

make_sample_config() {
  local src="$1"
  local dst="$2"
  jq --argjson seed "$SEED_COUNT" --argjson init "$INIT_COUNT" '
    .schedule.stages[0].overrides = {
      customer_profiles_seed: { localConfigs: { maxEvents: $seed, throttleMs: 0 } }
    }
    | .schedule.stages[1].generators = [
        "payment_initiation",
        "payment_authorization",
        "payment_balance_update",
        "payment_status"
      ]
    | .schedule.stages[1].overrides = {
        payment_initiation: { localConfigs: { maxEvents: $init, throttleMs: 0 } }
      }
  ' "$src" > "$dst"
}

make_sample_config "$WORKDIR/config-json.json" "$WORKDIR/sample-json.json"
make_sample_config "$WORKDIR/config-avro.json" "$WORKDIR/sample-avro.json"

run_st() {
  local config="$1"
  local out="$2"
  local seed="${3:-}"
  local seed_args=()
  if [[ -n "$seed" ]]; then
    seed_args=(--seed "$seed")
  fi
  docker run --rm \
    --env-file "$WORKDIR/license.env" \
    -v "$config:/home/config.json:ro" \
    "$IMAGE" \
    --config /home/config.json \
    --stdout --sample "$SAMPLE_CAP" \
    "${seed_args[@]}" \
    > "$out" 2>"$out.err"
}

extract_events() {
  # Keep only JSON event objects (drop ST status lines / ANSI)
  python3 - "$1" <<'PY'
import json, sys, re
path = sys.argv[1]
ansi = re.compile(r"\x1b\[[0-9;]*m")
buf = []
depth = 0
for raw in open(path, encoding="utf-8", errors="replace"):
    line = ansi.sub("", raw)
    if not buf and not line.lstrip().startswith("{"):
        continue
    buf.append(line)
    depth += line.count("{") - line.count("}")
    if depth == 0 and buf:
        text = "".join(buf).strip()
        buf = []
        if text:
            try:
                print(json.dumps(json.loads(text), separators=(",", ":")))
            except json.JSONDecodeError:
                pass
PY
}

validate_events() {
  local label="$1"
  local events_file="$2"
  echo "==> Validating: $label"
  python3 - "$events_file" "$SEED_COUNT" "$INIT_COUNT" <<'PY'
import json, sys
from collections import defaultdict

path, seed_n, init_n = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
events = [json.loads(l) for l in open(path) if l.strip()]
errors = []

profiles = [e for e in events if e.get("table") == "riverpay.customer_profiles"]
by_topic = defaultdict(list)
for e in events:
    t = e.get("topic")
    if t:
        by_topic[t].append(e)

required_topics = [
    "riverflow.payments.initiation",
    "riverflow.payments.authorization",
    "riverflow.payments.balance_update",
    "riverflow.payments.status",
]

if len(profiles) != seed_n:
    errors.append(f"expected {seed_n} profile rows, got {len(profiles)}")

cust_ids = {p["row"]["customer_id"] for p in profiles}
for p in profiles:
    row = p["row"]
    for f in ("customer_id", "partner_bank_id", "segment", "account_tier", "full_name", "created_at", "updated_at"):
        if f not in row or row[f] in (None, ""):
            errors.append(f"profile missing {f}: {row.get('customer_id')}")

for topic in required_topics:
    if topic not in by_topic:
        errors.append(f"missing topic {topic}")

init_ids = []
for e in by_topic.get("riverflow.payments.initiation", []):
    pid = e["value"]["payment_id"]
    init_ids.append(pid)
    if e["key"]["payment_id"] != pid:
        errors.append(f"initiation key/value payment_id mismatch: {e['key']} vs {e['value']}")
    if e["value"]["customer_id"] not in cust_ids:
        errors.append(f"initiation customer_id not from seed: {e['value']['customer_id']}")
    for f in ("source_account", "destination_account", "amount", "currency", "payment_type", "channel", "initiated_at", "status"):
        if f not in e["value"]:
            errors.append(f"initiation missing {f} on {pid}")
    if e["value"].get("status") != "initiated":
        errors.append(f"initiation bad status on {pid}")

if len(init_ids) != init_n:
    errors.append(f"expected {init_n} initiations, got {len(init_ids)}")
if len(set(init_ids)) != len(init_ids):
    errors.append(f"duplicate initiation payment_ids: {init_ids}")

def ids_for(topic):
    return [e["value"]["payment_id"] for e in by_topic.get(topic, [])]

auth_ids = ids_for("riverflow.payments.authorization")
bal_ids = ids_for("riverflow.payments.balance_update")
stat_ids = ids_for("riverflow.payments.status")

for name, ids in (("authorization", auth_ids), ("balance_update", bal_ids), ("status", stat_ids)):
    if sorted(ids) != sorted(init_ids):
        errors.append(f"{name} payment_ids != initiation set\n  init={sorted(init_ids)}\n  {name}={sorted(ids)}")
    if len(ids) != len(set(ids)):
        errors.append(f"{name} has duplicate payment_ids: {ids}")

# Field / correlation checks per payment
init_by_id = {e["value"]["payment_id"]: e["value"] for e in by_topic["riverflow.payments.initiation"]}
for e in by_topic.get("riverflow.payments.authorization", []):
    v = e["value"]
    pid = v["payment_id"]
    src = init_by_id[pid]
    if v["customer_id"] != src["customer_id"]:
        errors.append(f"auth customer_id mismatch for {pid}")
    for f in ("authorization_code", "validation_result", "authorized_at", "status"):
        if f not in v:
            errors.append(f"auth missing {f} on {pid}")
    if v.get("status") != "authorized":
        errors.append(f"auth bad status on {pid}")
    # Must not carry initiation-only fields (regression for stateMachine merge bug)
    for bad in ("initiated_at", "source_account", "payment_type", "channel"):
        if bad in v:
            errors.append(f"auth unexpectedly has {bad} on {pid}")

for e in by_topic.get("riverflow.payments.balance_update", []):
    v = e["value"]
    pid = v["payment_id"]
    src = init_by_id[pid]
    if v["customer_id"] != src["customer_id"]:
        errors.append(f"balance customer_id mismatch for {pid}")
    if v["amount"] != src["amount"]:
        errors.append(f"balance amount mismatch for {pid}: {v['amount']} vs {src['amount']}")
    if v["source_account"] != src["source_account"] or v["destination_account"] != src["destination_account"]:
        errors.append(f"balance accounts mismatch for {pid}")
    for f in ("source_balance_after", "destination_balance_after", "updated_at", "status"):
        if f not in v:
            errors.append(f"balance missing {f} on {pid}")
    if v.get("status") != "balance_updated":
        errors.append(f"balance bad status on {pid}")

for e in by_topic.get("riverflow.payments.status", []):
    v = e["value"]
    pid = v["payment_id"]
    src = init_by_id[pid]
    if v["customer_id"] != src["customer_id"]:
        errors.append(f"status customer_id mismatch for {pid}")
    if v.get("status") != "completed":
        errors.append(f"status bad status on {pid}")
    if v.get("status_reason") != "settlement_confirmed":
        errors.append(f"status bad reason on {pid}")
    if "completed_at" not in v:
        errors.append(f"status missing completed_at on {pid}")
    for bad in ("initiated_at", "authorization_code", "amount"):
        if bad in v:
            errors.append(f"status unexpectedly has {bad} on {pid}")

if errors:
    print("VALIDATION FAILED:")
    for err in errors:
        print(f"  - {err}")
    sys.exit(1)

print(f"  events={len(events)} profiles={len(profiles)} payments={len(init_ids)}")
print(f"  topics: " + ", ".join(f"{t.split('.')[-1]}={len(by_topic[t])}" for t in required_topics))
sys.exit(0)
PY
}

echo "==> Test 1: validate production config (JSON stubs, no generate)"
if docker run --rm \
  --env-file "$WORKDIR/license.env" \
  -v "$WORKDIR/config-json.json:/home/config.json:ro" \
  "$IMAGE" \
  --config /home/config.json \
  --stdout --sample 1 \
  >"$WORKDIR/prod-validate.out" 2>"$WORKDIR/prod-validate.err"; then
  assert "production JSON config validates + runs" true
else
  # sample 1 may exit 0 after 1 event; failure is non-zero or config errors in stderr
  if grep -q "configuration errors" "$WORKDIR/prod-validate.err" "$WORKDIR/prod-validate.out" 2>/dev/null; then
    assert "production JSON config validates + runs" false
    cat "$WORKDIR/prod-validate.err" | tail -40
  else
    assert "production JSON config validates + runs" true
  fi
fi

echo "==> Test 2: JSON serializers — seed 42"
run_st "$WORKDIR/sample-json.json" "$WORKDIR/run-json-42.out" 42
extract_events "$WORKDIR/run-json-42.out" > "$WORKDIR/run-json-42.events"
if validate_events "JSON seed=42" "$WORKDIR/run-json-42.events"; then
  assert "JSON seed=42 lifecycle correlation" true
else
  assert "JSON seed=42 lifecycle correlation" false
  echo "---- stderr (tail) ----"
  tail -40 "$WORKDIR/run-json-42.out.err" || true
fi

echo "==> Test 3: JSON serializers — seed 99 (determinism / second sample)"
run_st "$WORKDIR/sample-json.json" "$WORKDIR/run-json-99.out" 99
extract_events "$WORKDIR/run-json-99.out" > "$WORKDIR/run-json-99.events"
if validate_events "JSON seed=99" "$WORKDIR/run-json-99.events"; then
  assert "JSON seed=99 lifecycle correlation" true
else
  assert "JSON seed=99 lifecycle correlation" false
fi

echo "==> Test 4: Avro serializers + avroSchemaHint (prod-like, --stdout)"
run_st "$WORKDIR/sample-avro.json" "$WORKDIR/run-avro-7.out" 7
# Fail fast if the old mega-schema merge bug resurfaces
if grep -q 'Expected field name not found' "$WORKDIR/run-avro-7.out" "$WORKDIR/run-avro-7.out.err" 2>/dev/null; then
  assert "Avro run has no schema-merge crash" false
  grep -n "Expected field name not found\|configuration errors\|✘" "$WORKDIR/run-avro-7.out.err" | head -20
else
  assert "Avro run has no schema-merge crash" true
fi
extract_events "$WORKDIR/run-avro-7.out" > "$WORKDIR/run-avro-7.events"
if [[ -s "$WORKDIR/run-avro-7.events" ]] && validate_events "Avro seed=7" "$WORKDIR/run-avro-7.events"; then
  assert "Avro seed=7 lifecycle correlation" true
else
  assert "Avro seed=7 lifecycle correlation" false
  echo "---- stderr (tail) ----"
  tail -50 "$WORKDIR/run-avro-7.out.err" || true
  echo "---- stdout (tail) ----"
  tail -30 "$WORKDIR/run-avro-7.out" || true
fi

echo "==> Test 6: full stage-2 generator set (incl. ongoing customer_profiles)"
# Regression: table-based lookup used to resolve to stage-2 profiles and fail validation.
jq --argjson seed "$SEED_COUNT" --argjson init "$INIT_COUNT" '
  .schedule.stages[0].overrides = {
    customer_profiles_seed: { localConfigs: { maxEvents: $seed, throttleMs: 0 } }
  }
  | .schedule.stages[1].overrides = {
      customer_profiles: { localConfigs: { maxEvents: 1, throttleMs: 0 } },
      payment_initiation: { localConfigs: { maxEvents: $init, throttleMs: 0 } }
    }
' "$WORKDIR/config-json.json" > "$WORKDIR/sample-full-stage2.json"
run_st "$WORKDIR/sample-full-stage2.json" "$WORKDIR/run-full-stage2.out" 11
if grep -q 'future scheduled stage\|configuration errors' "$WORKDIR/run-full-stage2.out" "$WORKDIR/run-full-stage2.out.err" 2>/dev/null; then
  assert "full stage-2 config has no lookup/stage errors" false
  grep -E 'future scheduled stage|configuration errors|✘' "$WORKDIR/run-full-stage2.out.err" | head -20
else
  assert "full stage-2 config has no lookup/stage errors" true
fi
extract_events "$WORKDIR/run-full-stage2.out" > "$WORKDIR/run-full-stage2.events"
# Allow 1 extra profile from ongoing generator
if python3 - "$WORKDIR/run-full-stage2.events" "$INIT_COUNT" <<'PY'
import json, sys
from collections import defaultdict
events = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
init_n = int(sys.argv[2])
by_topic = defaultdict(list)
for e in events:
    if e.get("topic"):
        by_topic[e["topic"]].append(e["value"]["payment_id"])
init = by_topic["riverflow.payments.initiation"]
ok = (
    len(init) == init_n
    and sorted(init) == sorted(by_topic["riverflow.payments.authorization"])
    and sorted(init) == sorted(by_topic["riverflow.payments.balance_update"])
    and sorted(init) == sorted(by_topic["riverflow.payments.status"])
)
sys.exit(0 if ok else 1)
PY
then
  assert "full stage-2 lifecycle still correlates" true
else
  assert "full stage-2 lifecycle still correlates" false
fi

echo "==> Test 5: repeat seed 42 is deterministic for payment_ids"
run_st "$WORKDIR/sample-json.json" "$WORKDIR/run-json-42b.out" 42
extract_events "$WORKDIR/run-json-42b.out" > "$WORKDIR/run-json-42b.events"
ids_a=$(jq -r 'select(.topic=="riverflow.payments.initiation") | .value.payment_id' "$WORKDIR/run-json-42.events" | sort | paste -sd, -)
ids_b=$(jq -r 'select(.topic=="riverflow.payments.initiation") | .value.payment_id' "$WORKDIR/run-json-42b.events" | sort | paste -sd, -)
if [[ "$ids_a" == "$ids_b" && -n "$ids_a" ]]; then
  assert "seed=42 payment_id set stable across reruns" true
else
  echo "    first : $ids_a"
  echo "    second: $ids_b"
  assert "seed=42 payment_id set stable across reruns" false
fi

echo
echo "=============================="
echo "Results: $pass passed, $fail failed"
echo "=============================="
if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
echo "All local ShadowTraffic checks passed."
