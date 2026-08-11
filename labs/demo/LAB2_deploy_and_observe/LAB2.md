# LAB 2: Deploy and Observe

**Previous:** [LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)

## Overview

A single `terraform apply` provisions the RiverPay pipeline: AWS + Postgres + ShadowTraffic, Confluent Cloud (CDC for profiles **and FX rates**, lifecycle topics, Flink completed-payments join **+ FX TTJ**, risk score via **profile TTJ + external UDF**, Tableflow), and Databricks Unity Catalog integration.

### What Terraform Creates

| Layer | Resources |
|-------|-----------|
| **AWS** | VPC, EC2 (PostgreSQL + ShadowTraffic + Risk API `:8089`), S3, IAM |
| **Confluent Cloud** | Environment, Standard Kafka cluster, Schema Registry, Flink compute pool, Postgres CDC (`customer_profiles` + `fx_rates`), lifecycle topics, Flink MTs (`riverflow_payments`, `riverflow_payments_risk_score`, `riverflow_customer_risk_exposure_24h`), risk UDF artifact/CONNECTION (default on), Tableflow on those three products + UC catalog integration |
| **Databricks** | Storage credential, external location, catalog, RiverPulse SQL views |

### Prerequisites

Complete **[LAB 1](../LAB1_account_setup/LAB1.md)**.

> [!WARNING]
> Apply creates billable resources. Tear down with **[LAB 4](../LAB4_cleanup/LAB4.md)** when finished.

## Steps

### Step 1: Initialize and Apply

```sh
cd terraform/aws-demo
docker-compose run --rm terraform -c "terraform init"
docker-compose run --rm terraform -c "terraform apply -auto-approve"
```

> [!NOTE]
> **Expected Duration**
>
> Approximately 45–90 minutes on a cold start. Longest steps are typically EC2/Postgres boot, CDC snapshot, IAM propagation, Flink MT creation, and **Tableflow → S3 → Unity Catalog** (often 30–60+ minutes while topics stay `PENDING`). Terraform polls until Tableflow is `RUNNING` and UC base tables exist before creating RiverPulse views.

#### While you wait (facilitator / self-study)

Use the idle apply time — don’t leave a silent gap:

1. Walk the [architecture diagram](../../../README.md#architecture) (source → stream → Flink products → Tableflow → Genie)
2. Introduce personas from [`USECASE.md`](../../../USECASE.md) (Dana / Marcus)
3. Preview the **CSFLE** talking point (light PII on profiles — not full labs)
4. Bookmark Genie prompts: [`sql/genie_prompts.md`](../../../sql/genie_prompts.md)

### Step 2: Review Outputs

```sh
docker-compose run --rm terraform -c "terraform output demo_status"
docker-compose run --rm terraform -c "terraform output workshop_summary"
```

> [!NOTE]
> **Expected Result**
>
> Outputs list environment/cluster IDs, Flink table names, Tableflow topic IDs,
> `databricks_catalog`, `databricks_schema` (usually the Kafka cluster ID), and console links.

**Example shape** (IDs and names will differ for your `prefix`):

```text
demo_status = {
  environment_id     = "env-xxxxx"
  kafka_cluster_id   = "lkc-xxxxx"
  flink_compute_pool = "lfcp-xxxxx"
  payments_table     = "riverflow_payments"
  risk_score_table   = "riverflow_payments_risk_score"
  customer_risk_exposure_table = "riverflow_customer_risk_exposure_24h"
  databricks_catalog = "neo-abcd1234"
  databricks_schema  = "lkc-xxxxx"
  links = {
    confluent_tableflow = "https://confluent.cloud/environments/.../tableflow"
    confluent_flink     = "https://confluent.cloud/environments/.../flink/..."
    databricks          = "https://dbc-….cloud.databricks.com"
  }
}
```

### Step 3: Observe Confluent Cloud

1. Open the **Tableflow** and **Flink** links from `demo_status`
2. Confirm CDC topics have messages:
   - `riverflow.riverpay.customer_profiles` (~100 profiles after ShadowTraffic stage 1)
   - `riverflow.riverpay.fx_rates` (USD + GBP/AUD/CAD/JPY/EUR; updates ~every 5s)
3. Confirm lifecycle **source** topics receive events:
   - `riverflow.payments.initiation`
   - `riverflow.payments.authorization`
   - `riverflow.payments.balance_update`
   - `riverflow.payments.status`
4. Optional — open one message on `riverflow.payments.initiation` in the Confluent Cloud topic UI and confirm it deserializes via **Schema Registry (Avro)** (flattened payment fields, multi-currency, not nested ISO 20022)
5. Open Flink data products:
   - `riverflow_payments` — completed payments (4-way inner join + FX TTJ → `amount_usd`)
   - `riverflow_payments_risk_score` — `risk_score` / `risk_reason` from external UDF
   - `riverflow_customer_risk_exposure_24h` — trailing-24h per-customer aggregate (`payment_count`, `avg_risk_score`, `max_risk_score`), updates immediately on each new payment
6. Confirm Tableflow is enabled on those **two** products (not the raw lifecycle topics)
7. Optional — `terraform output risk_api_url` and curl `/health` on the demo Risk API

> [!TIP]
> **CSFLE talking point (keep brief)**
>
> Profile rows include light PII fields (`full_name`, `tax_id`, `date_of_birth`). In production, RiverPay would protect these with CSFLE. This workshop does not walk through full CSFLE setup — call it out and move on.

### Step 4: Observe Databricks

1. Open your Databricks workspace (or the link from `demo_status.links.databricks`)
2. Navigate to catalog `demo_status.databricks_catalog` → schema `demo_status.databricks_schema`
3. Confirm Delta tables from Tableflow and views (sync can take several extra minutes after apply):
   - `riverflow_payments` / `riverflow_payments_risk_score` / `riverflow_customer_risk_exposure_24h`
   - `riverpulse_high_risk_payments`
   - `riverpulse_customer_risk_24h`
   - `riverpulse_lifecycle_completion`

#### Checkpoint

- [ ] `terraform apply` succeeded
- [ ] CDC profile + FX topics and lifecycle topics show traffic
- [ ] `riverflow_payments` (with `amount_usd`) and risk score tables have rows
- [ ] Databricks catalog/schema/views visible (Tableflow→UC can take 30–60+ minutes on first publish; apply waits for this)

## Conclusion

The end-to-end RiverFlow → RiverPulse pipeline is live.

## What's Next

Continue to **[LAB 3: RiverPulse Analytics](../LAB3_riverpulse_analytics/LAB3.md)**.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Apply stuck on Postgres wait | Check EC2 security group / SSH key; see shared troubleshooting |
| Empty risk_score | Confirm ShadowTraffic + Risk API on EC2; UDF CONNECTION; wait for watermarks |
| Missing `amount_usd` / FX join gaps | Confirm `riverflow.riverpay.fx_rates` CDC traffic |
| Tables missing in UC | Wait for Tableflow sync; re-check catalog integration |

Full guide: [shared troubleshooting](../../shared/troubleshooting.md).
