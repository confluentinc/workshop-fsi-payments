# FSI Real-Time Payments Workshop — Phase 1 Runbook

*Purpose: conceptual build-and-run guide aligned with the demo-mode Terraform product. For hands-on steps, use `labs/demo/`.*

## Phase 1 scope

* Storyline: happy path only (failed-payment / DLQ → Phase 2).
* Narrative: RiverPay instant-payments (maps to FedNow/RTP-style flows).
* `risk_score`: operational exception probability, with a `risk_reason` (from shared risk UDF).
* Payload: flattened records over Avro + Schema Registry (ISO 20022 nesting is Phase 2).
* Security: light PII in the profile + brief CSFLE talking point; Tableflow **data TTL** for right-to-forget.
* Flink data products:
  * `riverflow_payments` — 4-way inner join (completed only) + FX rates temporal join → Tableflow **append**
  * `riverflow_payments_risk_score` — profile temporal join + external risk UDF → Tableflow **upsert**
* Progressive / stall-aware payment state: **Phase 2 backlog** (progressive upsert deferred).
* Topics: lifecycle-specific Kafka sources; profile + **FX rates** CDC; multi-currency (USD + GBP, AUD, CAD, JPY, EUR).
* Delivery:
  * **Demo:** `terraform/aws-demo` (+ Azure demo root as needed) — Flink/Tableflow automated.
  * **Instructor-led (Elevate):** Azure shared infra + per-attendee; Flink SQL and Tableflow are attendee work.

## Formalized names

| Resource | Name |
|----------|------|
| Postgres table (profiles) | `riverpay.customer_profiles` |
| Postgres table (FX) | `riverpay.fx_rates` |
| CDC topic (profiles) | `riverflow.riverpay.customer_profiles` |
| CDC topic (FX) | `riverflow.riverpay.fx_rates` |
| Initiation | `riverflow.payments.initiation` |
| Authorization | `riverflow.payments.authorization` |
| Balance update | `riverflow.payments.balance_update` |
| Status | `riverflow.payments.status` |
| Completed payments MT | `riverflow_payments` |
| Risk MT | `riverflow_payments_risk_score` |
| Genie views | `riverpulse_high_risk_payments`, `riverpulse_customer_risk_24h`, `riverpulse_lifecycle_completion` |
| Shared risk API | One workshop HTTPS URL; Flink `CONNECTION` + UDF pre-registered per env |

## Prerequisites

* Confluent Cloud org access + cloud API key
* AWS account (EC2, S3, VPC, IAM)
* Databricks workspace + service principal OAuth
* Docker Desktop + Git (see LAB0)
* Network access from Terraform to fetch the ShadowTraffic free-trial license (automatic at apply)

## Data model

**Customer profile (Postgres → CDC):** `customer_id`, `partner_bank_id`, `segment`, `account_tier`, `home_currency`, `country`, light PII (`full_name`, `tax_id`, `date_of_birth`), `created_at`, `updated_at`.

**Payment initiation (Kafka):** `payment_id`, `customer_id`, `source_account`, `destination_account`, `amount`, `currency` (USD, GBP, AUD, CAD, JPY, EUR), `payment_type`, `channel`, `initiated_at`, `status`.

**FX rates (Postgres → CDC):** `currency_code`, `rate_to_usd`, `updated_at`. ShadowTraffic upserts ~every 5 seconds; rates are realistic and often unchanged.

**Completed payments (`riverflow_payments`):** merged fields from all four lifecycle stages for payments that completed the happy path, plus FX enrichment (`rate_to_usd`, `amount_usd` or equivalent).

**Derived risk (`riverflow_payments_risk_score`):** `payment_id`, `customer_id`, `segment`, `account_tier`, `amount`, `currency`, `payment_type`, `initiated_at`, `risk_score`, `risk_reason`, `enrichment_timestamp` (UDF after profile TTJ).

## Build steps (demo automation)

Executable path: LAB0 → LAB1 → LAB2 (`terraform apply`) → LAB3 → LAB4.

