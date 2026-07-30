# LAB 3: Stream Processing (Flink)

## Overview

Build the two RiverPay Flink data products that Tableflow will publish later:

1. **`riverflow_payments`** — completed payments (4-way inner join + FX temporal join)
2. **`riverflow_payments_risk_score`** — profile temporal join + external risk UDF

`risk_score` is **operational exception probability**, not fraud.

### Prerequisites

Completed **[LAB 2](../LAB2_explore_environment/LAB2.md)**. Flink SQL workspace open with correct catalog/database.

> [!TIP]
> Create several empty cells before you start. Prefer `CREATE OR ALTER MATERIALIZED TABLE` so re-runs are safe. Run each `SET 'client.statement-name' …` in the **same cell** as its `CREATE` (workspace ignores a lone `SET`).

## Steps

### Step 1: Peek at sources

```sql
SELECT * FROM `riverflow.riverpay.customer_profiles` LIMIT 5;
SELECT * FROM `riverflow.riverpay.fx_rates` LIMIT 10;
SELECT * FROM `riverflow.payments.initiation` LIMIT 5;
```

### Step 2: Confirm changelog modes / watermarks

Terraform pre-applies changelog.mode and watermarks on CDC and lifecycle source tables (Azure and AWS). Spot-check one of each:

```sql
SHOW CREATE TABLE `riverflow.riverpay.customer_profiles`;
SHOW CREATE TABLE `riverflow.payments.initiation`;
```

**Expected result:** upsert + compact on profiles/FX; append on lifecycle topics; `$rowtime` watermarks present.

<details>
<summary>Fallback — only if SHOW CREATE looks incomplete</summary>

```sql
ALTER TABLE `riverflow.riverpay.customer_profiles`
  SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');
ALTER TABLE `riverflow.riverpay.customer_profiles`
  MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

ALTER TABLE `riverflow.riverpay.fx_rates`
  SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');
ALTER TABLE `riverflow.riverpay.fx_rates`
  MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

ALTER TABLE `riverflow.payments.initiation`
  SET ('changelog.mode' = 'append');
ALTER TABLE `riverflow.payments.initiation`
  MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

ALTER TABLE `riverflow.payments.authorization`
  SET ('changelog.mode' = 'append');
ALTER TABLE `riverflow.payments.authorization`
  MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

ALTER TABLE `riverflow.payments.balance_update`
  SET ('changelog.mode' = 'append');
ALTER TABLE `riverflow.payments.balance_update`
  MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

ALTER TABLE `riverflow.payments.status`
  SET ('changelog.mode' = 'append');
ALTER TABLE `riverflow.payments.status`
  MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;
```

</details>

### Step 3: Completed payments + FX conversion

Reference: [`flink/fx_conversion.sql`](../../../flink/fx_conversion.sql)

```sql
SET 'client.statement-name' = 'riverflow-payments-completed';
CREATE OR ALTER MATERIALIZED TABLE `riverflow_payments` AS
SELECT
  i.`payment_id`,
  i.`customer_id`,
  i.`source_account`,
  i.`destination_account`,
  i.`amount`,
  i.`currency`,
  fx.`rate_to_usd`,
  ROUND(i.`amount` * fx.`rate_to_usd`, 2) AS `amount_usd`,
  i.`payment_type`,
  i.`channel`,
  i.`initiated_at`,
  a.`authorization_code`,
  a.`authorized_at`,
  b.`source_balance_after`,
  b.`destination_balance_after`,
  b.`updated_at` AS `balance_updated_at`,
  s.`status`,
  s.`status_reason`,
  s.`completed_at`
FROM `riverflow.payments.initiation` i
  INNER JOIN `riverflow.payments.authorization` a
    ON i.`payment_id` = a.`payment_id`
  INNER JOIN `riverflow.payments.balance_update` b
    ON i.`payment_id` = b.`payment_id`
  INNER JOIN `riverflow.payments.status` s
    ON i.`payment_id` = s.`payment_id`
  JOIN `riverflow.riverpay.fx_rates` FOR SYSTEM_TIME AS OF i.`$rowtime` AS fx
    ON fx.`currency_code` = i.`currency`;
```

**Expected result:** Rows appear only for payments that completed all four stages, with `amount_usd` populated.

### Step 4: Operational risk via external UDF

Reference: [`flink/risk_udf.sql`](../../../flink/risk_udf.sql)

The function `lookup_operational_risk(amount, segment, account_tier)` calls the shared Risk Scoring API and returns `risk_score|risk_reason`.

```sql
SET 'client.statement-name' = 'riverflow-payments-risk-score';
CREATE OR ALTER MATERIALIZED TABLE `riverflow_payments_risk_score` AS
SELECT
  enriched.`payment_id`,
  enriched.`customer_id`,
  enriched.`segment`,
  enriched.`account_tier`,
  enriched.`amount`,
  enriched.`currency`,
  enriched.`payment_type`,
  enriched.`initiated_at`,
  CAST(SPLIT_INDEX(enriched.`risk_payload`, '|', 0) AS DOUBLE) AS `risk_score`,
  SPLIT_INDEX(enriched.`risk_payload`, '|', 1) AS `risk_reason`,
  CURRENT_TIMESTAMP AS `enrichment_timestamp`
FROM (
  SELECT
    p.`payment_id`,
    p.`customer_id`,
    c.`segment`,
    c.`account_tier`,
    p.`amount`,
    p.`currency`,
    p.`payment_type`,
    p.`initiated_at`,
    lookup_operational_risk(p.`amount`, c.`segment`, c.`account_tier`) AS `risk_payload`
  FROM `riverflow.payments.initiation` p
    JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
      ON c.`customer_id` = p.`customer_id`
) AS enriched;
```

**Expected result:** Upsert rows with readable `risk_reason` values such as `amount_significantly_above_customer_baseline`, `new_partner_bank_customer`, `routine_instant_credit_transfer`.

#### Checkpoint

- [ ] `riverflow_payments` has completed payments with `rate_to_usd` / `amount_usd`
- [ ] `riverflow_payments_risk_score` has `risk_score` + `risk_reason` from the UDF path

## Conclusion

You produced the two Flink data products Elevate cares about: FX-aware completed payments and externally scored operational risk.

## What's next

**[LAB 4: Tableflow](../LAB4_tableflow/LAB4.md)**
