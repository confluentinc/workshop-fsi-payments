# Recap — RiverPay Workshop

## What you built

1. **Ingest** — Postgres CDC for RiverPay customer profiles **and FX rates**
2. **Stream** — RiverFlow lifecycle topics (initiation → authorization → balance update → status), multi-currency
3. **Flink data products**
   - `riverflow_payments` — completed payments (4-way inner join + FX temporal join, append)
   - `riverflow_payments_risk_score` — operational risk (profile temporal join + external risk UDF, upsert)
4. **Serve** — Tableflow those two products into Unity Catalog
5. **Act** — RiverPulse / Genie answers to three ops questions

## Talking points

- Happy path only (Phase 1) — maps to FedNow/RTP-style flows without claiming to be those rails
- `risk_score` ≠ fraud; it is operational exception probability from an **external lookup** (UDF)
- FX rates are versioned in Postgres and joined temporally so each payment picks the rate in effect at initiation
- Completed-payments product only emits when all four stages match
- Stall / in-flight stage drill-down is Phase 2 backlog
- Light PII + CSFLE is a talking point, not a deep dive
- Tableflow removes custom lakehouse pipeline toil for Marcus (data platform)
- Genie closes the loop for Dana (ops)

## Three business questions (keep consistent)

1. Which payments are most likely to need manual intervention right now?
2. Which customers drive the highest operational exception exposure in the last 24 hours?
3. What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy: completed = 4-way join + FX enrichment / initiated_enriched)

## Delivery modes

- **Demo** (`labs/demo` + `terraform/aws-demo`) — full pipeline automated
- **Instructor-led** (`labs/instructor-led` + Azure shared/per-attendee) — Flink MTs and Tableflow are hands-on

## Phase 2 (out of scope today)

Failed-payment / DLQ / side-outputs, progressive / stall-aware payment state, NSF/fraud branches, ISO 20022 nesting, `MATCH_RECOGNIZE`, full CSFLE lab, Lightning Tables, deeper CP/CPC beyond the parallel `cp-rosa` lite path.
