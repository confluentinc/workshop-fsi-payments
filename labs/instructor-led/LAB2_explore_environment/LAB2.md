# LAB 2: Explore Your Environment

## Overview

Tour the RiverPay pipeline that is already ingesting data: Postgres CDC (profiles + FX rates), RiverFlow lifecycle topics, Flink compute pool, and the pre-registered risk UDF connection.

### What you'll accomplish

1. Inspect CDC topics for customer profiles and FX rates
2. Inspect RiverFlow payment lifecycle topics
3. Confirm Flink compute pool and `lookup_operational_risk` availability
4. Note Databricks catalog/schema for later labs

### Prerequisites

Completed **[LAB 1](../LAB1_claim_account/LAB1.md)**.

## Steps

### Step 1: Kafka topics (Confluent Cloud)

In your environment → cluster → **Topics**, confirm messages on:

| Topic | Role |
|-------|------|
| `riverflow.riverpay.customer_profiles` | CDC profiles (upsert) |
| `riverflow.riverpay.fx_rates` | CDC FX rates (upsert ~5s) |
| `riverflow.payments.initiation` | Lifecycle stage 1 |
| `riverflow.payments.authorization` | Stage 2 |
| `riverflow.payments.balance_update` | Stage 3 |
| `riverflow.payments.status` | Stage 4 |

**Expected result:** Profiles seeded (~100), FX rows for USD/GBP/AUD/CAD/JPY/EUR, and ongoing payment events. Currencies include USD plus foreign currencies.

### Step 2: Connectors

Open **Connectors** and confirm the Postgres CDC source is **Running** with table include list covering `riverpay.customer_profiles` and `riverpay.fx_rates`.

### Step 3: Flink compute pool

1. Open **Flink** → your compute pool → **SQL workspace**
2. Set catalog = your environment, database = your Kafka cluster
3. Run:

```sql
SHOW FUNCTIONS;
-- Expect lookup_operational_risk when operators pre-registered the UDF

SHOW CONNECTIONS;
-- Expect riverpay_risk_api (HTTPS shared Risk Scoring API)
```

```sql
SELECT lookup_operational_risk(12000, 'retail', 'standard');
-- Expect a string like: 0.42|High amount for retail standard tier
```

> [!NOTE]
> You do **not** create infrastructure here. LAB 3 is where you write Flink SQL for the data products.

### Step 4: Databricks orientation

1. In Databricks, note your **catalog** and **schema** from the credentials email
2. Confirm a SQL warehouse is available (you will use Genie in LAB 5)

#### Checkpoint

- [ ] CDC + lifecycle topics have data
- [ ] CDC connector healthy
- [ ] Flink pool opens; risk connection/UDF visible (or instructor confirms pre-reg status)

## Conclusion

Sources are live. Next you build the Flink data products yourself.

## What's next

**[LAB 3: Stream Processing](../LAB3_stream_processing/LAB3.md)**
