# FSI Real-Time Payments Workshop

This repo is the **workshop product** for Confluent FSI real-time payments
(RiverPay / RiverFlow / RiverPulse): labs, Terraform, ShadowTraffic configs,
plus narrative docs under `context/`.

## Structure

- `labs/demo/` — Confluent Cloud demo-mode labs (LAB0–LAB4; AWS full pipeline)
- `labs/self-service/` — BYO accounts; Flink + Tableflow hands-on (LAB0–LAB6)
- `labs/instructor-led/` — instructor-led / hosted path (pre-provisioned shared infra on Azure or AWS; Flink + Tableflow hands-on)
- `labs/cp-rosa/` — parallel **CP on ROSA** labs (RiverPay-lite; LAB0–LAB4)
- `labs/shared/` — Cloud-path troubleshooting + recap
- `terraform/aws/` — self-service AWS **or** instructor-led per-attendee (with `shared_*` from aws-shared)
- `terraform/aws-demo/` — Dockerized Terraform root (one apply = full Cloud pipeline on AWS)
- `terraform/aws-shared/` — instructor-led shared AWS infra (Postgres, FX, Risk API, S3)
- `terraform/azure-shared/` — instructor-led shared Azure infra (Postgres, FX, Risk API, ADLS)
- `terraform/azure/` — per-attendee instructor-led **or** self-service (empty `shared_*`)
- `terraform/azure-lifecycle-st/` / `terraform/aws-lifecycle-st/` — post-account multi-cluster lifecycle ShadowTraffic
- `terraform/modules/lifecycle-shadowtraffic/` — reusable N-Kafka ST module
- `terraform/cp-rosa/` — two-stage Terraform (ROSA HCP → CFK + CP + RiverPay-lite)
- `terraform/modules/` — Confluent / Databricks modules (Cloud path)
- `shadowtraffic/` — ShadowTraffic generator config (pin `2.0.3`)
- `services/risk-api/` — shared Risk Scoring REST API (Flink UDF target)
- `udf/riverpay-risk/` — Java Flink UDF (`LookupOperationalRisk`); JAR in `dist/`
- `flink/` / `sql/` — Flink SQL reference + Genie views/prompts
- `scripts/wsa-deploy-lifecycle-st.sh` — after `wsa build`, apply multi-cluster lifecycle ST
- `context/` — authoritative narrative content:
  - `fsi_payments_workshop_plan_v2.md` — plan of record
  - `fsi_payments_workshop_phase1_runbook.md` — conceptual build/run/teardown
  - `fsi_payments_workshop_deck.md` — slide content
  - `fsi_payments_workshop_facilitator_script.md` — speaker notes
  - `cp_rosa_demo_talk_track.md` — CP / ROSA recording + talk track
  - `elevate_2026_internal_changelog.md` — detailed Elevate implementation delta (not the public `CHANGELOG.md`)
- `docs/operator-instructor-led.md` — WSA operator runbook (shared → accounts → lifecycle-st → teardown)
- `docs/operator-azure-elevate.md` — Azure-specific Elevate notes (ACR / Container Apps)
- `wsa-spec-azure.yaml` / `wsa-spec-aws.yaml` — WSA build/clean for instructor-led
- `tmp/` — scratch only (not authoritative)
- `USECASE.md` — RiverPay narrative skin

## Delivery paths

| Path | Stack | Labs | Terraform |
|------|-------|------|-----------|
| **Cloud demo** | Confluent Cloud + Flink + Tableflow + Databricks (automated) | `labs/demo/` | `terraform/aws-demo/` |
| **Cloud self-service** | BYO accounts; Flink + Tableflow **manual** | `labs/self-service/` | `terraform/aws/`; `terraform/azure/` empty `shared_*` (datagen VM + Flexible Server) |
| **Cloud instructor-led** | Shared infra + per-attendee + multi-cluster lifecycle ST; Flink + Tableflow **manual** | `labs/instructor-led/` | `*-shared` + per-attendee + `*-lifecycle-st` (Azure or AWS) |
| **cp-rosa (parallel)** | ROSA HCP + CFK + Confluent Platform + RiverPay-lite producer | `labs/cp-rosa/` | `terraform/cp-rosa/` (Stage 1 then Stage 2) |

`cp-rosa` reuses RiverPay topic names and narrative skin but does **not** change
locked Cloud Phase 1 scope below. v1 lite: JSON producer + Control Center
(port-forward default; optional OpenShift route). No Flink / Tableflow / Databricks
on ROSA yet.

**Instructor-led vs demo:** Demo roots automate Flink MTs + Tableflow enablement.
Instructor-led pre-provisions infra (Kafka, CDC, ShadowTraffic, Databricks,
shared risk API URL + Flink CONNECTION/UDF registration, **and Flink
changelog.mode + watermarks** on CDC/lifecycle sources) and leaves **Flink
materialized-table SQL and Tableflow** as attendee lab work.

## Formalized topic / table names (Phase 1)

| Name | Role |
|------|------|
| `riverflow.riverpay.customer_profiles` | CDC from Postgres `riverpay.customer_profiles` |
| `riverflow.riverpay.fx_rates` | CDC from Postgres `riverpay.fx_rates` (upsert; ShadowTraffic ~5s) |
| `riverflow.payments.initiation` | Lifecycle stage 1 (Kafka source) |
| `riverflow.payments.authorization` | Lifecycle stage 2 (Kafka source) |
| `riverflow.payments.balance_update` | Lifecycle stage 3 (Kafka source) |
| `riverflow.payments.status` | Lifecycle stage 4 (Kafka source) |
| `riverflow_payments` | Flink MT — completed payments (4-way inner join, append); includes FX temporal-join enrichment |
| `riverflow_payments_risk_score` | Flink MT — profile temporal join + external risk UDF (one row per payment) |
| `riverflow_customer_risk_exposure_24h` | Flink MT — trailing-24h `OVER` aggregate per customer, `PRIMARY KEY (customer_id)` (genuine upsert) |

