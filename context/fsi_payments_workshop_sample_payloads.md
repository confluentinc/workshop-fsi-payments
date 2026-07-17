# FSI Real-Time Payments Workshop — Sample Payloads

Illustrative JSON payloads for every topic and table in the Phase 1 data
model (`fsi_payments_workshop_plan_v2.md` / `fsi_payments_workshop_phase1_runbook.md`),
using the RiverPay/RiverFlow narrative from `USECASE.md`. All examples follow
one payment end-to-end so the lifecycle and the Flink enrichment are easy to
trace. Happy path only, single currency (USD), flattened Avro records — consistent
with Phase 1 scope.

Topic/table names below are **formalized** in the runbook and `AGENTS.md`.

## Customer profile (Postgres → CDC)

Source table: `riverpay.customer_profiles` · CDC topic: `riverflow.riverpay.customer_profiles`

```json
{
  "customer_id": "CUST-100234",
  "partner_bank_id": "BANK-0417",
  "segment": "small_business",
  "account_tier": "premium",
  "home_currency": "USD",
  "country": "US",
  "full_name": "<CSFLE-encrypted>",
  "tax_id": "<CSFLE-encrypted>",
  "date_of_birth": "<CSFLE-encrypted>",
  "created_at": 1730538720000,
  "updated_at": 1720687275000
}
```

`created_at` / `updated_at` are epoch millis (`BIGINT`) to match ShadowTraffic
`_gen: now`. Flink temporal joins use Kafka `$rowtime` on the CDC topic, not
these columns as watermarks.

The `full_name`, `tax_id`, and `date_of_birth` fields are the light-PII
fields called out in the runbook — this is what they'd look like at rest
under CSFLE (ciphertext placeholder), which is the brief talking point, not
a full walkthrough. The CDC connector uses `after.state.only=true`, so Kafka
records are flat Avro payloads (no Debezium envelope) matching this shape.

## Payment lifecycle events

Same `payment_id` across all four lifecycle-specific topics, one event per
stage. `customer_id` ties every stage back to the profile above.

### 1. Initiation — `riverflow.payments.initiation`

```json
{
  "payment_id": "PMT-2026071100438291",
  "customer_id": "CUST-100234",
  "source_account": "ACC-88213340",
  "destination_account": "ACC-55019284",
  "amount": 482.50,
  "currency": "USD",
  "payment_type": "instant_credit_transfer",
  "channel": "mobile_app",
  "initiated_at": "2026-07-11T14:02:07.331Z",
  "status": "initiated"
}
```

### 2. Authorization — `riverflow.payments.authorization`

```json
{
  "payment_id": "PMT-2026071100438291",
  "customer_id": "CUST-100234",
  "authorization_code": "AUTH-7F3D9C",
  "validation_result": "passed",
  "authorized_at": "2026-07-11T14:02:08.114Z",
  "status": "authorized"
}
```

### 3. Balance update — `riverflow.payments.balance_update`

```json
{
  "payment_id": "PMT-2026071100438291",
  "customer_id": "CUST-100234",
  "source_account": "ACC-88213340",
  "destination_account": "ACC-55019284",
  "amount": 482.50,
  "currency": "USD",
  "source_balance_after": 3117.42,
  "destination_balance_after": 9820.10,
  "updated_at": "2026-07-11T14:02:08.980Z",
  "status": "balance_updated"
}
```

### 4. Status — `riverflow.payments.status`

```json
{
  "payment_id": "PMT-2026071100438291",
  "customer_id": "CUST-100234",
  "status": "completed",
  "status_reason": "settlement_confirmed",
  "completed_at": "2026-07-11T14:02:09.450Z"
}
```

### Completed payments — Flink 4-way inner join → `riverflow_payments` (append)

Emits **only** when initiation, authorization, balance update, and status all
match on `payment_id` (happy-path completed payments). Progressive / stall-aware
state is Phase 2 backlog.

```json
{
  "payment_id": "PMT-2026071100438291",
  "customer_id": "CUST-100234",
  "source_account": "ACC-88213340",
  "destination_account": "ACC-55019284",
  "amount": 482.50,
  "currency": "USD",
  "payment_type": "instant_credit_transfer",
  "channel": "mobile_app",
  "initiated_at": "2026-07-11T14:02:07.331Z",
  "authorization_code": "AUTH-7F3D9C",
  "authorized_at": "2026-07-11T14:02:08.114Z",
  "source_balance_after": 3117.42,
  "destination_balance_after": 9820.10,
  "balance_updated_at": "2026-07-11T14:02:08.980Z",
  "status": "completed",
  "status_reason": "settlement_confirmed",
  "completed_at": "2026-07-11T14:02:09.450Z"
}
```

## Derived risk output (Flink temporal join → Tableflow upsert)

Compacted / upsert table: `riverflow_payments_risk_score`. `risk_score`
is operational exception probability (0–1), not a fraud score — three
examples showing the range of `risk_reason` values:

```json
{
  "payment_id": "PMT-2026071100438291",
  "risk_score": 0.12,
  "risk_reason": "low_value_established_recipient",
  "enrichment_timestamp": "2026-07-11T14:02:10.002Z"
}
```

```json
{
  "payment_id": "PMT-2026071100438509",
  "risk_score": 0.61,
  "risk_reason": "first_transfer_to_new_destination_account",
  "enrichment_timestamp": "2026-07-11T14:03:44.117Z"
}
```

```json
{
  "payment_id": "PMT-2026071100439012",
  "risk_score": 0.83,
  "risk_reason": "amount_significantly_above_customer_baseline",
  "enrichment_timestamp": "2026-07-11T14:05:12.556Z"
}
```

## Tableflow-published tables (downstream / Databricks side)

Phase 1 Tableflow publishes **only** Flink data products:

**`riverflow_payments`** (append) — completed payments from the 4-way inner join.

**`riverflow_payments_risk_score`** (upsert) — one row per `payment_id` with latest risk state:

| payment_id | risk_score | risk_reason | enrichment_timestamp |
|---|---|---|---|
| PMT-2026071100438291 | 0.12 | low_value_established_recipient | 2026-07-11T14:02:10.002Z |
| PMT-2026071100438509 | 0.61 | first_transfer_to_new_destination_account | 2026-07-11T14:03:44.117Z |
| PMT-2026071100439012 | 0.83 | amount_significantly_above_customer_baseline | 2026-07-11T14:05:12.556Z |

RiverPulse Genie views: `riverpulse_high_risk_payments`,
`riverpulse_customer_risk_7d`, `riverpulse_lifecycle_completion`
(completion rate = completed / initiated_enriched; stall drill-down is Phase 2).
