# LAB 3: RiverPulse Analytics

## Overview

Your pipeline is streaming. Use Databricks Genie (RiverPulse) to answer the three operational questions that matter to RiverPay ops — without waiting for an end-of-day batch report.

### Personas (optional beat)

- **Dana Ruiz, VP of Payment Operations** — needs payments that need human attention *now*
- **Marcus Chen, Head of Data Platform** — wants governed tables in Databricks without custom ETL

### Prerequisites

Complete **[LAB 2](../LAB2_deploy_and_observe/LAB2.md)**. Have `demo_status.databricks_catalog` and `demo_status.databricks_schema` handy (schema is usually the Kafka cluster ID).

## Steps

### Step 1: Open Genie

1. In Databricks, open **Genie** (or **SQL editor** if Genie is unavailable)
2. Create or open a Genie space and attach the workshop catalog from `demo_status.databricks_catalog`
3. Set the default schema to `demo_status.databricks_schema` (or fully qualify objects as `catalog.schema.object`)

### Step 2: Ask the three business questions

Use the prompts from [`sql/genie_prompts.md`](../../../sql/genie_prompts.md):

1. **Which payments are most likely to need manual intervention right now?**
2. **Which customers drive the highest operational exception exposure in the last 7 days?**
3. **What is the RiverFlow lifecycle completion rate from initiation to completed status?**

> [!NOTE]
> **Expected Result**
>
> Answers cite `risk_score` / `risk_reason` for (1)–(2). For (3), expect
> `initiated_enriched`, `completed`, and `completion_rate` (Phase 1 proxy:
> completed / initiated_enriched). Stall / “stuck at stage X” drill-down is
> Phase 2 backlog — do not oversell it in Phase 1.
>
> Remember: `risk_score` is operational exception probability, **not** fraud.

**Worked example (Q1)** — Genie (or SQL) should surface rows like:

| payment_id | amount | risk_score | risk_reason |
|------------|--------|------------|-------------|
| `pay-…` | ≥ 10000 | `0.85` | `amount_significantly_above_customer_baseline` |
| `pay-…` | ≥ 5000 (standard tier) | `0.72` | `high_value_standard_tier` |

Other `risk_reason` values from the Flink heuristics (`flink/risk_score.sql`): `new_partner_bank_customer`, `elevated_amount_review_recommended`, `low_value_established_recipient`, `routine_instant_credit_transfer`.

### Step 3: Validate with SQL views (optional)

Replace `<catalog>` and `<schema>` with values from `demo_status`:

```sql
SELECT * FROM <catalog>.<schema>.riverpulse_high_risk_payments LIMIT 20;
SELECT * FROM <catalog>.<schema>.riverpulse_customer_risk_7d LIMIT 20;
SELECT * FROM <catalog>.<schema>.riverpulse_lifecycle_completion;
```

#### Checkpoint

- [ ] Genie (or SQL) answers all three questions
- [ ] At least one high `risk_score` payment shows a readable `risk_reason`

## Conclusion

RiverPulse turns real-time RiverFlow data into actionable ops answers.

## What's Next

Continue to **[LAB 4: Cleanup](../LAB4_cleanup/LAB4.md)**.

## Troubleshooting

If Genie returns empty results, wait for Tableflow sync and confirm views exist — see [shared troubleshooting](../../shared/troubleshooting.md).
