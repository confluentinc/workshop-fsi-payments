# Recap — RiverPay Demo

## What you built

1. **Ingest** — Postgres CDC for RiverPay customer profiles
2. **Stream** — RiverFlow lifecycle topics (initiation → authorization → balance update → status)
3. **Flink data products**
   - `riverflow_payments` — completed payments (4-way inner join, append)
   - `riverflow_payments_risk_score` — operational risk (temporal join, upsert)
4. **Serve** — Tableflow those two products into Unity Catalog
5. **Act** — RiverPulse / Genie answers to three ops questions

## Talking points

- Happy path only (Phase 1) — maps to FedNow/RTP-style flows without claiming to be those rails
- `risk_score` ≠ fraud; it is operational exception probability
- Completed-payments product only emits when all four stages match
- Stall / in-flight stage drill-down is Phase 2 backlog
- Light PII + CSFLE is a talking point, not a deep dive
- Tableflow removes custom lakehouse pipeline toil for Marcus (data platform)
- Genie closes the loop for Dana (ops)

## Three business questions (keep consistent)

1. Which payments are most likely to need manual intervention right now?
2. Which customers drive the highest operational exception exposure in the last 7 days?
3. What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy: completed / initiated_enriched)

## Phase 2 (out of scope today)

Progressive / stall-aware payment state, NSF/fraud branches, ISO 20022 nesting, MATCH_RECOGNIZE, FX, full CSFLE lab, Lightning Tables, CP/CPC, self-service / instructor-led modes.
