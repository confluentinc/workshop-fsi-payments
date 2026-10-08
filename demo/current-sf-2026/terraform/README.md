# Terraform note — point the generator at the demo Flink cluster

**Goal:** stream the RiverPay data into the env Video 3 records on (Julian's **us-central-dev**
CMF env, or a CP/CC cluster its Catalog can read), so Confluent Assistant queries FSI data
instead of the stock `examples.marketplace` demo set.

The generator takes its Kafka/Postgres connection from Terraform at deploy time
(see [`../../../shadowtraffic/README.md`](../../../shadowtraffic/README.md)) — so this is a
**connection-target** change, not a generator-code change.

## Options

1. **CC cluster (fastest).** Kyle already has Terraform that spins up a Confluent Cloud cluster +
   runs the generator (Java client). Point the CMF env's Catalog at that cluster's topics.
   - TODO: confirm CMF can add a Catalog pointing at the CC cluster (Julian/Robert).
2. **CP cluster (truest to the on-prem story).** Deploy a CP Kafka the CMF env reads directly.
   - TODO: Kyle hasn't run the generator against CP yet — add a CP bootstrap + credentials target.
   - Reuse `../../../terraform/modules/` where possible; keep any CP target additive here.

## TODOs (fill in from the env handoff)

- [ ] Target Kafka bootstrap + auth (CC or CP) for the ShadowTraffic connection injection.
- [ ] Postgres target for `customer_profiles` (CDC) + `fx_rates`, or skip CDC and seed topics directly.
- [ ] Confirm with Robert/Julian how the CMF env registers the Catalog/topics so Chatbook can query them.
- [ ] Send Julian/Robert the data-shape summary + `assets/architecture.png`.
