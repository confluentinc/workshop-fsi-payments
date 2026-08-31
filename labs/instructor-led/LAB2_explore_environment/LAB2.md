# LAB 2: Explore Your Environment

**Previous:** [LAB 1: Claim Your Account](../LAB1_claim_account/LAB1.md)

## Overview

Tour the RiverPay pipeline that is already ingesting data: Postgres CDC (profiles + FX rates), RiverFlow lifecycle topics, Flink compute pool, and the pre-registered risk UDF connection.

### What you'll accomplish

1. Inspect CDC topics for customer profiles and FX rates
2. Inspect RiverFlow payment lifecycle topics
3. Confirm Flink compute pool and `lookup_operational_risk` availability

### Prerequisites

Completed **[LAB 1](../LAB1_claim_account/LAB1.md)**.

## Steps

### Step 1: Kafka topics (Confluent Cloud)

In [Confluent Cloud](https://confluent.cloud/environments): your environment → cluster → **Topics**, confirm messages on:

| Topic | Role |
|-------|------|
| `riverflow.riverpay.customer_profiles` | CDC profiles (upsert) |
| `riverflow.riverpay.fx_rates` | CDC FX rates (upsert ~5s) |
| `riverflow.payments.initiation` | Payment lifecycle stage 1 |
| `riverflow.payments.authorization` | Stage 2 |
| `riverflow.payments.balance_update` | Stage 3 |
| `riverflow.payments.status` | Stage 4 |

### Step 2: Connectors

The Postgres CDC source connector is **pre-provisioned**. Open **Connectors** and confirm it is **Running** with table include list covering `riverpay.customer_profiles` and `riverpay.fx_rates`.

<img src="./assets/lab2_step2.png" alt="Postgres CDC connector running in Confluent Cloud" width="400">

### Step 3: Flink compute pool

1. Open **Flink** → **Compute pools**. Pick the workshop pool, **not** the default one. It is named `<participant_id>_flink_compute_pool_<id>` — for example `wp001-tf-db_flink_compute_pool_16255802`, where `wp001` is your participant prefix.
2. Open its **SQL workspace**
3. Set catalog = your environment, database = your Kafka cluster
4. Run:

    ```sql
    SHOW USER FUNCTIONS;
    -- Expect lookup_operational_risk when operators pre-registered the UDF
    ```

    <img src="./assets/lab2_step3_2.png" alt="SHOW USER FUNCTIONS result showing lookup_operational_risk" width="550">

    ```sql
    SHOW CONNECTIONS LIKE 'riverpay%';
    -- Expect riverpay_risk_api (HTTPS shared Risk Scoring API)
    ```

    <img src="./assets/lab2_step3_3.png" alt="SHOW CONNECTIONS result showing riverpay_risk_api" width="550">

> [!TIP]
> **Plain `SHOW FUNCTIONS;`**
>
> This lists every built-in function too (hundreds of rows, including operators like `%` and `<=`). `SHOW USER FUNCTIONS;` restricts the output to user-defined functions in the current catalog and database, so the workshop UDF is the only thing you see. For details on one function:
>
> ```sql
> DESCRIBE FUNCTION EXTENDED lookup_operational_risk;
> -- Shows kind, argument types, return type, and signature
> ```

`lookup_operational_risk` calls the shared Risk Scoring API. Given an amount, customer segment, and account tier, it returns a single `score|reason` string:

- **score** — an **operational exception probability** from `0.0` (routine) to `1.0` (near-certain exception): how likely the payment is to need manual review. It is *not* a fraud score. Downstream, `>= 0.5` counts as high risk.
- **reason** — a short, human-readable explanation of that score.

In **LAB 3** you'll call this UDF from Flink SQL to build the `riverflow_payments_risk_score` data product.

Test the function by running:

```sql
SELECT lookup_operational_risk(3600, 'retail', 'standard');
-- Expect a string like: 0.42|High amount for retail standard tier
```

<img src="./assets/lab2_step3_4.png" alt="SELECT lookup_operational_risk result" width="550">

> [!NOTE]
> **Cold UDF Latency:**
>
> The first `lookup_operational_risk(...)` call can take up to ~1 minute (Flink compute warm-up + HTTPS to the shared Risk API). Re-runs are usually much faster. If it hangs past ~2 minutes, check `SHOW CONNECTIONS` again or ask the instructor.
>
> Soft-fail payloads use score `0.28` with a reason prefix — not a real API score:
> `risk_api_endpoint_missing`, `risk_api_http_<code>`, or `risk_api_error` (timeout / network). Healthy low-risk looks like `0.28|routine_instant_credit_transfer`.
>
> **If you see a soft-fail** (`risk_api_error` / `risk_api_http_*`): re-run the same `SELECT` once or twice. Occasional Flink→Risk API blips are expected; a successful retry returns a readable score such as `0.85|amount_significantly_above_customer_baseline`.


#### Checkpoint

- [ ] CDC + lifecycle topics have data
- [ ] CDC connector healthy
- [ ] Flink pool opens; risk connection/UDF visible (or instructor confirms pre-reg status)

## Conclusion

Sources are live. Next you build the Flink data products yourself.

## What's next

**[LAB 3: Stream Processing](../LAB3_stream_processing/LAB3.md)**
