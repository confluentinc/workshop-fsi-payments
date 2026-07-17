# FSI Real-Time Payments Workshop — Phase 1 Runbook

*Purpose: conceptual build-and-run guide aligned with the demo-mode Terraform product. For hands-on steps, use `labs/demo/`.*

## Phase 1 scope

* Storyline: happy path only.
* Narrative: RiverPay instant-payments (maps to FedNow/RTP-style flows).
* `risk_score`: operational exception probability, with a `risk_reason`.
* Payload: flattened records over Avro + Schema Registry (ISO 20022 nesting is Phase 2).
* Security: light PII in the profile + brief CSFLE talking point.
* Flink data products:
  * `riverflow_payments` — 4-way inner join (completed only) → Tableflow **append**
  * `riverflow_payments_risk_score` — temporal join initiation × profile → Tableflow **upsert**
* Progressive / stall-aware payment state: **Phase 2 backlog** (progressive upsert deferred).
* Topics: lifecycle-specific Kafka sources; single-currency (USD).
* Delivery: demo mode (AWS) via `terraform/aws-demo`.

## Formalized names

| Resource | Name |
|----------|------|
| Postgres table | `riverpay.customer_profiles` |
| CDC topic | `riverflow.riverpay.customer_profiles` |
| Initiation | `riverflow.payments.initiation` |
| Authorization | `riverflow.payments.authorization` |
| Balance update | `riverflow.payments.balance_update` |
| Status | `riverflow.payments.status` |
| Completed payments MT | `riverflow_payments` |
| Risk MT | `riverflow_payments_risk_score` |
| Genie views | `riverpulse_high_risk_payments`, `riverpulse_customer_risk_7d`, `riverpulse_lifecycle_completion` |

## Prerequisites

* Confluent Cloud org access + cloud API key
* AWS account (EC2, S3, VPC, IAM)
* Databricks workspace + service principal OAuth
* Docker Desktop + Git (see LAB0)
* Network access from Terraform to fetch the ShadowTraffic free-trial license (automatic at apply)

## Data model

**Customer profile (Postgres → CDC):** `customer_id`, `partner_bank_id`, `segment`, `account_tier`, `home_currency`, `country`, light PII (`full_name`, `tax_id`, `date_of_birth`), `created_at`, `updated_at`.

**Payment initiation (Kafka):** `payment_id`, `customer_id`, `source_account`, `destination_account`, `amount`, `currency`, `payment_type`, `channel`, `initiated_at`, `status`.

**Completed payments (`riverflow_payments`):** merged fields from all four lifecycle stages for payments that completed the happy path.

**Derived risk (`riverflow_payments_risk_score`):** `payment_id`, `customer_id`, `segment`, `account_tier`, `amount`, `currency`, `payment_type`, `initiated_at`, `risk_score`, `risk_reason`, `enrichment_timestamp`.

## Build steps (demo automation)

Executable path: LAB0 → LAB1 → LAB2 (`terraform apply`) → LAB3 → LAB4.

### Step 1 — Seed source data

ShadowTraffic stage 1 inserts ~100 profiles into `riverpay.customer_profiles`.

**Expected result:** ~100 profiles present in Postgres.

### Step 2 — Configure CDC into Kafka

Terraform creates Postgres CDC Source V2 → `riverflow.riverpay.customer_profiles`.

**Expected result:** Customer profile changes land in Kafka in near-real time.

### Step 3 — Create payment lifecycle topics

Terraform creates the four RiverFlow Kafka source topics.

**Expected result:** All lifecycle topics exist.

### Step 4 — Generate payment events

ShadowTraffic stage 2 emits initiation → authorization → balance update → status with correlated `payment_id` / `customer_id`.

**Expected result:** Events flow across all lifecycle topics.

### Step 5 — Flink data products

1. Configure watermarks/changelog modes on sources.
2. Create `riverflow_payments` (4-way inner join — emits only when all stages match).
3. Create `riverflow_payments_risk_score` (temporal join + risk heuristics).

Reference SQL: `flink/risk_score.sql`.

**Expected result:** Completed payments and risk rows populate.

### Step 6 — Tableflow serving

Terraform enables Tableflow (Delta) on **`riverflow_payments`** (append) and **`riverflow_payments_risk_score`** (upsert), plus Unity Catalog integration. Raw lifecycle topics are not Tableflow-enabled.

**Expected result:** Both data products visible in the Databricks workshop catalog.

### Step 7 — Downstream consumption

Terraform creates RiverPulse views; LAB3 uses Genie prompts from `sql/genie_prompts.md`.

Completion rate Phase 1 proxy: `completed` (`riverflow_payments`) / `initiated_enriched` (`riverflow_payments_risk_score`). Stall drill-down is backlog.

**Expected result:** Genie answers all three demo questions (with Phase 1 completion caveat).

## Validation checklist (run before every workshop)

- [ ] Postgres profiles present and CDC connector healthy
- [ ] All four lifecycle topics receiving events
- [ ] Flink `riverflow_payments` and `riverflow_payments_risk_score` populated
- [ ] Tableflow tables for both products visible in Unity Catalog
- [ ] Genie (or SQL views) answers the three demo questions
- [ ] Generation rate set to demo-friendly speed

## Teardown / reset

Use LAB4: `terraform destroy` in `terraform/aws-demo`. Optionally stop ShadowTraffic on EC2 first.

## Troubleshooting

See `labs/shared/troubleshooting.md`.

## Phase 2 backlog (not in this runbook)

* Progressive / stall-aware payment state (in-flight stage drill-down); progressive upsert deferred from Phase 1.
* Insufficient-funds and/or fraud branch
* ISO 20022-inspired nested payload
* `MATCH_RECOGNIZE` pattern detection
* Foreign-exchange / cross-currency lookup
* Materialized tables and Tableflow Data TTL deep dive
* Full CSFLE walkthrough
* Evaluate Kafka Lightning Tables
* Validate on Confluent Platform / Private Cloud
* Self-service and instructor-led delivery modes; Azure parity
