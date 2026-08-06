# Genie Prompt Pack — RiverPulse

Use these prompts in Databricks Genie against the Tableflow-published Flink
data products / `riverpulse_*` views.

**Published tables (Phase 1):** `riverflow_payments` (append, completed only),
`riverflow_payments_risk_score` (upsert), `riverflow_customer_risk_exposure_24h` (upsert).

## 1. Highest exception-probability payments

**Prompt:** Which payments are most likely to need manual intervention right now?

**Expected shape:** Rows ordered by `risk_score` descending with `payment_id`,
`customer_id`, `amount` (and `amount_usd` / `currency` when asking about FX),
`risk_score`, and human-readable `risk_reason`.

**View shortcut:** `SELECT * FROM riverpulse_high_risk_payments LIMIT 20;`

Optional FX-oriented prompt: *Show me the largest completed payments by USD value, including the original amount and currency.* Expect `amount`, `currency`, `amount_usd` from `riverflow_payments` side by side, so the conversion is visible.

## 2. Highest-risk customers (last 24 hours)

**Prompt:** Which customers drive the highest operational exception exposure in the last 24 hours?

**Expected shape:** Customers ranked by average or max `risk_score`, with
`payment_count`, `segment`, and `account_tier`.

**View shortcut:** `SELECT * FROM riverpulse_customer_risk_24h LIMIT 20;`

> **Facilitator note:** Instructor-led stacks are typically provisioned 6–12 hours
> before the session, so the 24-hour window usually has real traffic. Short
> self-service / demo runs still return rows — all workshop data falls inside
> the window.
>
> `riverflow_customer_risk_exposure_24h` only recomputes a customer's row when
> they have a new payment — a customer who goes quiet keeps their last-computed
> numbers rather than decaying to zero. If challenged, this is a known,
> intentional simplification (no background clock forces recomputation).

## 3. Lifecycle completion rate

**Prompt:** What is the RiverFlow lifecycle completion rate from initiation to completed status?

**Expected shape:** `initiated_enriched`, `completed`, and `completion_rate`
(completed / initiated_enriched). Phase 1 uses risk_score rows as the
initiation proxy and `riverflow_payments` as fully completed (**4-way inner
join + FX temporal join**). Missing FX rates can exclude an otherwise complete
lifecycle from `completed`.

**View shortcut:** `SELECT * FROM riverpulse_lifecycle_completion;`

> **Facilitator note:** Stall / “stuck at authorization” drill-down is **Phase 2
> backlog**. Do not oversell in-flight stage visibility in Phase 1.

## 4. Payments by customer segment (bonus — needs schema evolution)

**Prompt:** Break down completed payments by customer segment: how many payments and what is the total USD value for each?

**Expected shape:** One row per `segment` (`retail`, `small_business`, `new_partner`,
`wealth`) with a payment count and summed `amount_usd`.

**Requires the LAB 5 Step 3 bonus.** `riverflow_payments` has no `segment` column as
built in LAB 3 — participants add it by evolving the materialized table
(`flink/payments_add_segment.sql`). Ask this *before* the evolution too: Genie
failing to answer is the setup for why the evolution matters.

> **Facilitator note:** Payments completed before the evolution ran keep `NULL` for
> `segment` — adding a column is not a backfill. On a stack provisioned hours earlier,
> expect a meaningful `NULL` bucket alongside the real segments, and call it out rather
> than letting the room read it as breakage.

## Facilitator notes

- `risk_score` is **operational exception probability**, not fraud.
- Happy path only — `riverflow_payments` only contains fully completed payments (with FX enrichment: `rate_to_usd`, `amount_usd`).
- Judge Genie by answer *shape*, not brittle golden rows.
- If Genie returns empty results, wait for Tableflow sync and confirm both Flink MTs have data.
