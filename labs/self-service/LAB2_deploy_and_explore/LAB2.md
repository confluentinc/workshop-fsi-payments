# LAB 2: Deploy & Explore

**Previous:** [LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)

## Overview

Apply Terraform to provision RiverPay infra, then tour CDC, lifecycle topics, and the pre-registered risk UDF — the same explore shape as instructor-led LAB2, after a BYO deploy.

### What Terraform creates (self-service defaults)

| Layer | Created | Not created (you do later) |
|-------|---------|----------------------------|
| Cloud + Postgres + ShadowTraffic | Yes | — |
| Confluent Kafka, Flink pool, CDC, topics | Yes | — |
| Risk API + Flink CONNECTION / UDF | Yes | — |
| Flink MTs `riverflow_payments` / risk | — | **LAB 3** |
| Tableflow on those products | — | **LAB 4** |
| RiverPulse Genie views | After Tableflow | **LAB 5** (SQL views optional) |

### Prerequisites

**[LAB 1](../LAB1_account_setup/LAB1.md)** with a filled `terraform.tfvars`.

## Steps

### Step 1: Apply

**AWS:**

```sh
cd terraform/aws
docker-compose run --rm terraform -c "terraform init"
docker-compose run --rm terraform -c "terraform apply -auto-approve"
```

**Azure:**

```sh
cd terraform/azure
terraform init
terraform apply
```

> Cold start often **45–90+ minutes** (Postgres, CDC, IAM, Databricks). Use the wait to skim [`README.md`](../../../README.md) architecture and [`USECASE.md`](../../../USECASE.md).

### Step 2: Review outputs

**AWS:**

```sh
docker-compose run --rm terraform -c "terraform output workshop_summary"
docker-compose run --rm terraform -c "terraform output workshop_status"
```

**Azure:**

```sh
terraform output workshop_summary
terraform output risk_api_endpoint
terraform output datagen_public_ip
```

Confirm Risk API URL is `http://<datagen-ip>:8089`, and note Flink + Databricks links. On AWS, confirm `flink_mts_created` / Tableflow flags are false.

### Step 3: Explore Confluent Cloud

1. Open the Flink compute pool link from outputs
2. Confirm CDC topics have data:
   - `riverflow.riverpay.customer_profiles`
   - `riverflow.riverpay.fx_rates`
3. Confirm lifecycle topics:
   - `riverflow.payments.initiation` / `authorization` / `balance_update` / `status`
4. In Flink SQL:

```sql
SHOW USER FUNCTIONS;
-- Expect lookup_operational_risk (user-defined functions only, so no built-in noise)

SHOW CONNECTIONS LIKE 'riverpay%';
-- Expect riverpay_risk_api

SELECT lookup_operational_risk(12000, 'retail', 'standard');
-- Expect e.g. 0.85|amount_significantly_above_customer_baseline
-- First call can take ~1 minute (cold Flink + Risk API HTTPS/HTTP)
```

> Soft-fail payloads use `0.28|risk_api_*` (endpoint missing, HTTP status, or timeout/network) — not a real score. Healthy low-risk is `0.28|routine_instant_credit_transfer`.
>
> If you see a soft-fail, re-run the same `SELECT` once or twice — occasional Flink→Risk API blips are expected.

5. Confirm Flink MTs for completed payments / risk_score are **not** present yet (you create them in LAB 3)

### Step 4: Databricks orientation

Note catalog + schema from outputs. You will Genie against Tableflow tables after LAB 4–5.

## Checkpoint

- [ ] Apply succeeded
- [ ] CDC + lifecycle topics have traffic
- [ ] Risk UDF / CONNECTION work
- [ ] No auto-created completed-payments / risk MTs (unless you overrode flags)

## What's next

**[LAB 3: Stream processing](../LAB3_stream_processing/LAB3.md)**