### Step 1 — Seed source data

ShadowTraffic stage 1 inserts ~100 profiles into `riverpay.customer_profiles` and seeds `riverpay.fx_rates` (GBP, AUD, CAD, JPY, EUR).

**Expected result:** ~100 profiles and FX rate rows present in Postgres.

### Step 2 — Configure CDC into Kafka

Terraform creates Postgres CDC Source V2 → `riverflow.riverpay.customer_profiles` and `riverflow.riverpay.fx_rates` (upserts).

**Expected result:** Profile and FX rate changes land in Kafka in near-real time.

### Step 3 — Create payment lifecycle topics

Terraform creates the four RiverFlow Kafka source topics.

**Expected result:** All lifecycle topics exist.

### Step 4 — Generate payment events

ShadowTraffic stage 2 emits initiation → authorization → balance update → status with correlated `payment_id` / `customer_id`.

**Expected result:** Events flow across all lifecycle topics.

### Step 5 — Flink data products

1. Configure watermarks/changelog modes on sources (including FX rates).
2. Create `riverflow_payments` (4-way inner join — emits only when all stages match; FX temporal join for conversion).
3. Create `riverflow_payments_risk_score` (profile temporal join + external risk UDF).

In **demo** mode, Terraform creates these MTs. In **instructor-led** mode, attendees write the Flink SQL; CONNECTION + UDF are pre-registered against the shared risk API URL.

Reference SQL: `flink/` (risk + FX; update as patterns land).

**Expected result:** Completed payments (with USD-normalized amounts) and risk rows populate.

### Step 6 — Tableflow serving

**Demo:** Terraform enables Tableflow (Delta) on **`riverflow_payments`** (append) and **`riverflow_payments_risk_score`** (upsert), plus Unity Catalog integration and Tableflow data TTL for right-to-forget. **Instructor-led:** attendees enable Tableflow; TTL is a guided talking point. Raw lifecycle topics are not Tableflow-enabled.

**Expected result:** Both data products visible in the Databricks workshop catalog.

### Step 7 — Downstream consumption

Terraform creates RiverPulse views; LAB3 uses Genie prompts from `sql/genie_prompts.md`.

Completion rate Phase 1 proxy: `completed` (`riverflow_payments` — 4-way join + FX enrichment) / `initiated_enriched` (`riverflow_payments_risk_score`). Stall drill-down is backlog.

**Expected result:** Genie answers all three demo questions (with Phase 1 completion caveat).

## Validation checklist (run before every workshop)

- [ ] Postgres profiles and FX rates present; CDC connector(s) healthy
- [ ] All four lifecycle topics receiving events
- [ ] Shared risk API reachable; Flink CONNECTION + UDF registered (per env)
- [ ] Flink `riverflow_payments` and `riverflow_payments_risk_score` populated
- [ ] Tableflow tables for both products visible in Unity Catalog (TTL configured / discussed)
- [ ] Genie (or SQL views) answers the three demo questions
- [ ] Generation rate set to demo-friendly speed

## Teardown / reset

**Demo:** LAB4 — `terraform destroy` in `terraform/aws-demo`. Optionally stop ShadowTraffic first.
**Instructor-led:** see [`docs/operator-azure-elevate.md`](../docs/operator-azure-elevate.md) and `wsa clean` / per-env destroy, then shared destroy last.

## Troubleshooting

See `labs/shared/troubleshooting.md`.

## Phase 2 backlog (not in this runbook)

* Failed-payment paths, side-outputs, DLQ / invalid-schema fan-out
* Progressive / stall-aware payment state (in-flight stage drill-down); progressive upsert deferred from Phase 1
* Insufficient-funds and/or fraud branch
* ISO 20022-inspired nested payload
* `MATCH_RECOGNIZE` pattern detection (skipped for Elevate)
* Full CSFLE walkthrough
* Evaluate Kafka Lightning Tables
* Validate on Confluent Platform / Private Cloud beyond `cp-rosa` lite
