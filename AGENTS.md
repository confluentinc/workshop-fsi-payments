# FSI Real-Time Payments Workshop

This repo is the **demo-mode workshop product** for Confluent FSI real-time
payments (RiverPay / RiverFlow / RiverPulse): labs, Terraform, ShadowTraffic
configs, plus narrative docs under `context/`.

## Structure

- `labs/demo/` — Confluent Cloud participant labs (LAB0–LAB4)
- `labs/cp-rosa/` — parallel **CP on ROSA** labs (RiverPay-lite; LAB0–LAB4)
- `labs/shared/` — Cloud-path troubleshooting + recap
- `terraform/aws-demo/` — Dockerized Terraform root (one apply = full Cloud pipeline)
- `terraform/cp-rosa/` — two-stage Terraform (ROSA HCP → CFK + CP + RiverPay-lite)
- `terraform/modules/` — Confluent / Databricks modules (Cloud path)
- `shadowtraffic/` — ShadowTraffic generator config
- `flink/` / `sql/` — Flink SQL reference + Genie views/prompts
- `context/` — authoritative narrative content:
  - `fsi_payments_workshop_plan_v2.md` — plan of record
  - `fsi_payments_workshop_phase1_runbook.md` — conceptual build/run/teardown
  - `fsi_payments_workshop_deck.md` — slide content
  - `fsi_payments_workshop_facilitator_script.md` — speaker notes
  - `cp_rosa_demo_talk_track.md` — CP / ROSA recording + talk track
- `tmp/` — scratch only (not authoritative)
- `USECASE.md` — RiverPay narrative skin

## Delivery paths

| Path | Stack | Labs | Terraform |
|------|-------|------|-----------|
| **Cloud (Phase 1)** | Confluent Cloud + Flink + Tableflow + Databricks | `labs/demo/` | `terraform/aws-demo/` |
| **cp-rosa (parallel)** | ROSA HCP + CFK + Confluent Platform + RiverPay-lite producer | `labs/cp-rosa/` | `terraform/cp-rosa/` (Stage 1 then Stage 2) |

`cp-rosa` reuses RiverPay topic names and narrative skin but does **not** change
locked Cloud Phase 1 scope below. v1 lite: JSON producer + Control Center
(port-forward default; optional OpenShift route). No Flink / Tableflow / Databricks
on ROSA yet.

## Formalized topic / table names (Phase 1)

| Name | Role |
|------|------|
| `riverflow.riverpay.customer_profiles` | CDC from Postgres `riverpay.customer_profiles` |
| `riverflow.payments.initiation` | Lifecycle stage 1 (Kafka source) |
| `riverflow.payments.authorization` | Lifecycle stage 2 (Kafka source) |
| `riverflow.payments.balance_update` | Lifecycle stage 3 (Kafka source) |
| `riverflow.payments.status` | Lifecycle stage 4 (Kafka source) |
| `riverflow_payments` | Flink MT — completed payments (4-way inner join, append) |
| `riverflow_payments_risk_score` | Flink MT — temporal join risk output (upsert) |

Tableflow publishes **only** the two Flink data products (`riverflow_payments` append,
`riverflow_payments_risk_score` upsert). Raw lifecycle topics are not Tableflow-enabled
in Phase 1. Downstream views: `riverpulse_high_risk_payments`,
`riverpulse_customer_risk_7d`, `riverpulse_lifecycle_completion`.

## Locked Phase 1 scope (don't relitigate without flagging it)

Applies to the **Confluent Cloud** path (`labs/demo/`, `terraform/aws-demo/`).

- Storyline: happy path only (no NSF/fraud branch yet).
- Narrative: generic instant-payments, framed as "maps to FedNow/RTP-style flows."
- `risk_score` = operational exception probability, not fraud — paired with a human-readable `risk_reason`.
- Payload: flattened records (no ISO 20022 nesting); Kafka wire format **Avro + Schema Registry** (CDC and ShadowTraffic).
- Security: light PII + a brief CSFLE talking point only — not a full CSFLE walkthrough.
- Flink patterns: (1) 4-way inner join → completed `riverflow_payments` (append); (2) temporal join profile × initiation → `risk_score` (upsert). Progressive upsert / stall-aware state is Phase 2.
- Topics: lifecycle-specific (initiation, authorization, balance update, status), single-currency.
- Stack: Confluent Cloud (Kafka + Flink + Tableflow), Postgres via CDC connector, ShadowTraffic for data generation, Databricks/Genie (Delta Lake, Unity Catalog) as the downstream consumer.
- Delivery: **demo mode only** for v1 (self-service / instructor-led deferred). Cloud: **AWS-first**.

Anything not on this list is Phase 2 backlog — see the runbook's "Phase 2 backlog" and the plan's "Phase 2 extensions" sections.

## Working conventions

- Author of record: Kyle Klein (kklein@confluent.io).
- Match existing doc style: plain Markdown, `##`/`###` headers, bullet-first, tables for decision/troubleshooting matrices, "**Expected result:**" / GitHub callouts on lab steps.
- Keep the three recurring business questions (highest-risk customers, highest exception-probability payments, lifecycle completion/stall rate) consistent across the plan, deck, script, and labs when any of them changes. Phase 1 completion rate is a proxy (`riverflow_payments` / risk_score counts); stall drill-down is backlog.
- When editing the runbook or labs, keep steps numbered and testable, and keep validation checklists in sync.
- Prefer edits that keep the content customizable/reusable (e.g., Elevate 2026 DSP session).
