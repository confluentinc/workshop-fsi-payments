# ShadowTraffic — RiverPay generators

[`riverpay-generator.json`](riverpay-generator.json) defines:

1. **Stage 1** — seed ~100 rows into Postgres `riverpay.customer_profiles`
2. **Stage 2** — emit correlated payment lifecycle events to Kafka:
   - `payment_initiation` — new `PMT-*` events (customer_id via named lookup of `customer_profiles_seed`)
   - `payment_authorization` / `payment_balance_update` / `payment_status` — each **forks once** on the initiation value (`oneTimeKeys` + `maxEvents: 1`) so the same `payment_id` appears on all four topics

Do **not** put per-state `avroSchemaHint`s inside a single `stateMachine` that switches Kafka topics — ShadowTraffic deep-merges those hints and Avro serialization fails.

Connections are injected at deploy time by Terraform (`terraform/aws-demo/shadowtraffic.tf`) from live Postgres + Confluent credentials. The ShadowTraffic free-trial license is fetched automatically via HTTP. Do not commit secrets into this folder.

## Local dry-run

Uses `--stdout --sample` so nothing is written to Kafka/Postgres (stub connections in [`connections-local.json`](connections-local.json)).

```sh
cd shadowtraffic

# Free-trial license (same URL Terraform uses)
curl -fsSL \
  https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env \
  -o /tmp/shadow-traffic-license.env

# Merge generator + local stub connections
jq -s '.[0] * {connections: .[1]}' \
  riverpay-generator.json connections-local.json \
  > /tmp/riverpay-config.json

# Cap volume for a fast sample (seed 5 profiles, 5 initiations; skip ongoing profiles)
jq '
  .schedule.stages[0].overrides = {
    customer_profiles_seed: { localConfigs: { maxEvents: 5, throttleMs: 0 } }
  }
  | .schedule.stages[1].generators = [
      "payment_initiation",
      "payment_authorization",
      "payment_balance_update",
      "payment_status"
    ]
  | .schedule.stages[1].overrides = {
      payment_initiation: { localConfigs: { maxEvents: 5, throttleMs: 0 } }
    }
' /tmp/riverpay-config.json > /tmp/riverpay-config-sample.json

docker run --rm \
  --env-file /tmp/shadow-traffic-license.env \
  -v /tmp/riverpay-config-sample.json:/home/config.json:ro \
  shadowtraffic/shadowtraffic:latest \
  --config /home/config.json \
  --stdout --sample 40
```

**Expected:** Postgres seed rows, then initiation / authorization / balance_update / status events sharing the same `payment_id` values (e.g. `PMT-202607110000` on all four topics).

### Automated checks

```sh
./test_local.sh
```

Runs config validation, JSON + Avro `--stdout` samples (two seeds), full lifecycle correlation assertions, and a seed-determinism check.

See [ShadowTraffic docs](https://docs.shadowtraffic.io/overview/) — especially [fork on lookup](https://docs.shadowtraffic.io/fork/key/#forking-on-a-lookup) and [`oneTimeKeys`](https://docs.shadowtraffic.io/fork/oneTimeKeys/).
