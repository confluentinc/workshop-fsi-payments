# Current SF 2026 — Hybrid demo variant

**Additive, demo-only scaffolding for the Current SF 2026 hybrid videos (Video 3 — CP Flink).**
Nothing here modifies the workshop's happy-path main. These files layer on top of the
existing `shadowtraffic/`, `flink/`, and `terraform/` assets so the Current demo can reuse
the RiverPay data model while swapping in on-prem serving.

> Planning docs live in the event folder:
> `~/Projects/Events/Current/2026/SF/` → `Storyboard.md`, `Talk-Tracks.md`.
> Videos are **strictly on-prem** — no Databricks / Genie / Tableflow.

## Why this branch exists

The videos reuse the workshop's **data as-is** (ShadowTraffic generator → 4 RiverFlow
lifecycle topics + Postgres `customer_profiles` CDC + `fx_rates`). Only the **serving +
scoring layer** changes, plus two optional narrative extras. Keeping it on a branch (and in
this folder) isolates it from the workshop main and the instructor-led/self-service labs.

## The four additive items (map to the storyboard)

| Item | File | Status |
|---|---|---|
| CI model scoring (replace CASE/REST UDF with on-prem KServe/Granite model) | [`flink/exception_score_ci.sql`](flink/exception_score_ci.sql) | stub + TODOs |
| "Stuck between stages" detection (workshop Phase 2 backlog) — optional | [`flink/stuck_payments.sql`](flink/stuck_payments.sql) | stub + TODOs |
| `partner_bank` field + partial/stuck lifecycles in the generator | [`shadowtraffic/generator-demo-overlay.md`](shadowtraffic/generator-demo-overlay.md) | overlay doc |
| Point the generator at the CP / demo Flink cluster | [`terraform/README.md`](terraform/README.md) | note + TODOs |

## Current narrative note

Video 3 (Dana) uses **exception-probability** (`risk_score` / `riverpulse_high_risk_payments`)
and slices **by `segment`** — both already supported by the stock data. The `partner_bank`
field and `stuck_payments` job are **optional** (only if we want "by partner bank" or a literal
"stuck" drill-down); the exception-probability story needs neither.

## Fallback

If the on-prem CI model isn't demo-stable in time, the stock
[`../../flink/risk_score.sql`](../../flink/risk_score.sql) (CASE heuristic) or
[`../../flink/risk_udf.sql`](../../flink/risk_udf.sql) (REST UDF) produce the **same output
columns** (`risk_score`, `risk_reason`) — so the RiverPulse views and the Confluent Assistant
queries are identical either way.