Tableflow publishes **only** the three Flink data products (`riverflow_payments` append,
`riverflow_payments_risk_score` upsert, `riverflow_customer_risk_exposure_24h` upsert), with **Tableflow data TTL** used for a
right-to-forget / GDPR talking point. Raw lifecycle and CDC source topics are not
Tableflow-enabled in Phase 1. Downstream views: `riverpulse_high_risk_payments`,
`riverpulse_customer_risk_24h`, `riverpulse_lifecycle_completion`.

**FX currencies (Phase 1):** GBP, AUD, CAD, JPY, EUR (plus USD as base). Rates are
realistic; ShadowTraffic often leaves a rate unchanged between updates.

**Risk UDF:** Shared workshop Risk Scoring REST API (one public HTTPS URL via
Azure Container Apps on Elevate). Flink `CONNECTION` + Java UDF are pre-created
per environment; attendees call the UDF from Flink SQL. Private UDF endpoints
are AWS-only — Azure Elevate uses a **public** HTTPS endpoint.

## Locked Phase 1 scope (don't relitigate without flagging it)

Applies to the **Confluent Cloud** path (`labs/demo/`, `labs/self-service/`,
instructor-led Azure, `terraform/aws-demo/`, `terraform/aws/`, and
`terraform/azure*`). Confirmed for Elevate 2026 with stakeholder review
(Jeremy, Ahmed, Satakshi).

- Storyline: happy path only (no NSF/fraud / DLQ / failed-payment side-outputs yet).
- Narrative: generic instant-payments, framed as "maps to FedNow/RTP-style flows."
- `risk_score` = operational exception probability, not fraud — paired with a human-readable `risk_reason`.
- Payload: flattened records (no ISO 20022 nesting); Kafka wire format **Avro + Schema Registry** (CDC and ShadowTraffic).
- Security: light PII + a brief CSFLE talking point only — not a full CSFLE walkthrough.
- Flink patterns:
  1. 4-way inner join → completed `riverflow_payments` (append).
  2. Temporal join initiation × `customer_profiles` → enrich inputs; **external UDF** (shared risk API) → `risk_score` / `risk_reason` (upsert).
  3. Temporal join payments × `fx_rates` (CDC upsert versioned rates) → cross-currency conversion on the completed-payments (or enrichment) path.
  4. Tableflow **data TTL** / right-to-forget as a lab talking point (fit to GDPR narrative; do not force a destructive attendee demo).
- Topics: lifecycle-specific (initiation, authorization, balance update, status) plus profile + FX CDC topics.
- Multi-currency: payments may use USD plus GBP, AUD, CAD, JPY, EUR with FX rates from Postgres CDC.
- Stack: Confluent Cloud (Kafka + Flink + Tableflow), Postgres via CDC connector, ShadowTraffic for data generation, Databricks/Genie (Delta Lake, Unity Catalog) as the downstream consumer, shared Risk Scoring REST API for the UDF.
- Delivery:
  - **Demo mode:** `aws-demo` (keep); Azure demo root for parity as needed.
  - **Self-service (BYO):** `terraform/aws` / `terraform/azure` (empty `shared_*`); accounts are self-signup — Flink queries and Tableflow are attendee work, same shape as instructor-led.
  - **Instructor-led:** Azure or AWS shared infrastructure + per-attendee environments + multi-cluster lifecycle ST (patterned on [workshop-tableflow-databricks](https://github.com/confluentinc/workshop-tableflow-databricks)); Flink MTs and Tableflow **not** auto-created — attendees build those. Changelog/watermark ALTERs are pre-applied on both clouds.
- Genie: attendees must be able to answer the three RiverPulse business questions; document expected *shape* / guidance (not brittle golden rows that break when data drifts).

Anything not on this list is Phase 2 backlog — see the runbook's "Phase 2 backlog"
and the plan's "Phase 2 extensions" sections.

## Phase 2 backlog (explicit)

- Failed-payment paths, side-outputs, DLQ / invalid-schema fan-out.
- Progressive upsert / stall-aware lifecycle drill-down.
- NSF / fraud narrative branches.
- ISO 20022 nesting; full CSFLE walkthrough.
- `MATCH_RECOGNIZE` (intentionally skipped for instructor-led complexity constraints).
- Kafka Lightning Tables evaluation; deeper CP/CPC portability beyond the parallel `cp-rosa` lite path.

## Working conventions

- Author of record: Kyle Klein (kklein@confluent.io).
- Match existing doc style: plain Markdown, `##`/`###` headers, bullet-first, tables for decision/troubleshooting matrices, "**Expected result:**" / GitHub callouts on lab steps.
- Keep the three recurring business questions (highest-risk customers, highest exception-probability payments, lifecycle completion/stall rate) consistent across the plan, deck, script, and labs when any of them changes. Phase 1 completion rate is a proxy (`riverflow_payments` with FX enrichment / risk_score counts); stall drill-down is backlog. Customer exposure window is **24 hours** (instructor-led often pre-provisioned 6–12h before the session).
- When editing the runbook or labs, keep steps numbered and testable, and keep validation checklists in sync.
- Prefer edits that keep the content customizable/reusable (e.g., Elevate 2026 DSP session).
- When Phase 1 vs Phase 2 scope changes, update this file, the plan, and the runbook together.
