# LAB 4: Tableflow

## Overview

Publish the Flink data products to Databricks Unity Catalog with Tableflow (Delta). Discuss **data TTL / right-to-forget** as a governance talking point for payment ops.

### What you'll accomplish

1. Confirm catalog integration (pre-provisioned)
2. Enable Tableflow on `riverflow_payments` (append) and `riverflow_payments_risk_score` (upsert)
3. Configure **data TTL** (right-to-forget) on both Tableflow topics
4. Verify Delta tables in Databricks

### Prerequisites

Completed **[LAB 3](../LAB3_stream_processing/LAB3.md)** with both MTs populated.

## Steps

### Step 1: Catalog integration

In Confluent Cloud → **Tableflow** → confirm your environment already has a Unity Catalog integration pointing at the shared ADLS location. If anything looks missing, ask the instructor (operators provision this with shared infra).

### Step 2: Enable Tableflow on Flink products only

Enable Tableflow for:

| Topic / table | Mode |
|---------------|------|
| `riverflow_payments` | append |
| `riverflow_payments_risk_score` | upsert |

Do **not** Tableflow-enable raw lifecycle CDC topics in this workshop.

Follow the Cloud UI: select topic → Tableflow → Enable → Delta Lake → your catalog integration.

**Expected result:** Sync status becomes healthy; tables appear under your Databricks catalog/schema.

### Step 3: Set Tableflow data TTL (right-to-forget)

For each of the two Tableflow-enabled topics, configure **data TTL** so old rows expire automatically (GDPR / right-to-forget talking point).

1. Open the topic → **Tableflow** → **Configuration** (or Edit settings)
2. Find **Data retention** / **Data TTL** (`data_retention_ms`)
3. Set retention to at least **30 days** (Confluent Cloud minimum today — `2592000000` ms). For the workshop, use **30 days** unless the instructor specifies otherwise.
4. Optionally note **Snapshot / version retention** (`retention_ms`) — this expires old Delta versions for time-travel, and is separate from deleting table rows.
5. Save

> [!NOTE]
> **Data TTL vs snapshot retention**
>
> - **Data TTL** (`data_retention_ms`) — deletes rows older than the retention window.
> - **Snapshot retention** (`retention_ms`) — expires old Delta snapshots/versions used for time-travel; does not by itself delete current table rows.
>
> In demo mode, Terraform sets both on `riverflow_payments` and `riverflow_payments_risk_score` (default TTL = 30 days). Here you set them in the UI so you see the control ops would use.

**Talking point:** RiverPay needs operational visibility *and* bounded retention of payment/risk history. TTL is how Tableflow encodes “we don’t keep this forever.”

### Step 4: Verify in Databricks

In SQL editor (replace catalog/schema):

```sql
SHOW TABLES IN <catalog>.<schema>;
SELECT * FROM <catalog>.<schema>.riverflow_payments LIMIT 10;
SELECT * FROM <catalog>.<schema>.riverflow_payments_risk_score LIMIT 10;
```

#### Checkpoint

- [ ] Both Flink products enabled for Tableflow
- [ ] Data TTL configured (≥ 30 days) on both topics
- [ ] Rows visible in Databricks
- [ ] You can explain data TTL vs snapshot retention for payments ops

## Conclusion

Governed Delta tables are ready for RiverPulse / Genie.

## What's next

**[LAB 5: RiverPulse Analytics](../LAB5_riverpulse_analytics/LAB5.md)**
