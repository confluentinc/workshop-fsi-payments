# LAB 5: RiverPulse Analytics (Genie)

**Previous:** [LAB 4: Tableflow](../LAB4_tableflow/LAB4.md)

## Overview

Use Databricks Genie to answer RiverPay’s three operational questions against Tableflow tables.

### Three business questions

1. Which payments are most likely to need manual intervention right now?
2. Which customers drive the highest operational exception exposure in the last 24 hours?
3. What is the RiverFlow lifecycle completion rate from initiation to completed status?

(Phase 1 completion rate is a proxy: completed = 4-way join + FX enrichment / initiated_enriched. Stall drill-down is Phase 2.)

### Prerequisites

Completed **[LAB 4](../LAB4_tableflow/LAB4.md)**. Have catalog, schema, and SQL warehouse ID from your credentials email.

## Steps

### Step 1: Open Genie

1. In Databricks, open **Genie**
2. Attach your workshop catalog/schema (and warehouse)

### Step 2: Ask the three questions

Paste these into Genie one at a time:

> [!NOTE]
> Each prompt takes around 1–2 minutes to complete — Genie has to pick the tables, write the SQL, and run it on your warehouse.

**Q1 — Highest exception-probability payments**

```text
Which payments are most likely to need manual intervention right now?
```

**Q2 — Highest-risk customers (last 24 hours)**

```text
Which customers drive the highest operational exception exposure in the last 24 hours?
```

**Q3 — Lifecycle completion rate**

```text
What is the RiverFlow lifecycle completion rate from initiation to completed status?
```

Optional, if you want to see the FX enrichment at work:

```text
Show me the largest completed payments by USD value, including the original amount and currency.
```

> [!NOTE]
> **Expected shape (not brittle golden rows)**
>
> - Q1: payments ordered by `risk_score` with `risk_reason`
> - Q2: customers ranked by avg/max `risk_score` over recent window
>
> A customer's row only updates when they have a new payment — a quiet customer's numbers won't decay to zero, they'll just stay at their last-computed value.
> - Q3: `initiated_enriched`, `completed`, `completion_rate`
>
> Exact IDs/amounts change with live ShadowTraffic data. `risk_score` is **not** fraud.

[`sql/genie_prompts.md`](../../../sql/genie_prompts.md) has the full expected answer shape and view shortcuts for each question.

### Step 3: Answer a question the data product can't answer yet (Schema Evolution)

Reference: [`flink/payments_add_segment.sql`](../../../flink/payments_add_segment.sql)

Ask Genie to break completed payments down by customer segment and it can't — `riverflow_payments` has no `segment` column. Nobody thought to include it when the product was built.

In a batch world this is a change request: a ticket, a backfill, a new table, and a wait. With Confluent's materialized tables it's far easier — a simple edit to the query that's already running, and Flink evolves the table in place. Go back to your **Flink SQL workspace** from LAB 3 and re-run the completed-payments statement with two additions — `c.segment` appended to the end of the `SELECT` list, and a temporal join that supplies it:

```sql
  LEFT JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF i.`$rowtime` AS c
    ON c.`customer_id` = i.`customer_id`;
```

The full statement is in [`flink/payments_add_segment.sql`](../../../flink/payments_add_segment.sql).

Nothing downstream had to be rebuilt, and nothing had to be taken down to do it. You didn't stop the statement, drop and recreate the table, or think about consumer offsets — the **materialized table** owns both the schema and the query, so Flink migrated it in place and kept going. Tableflow then carried the new column into Delta on its own, and Unity Catalog picked it up.

Check the new column in the Databricks **SQL Editor**:

```sql
SELECT `payment_id`, `customer_id`, `segment`
FROM `riverflow_payments`
ORDER BY `completed_at` DESC
LIMIT 50;
```

Then go back to Genie and ask the question that failed a minute ago:

```text
Break down completed payments by customer segment: how many payments and what is the total USD value for each?
```

> [!TIP]
> **Why this matters commercially.** Two properties made that a five-minute change instead of a project. The column was **added**, not moved or renamed — existing consumers keep reading the table exactly as before, so nothing had to be coordinated or re-tested. And the profile lookup is a `LEFT JOIN`, so a payment with no matching profile still appears; the table's meaning — every completed payment — is unchanged.

> [!NOTE]
> Payments that completed **before** you ran this show `NULL` for `segment` — the column is added going forward, not backfilled onto history. Sorting by `completed_at DESC` shows the populated rows first.

### Step 4: Optional SQL views

If operators created RiverPulse views:

```sql
SELECT * FROM <catalog>.<schema>.riverpulse_high_risk_payments LIMIT 20;
SELECT * FROM <catalog>.<schema>.riverpulse_customer_risk_24h LIMIT 20;
SELECT * FROM <catalog>.<schema>.riverpulse_lifecycle_completion;
```

Otherwise query `riverflow_payments_risk_score` / `riverflow_payments` directly.

#### Checkpoint

- [ ] Genie (or SQL) answers all three questions
- [ ] At least one high `risk_score` row has a readable `risk_reason`
- [ ] `riverflow_payments` carries `segment` in Databricks, and Genie can break payments down by segment

## Conclusion

RiverPulse turns real-time RiverFlow products into ops answers — without an end-of-day batch wait.

## What's next

**[LAB 6: Wrap-up & cleanup](../LAB6_cleanup/LAB6.md)**
