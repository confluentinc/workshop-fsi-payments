# Genie Prompt Pack — RiverPulse

Use these prompts in Databricks Genie against the Tableflow-published Flink
data products / `riverpulse_*` views.

**Published tables (Phase 1):** `riverflow_payments` (append, completed only),
`riverflow_payments_risk_score` (upsert).

## 1. Highest exception-probability payments

**Prompt:** Which payments are most likely to need manual intervention right now?

**Expected shape:** Rows ordered by `risk_score` descending with `payment_id`,
`customer_id`, `amount`, `risk_score`, and human-readable `risk_reason`.

**View shortcut:** `SELECT * FROM riverpulse_high_risk_payments LIMIT 20;`

## 2. Highest-risk customers (last 7 days)

**Prompt:** Which customers drive the highest operational exception exposure in the last 7 days?

**Expected shape:** Customers ranked by average or max `risk_score`, with
`payment_count`, `segment`, and `account_tier`.

**View shortcut:** `SELECT * FROM riverpulse_customer_risk_7d LIMIT 20;`

## 3. Lifecycle completion rate

**Prompt:** What is the RiverFlow lifecycle completion rate from initiation to completed status?

**Expected shape:** `initiated_enriched`, `completed`, and `completion_rate`
(completed / initiated_enriched). Phase 1 uses risk_score rows as the
initiation proxy and `riverflow_payments` as fully completed (4-way inner join).

**View shortcut:** `SELECT * FROM riverpulse_lifecycle_completion;`

> **Facilitator note:** Stall / “stuck at authorization” drill-down is **Phase 2
> backlog**. Do not oversell in-flight stage visibility in Phase 1.

## Facilitator notes

- `risk_score` is **operational exception probability**, not fraud.
- Happy path only — `riverflow_payments` only contains fully completed payments.
- If Genie returns empty results, wait for Tableflow sync and confirm both Flink MTs have data.
