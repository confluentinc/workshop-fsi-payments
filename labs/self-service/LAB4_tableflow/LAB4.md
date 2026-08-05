# LAB 4: Tableflow

**Previous:** [LAB 3: Stream Processing](../LAB3_stream_processing/LAB3.md)

## Overview

Publish the Flink data products to Databricks Unity Catalog with Tableflow (Delta).

### What you'll accomplish

1. Confirm catalog integration (pre-provisioned)
2. Enable Tableflow on `riverflow_payments` (append), `riverflow_payments_risk_score` (upsert), and `riverflow_customer_risk_exposure_24h` (upsert)
3. Verify Delta tables in Databricks

### Prerequisites

Completed **[LAB 3](../LAB3_stream_processing/LAB3.md)** with all three materialized tables populated.

## Steps

### Step 1: Catalog integration

In Confluent Cloud → **Tableflow** → confirm your environment already has a Unity Catalog integration — your **[LAB 2](../LAB2_deploy_and_explore/LAB2.md)** `terraform apply` created it, pointing at your own S3 (AWS) or ADLS Gen2 (Azure) external location. If it's missing, re-run `terraform apply` and check the plan for the catalog integration resource.

### Step 2: Enable Tableflow on real-time data products only

Enable Tableflow for:

| Topic / table | Mode |
|---------------|------|
| `riverflow_payments` | append |
| `riverflow_payments_risk_score` | upsert |
| `riverflow_customer_risk_exposure_24h` | upsert |

Do **not** Tableflow-enable raw lifecycle CDC topics in this workshop.

Follow the Cloud UI: select topic → Tableflow → Enable → Delta Lake → your catalog integration.

**Expected result:** Sync status becomes healthy; tables appear under your Databricks catalog/schema.

### Step 3: Verify in Databricks

In SQL editor (replace catalog/schema):

```sql
SHOW TABLES IN <catalog>.<schema>;
SELECT * FROM <catalog>.<schema>.riverflow_payments LIMIT 10;
SELECT * FROM <catalog>.<schema>.riverflow_payments_risk_score LIMIT 10;
SELECT * FROM <catalog>.<schema>.riverflow_customer_risk_exposure_24h LIMIT 10;
```

#### Checkpoint

- [ ] All three Flink products enabled for Tableflow
- [ ] Rows visible in Databricks for all three tables

## Conclusion

Delta tables are ready for RiverPulse / Genie.

## What's next

**[LAB 5: RiverPulse Analytics](../LAB5_riverpulse_analytics/LAB5.md)**
