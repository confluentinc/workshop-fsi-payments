# FSI Real-Time Payments Workshop — Plan (v2)

*Author: Kyle Klein · Status: Draft v2 · Cloud-first (Flink + Tableflow); CP/CPC portability is design intent, not yet validated*

## Summary

This plan describes a Cloud-first, happy-path real-time payments workshop and demo for financial services. Phase 1 is scoped to reliable Elevate "hero moments" (CDC, lifecycle streams, Flink joins + external risk UDF + FX temporal join, Tableflow with TTL, Genie) and supports both **AWS demo** and **Azure instructor-led** delivery. Everything beyond the Phase 1 core is explicitly deferred to Phase 2.

## Working goal

Build a financial services workshop and demo that shows how Confluent can power a real-time payments pipeline with connectors, stream processing, governance-minded design, and downstream data products for analytics and operational visibility.

## Why this workshop matters

There is a gap in existing FSI demo coverage: the team has stronger fraud and market-data material but lacks a reusable real-time payments demo that can be spun up quickly and customized for customers. The workshop emphasizes business relevance, real-time movement and normalization of payment data, and a practical path from source systems to downstream consumption. It can also be reused for the Elevate 2026 DSP session.

## Phase 1 scope decisions (locked for Elevate 2026)

Confirmed with stakeholder review (Jeremy, Ahmed, Satakshi) and Elevate delivery
goals. Canonical lock also lives in `AGENTS.md`. Everything not on this list is
Phase 2.

| Decision | Prior v2 choice | Elevate / Phase 1 lock | Rationale |
|---|---|---|---|
| Storyline | Happy path only | **Happy path only** (no NSF/fraud/DLQ yet) | Reliable workshop narrative; failed-payment side-outputs → Phase 2 |
| Payment rail | Generic instant-payments | **Unchanged** | Reusable without rail-specific modeling |
| `risk_score` meaning | Operational exception probability | **Unchanged** (+ human-readable `risk_reason`) | Avoids "another fraud demo" |
| Payload complexity | Flattened Avro + SR | **Unchanged**; ISO nesting → Phase 2 | Keeps focus on streaming concepts |
| PII / security depth | Light PII + brief CSFLE | **Unchanged**; full CSFLE → Phase 2 | Credibility without dominating the lab |
| Flink hero techniques | Temporal join required; UDF optional | **(1)** 4-way join completed payments; **(2)** profile TTJ + **external risk UDF**; **(3)** FX rates TTJ; **(4)** Tableflow TTL / right-to-forget | Matches real patterns: risk = external lookup, FX = temporal join; shows UDF external connectivity |
| Topics | Lifecycle-specific + completed product | **+** `riverflow.riverpay.fx_rates` CDC | FX rates versioned in Postgres, CDC upserts |
| Foreign exchange | Deferred (single-currency) | **In Phase 1** — GBP, AUD, CAD, JPY, EUR (+ USD base); ShadowTraffic ~5s, realistic, often unchanged | Elevate hero for cross-currency TTJ |
| Risk lookup | SQL CASE on profile TTJ | **Shared Risk Scoring REST API** (Azure Container Apps HTTPS) + Java UDF + Flink `CONNECTION` (one workshop URL) | External connectivity on Azure requires public HTTPS |
| Tableflow TTL | Phase 2 deep dive | **In Phase 1** as GDPR / right-to-forget talking point | Fit to use case without forcing destructive attendee demo |
| `MATCH_RECOGNIZE` | Phase 2 candidate | **Skip for Elevate** (still Phase 2) | Complexity vs workshop time box |
| Delivery | Demo mode AWS only | **Demo** (`aws-demo`) **+ instructor-led Azure** (shared infra; Flink/Tableflow manual) | Elevate: minimize setup; attendees still write Flink + enable Tableflow |

## Core workshop narrative

**RiverPay** (see `USECASE.md`) needs to process payment events in real time,
enrich them with customer and reference data, compute a payment-oriented risk
signal, and expose trusted outputs to downstream consumers for monitoring,
analytics, and action. The story is told in four layers:

* Ingest customer profile data from Postgres using CDC connectors.
* Stream RiverFlow payment events directly into Kafka using ShadowTraffic.
* Enrich and transform those streams with Flink — producing completed payments (`riverflow_payments`, with FX temporal-join enrichment) and an operational `risk_score` data product (profile TTJ + external risk UDF).
* Publish governed downstream tables through Tableflow (including TTL / right-to-forget) for Databricks Delta Lake / Unity Catalog (RiverPulse / Genie).

**Hands-on delivery:**
* **Demo:** `labs/demo/` + `terraform/aws-demo/` (full pipeline automated).
* **Instructor-led (Elevate):** Azure shared infra + per-attendee envs; Flink SQL and Tableflow are attendee work (patterned on workshop-tableflow-databricks).

Formalized topic names are in `AGENTS.md` and the Phase 1 runbook.

## Business questions the workshop answers

To keep the demo solution-led rather than feature-led, every section ties back to concrete business questions:

* Which payments are most likely to require manual intervention right now?
* Which customers drive the highest operational exception exposure in the last 24 hours?
* What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy: completed = 4-way join + FX enrichment; stall drill-down is Phase 2)

## Suggested audience

Elevate attendees, FSI solution architects, platform engineers, data engineering teams, and technical decision makers evaluating Cloud now and CP/CPC later.

## Workshop outcomes

By the end, attendees should understand:

* How Confluent supports a real-time payment lifecycle from initiation through status notification.
* How CDC plus event streaming creates a complete operational picture across customer and payment domains.
* How Flink enriches payment events (profile + FX temporal joins) and calls an external risk UDF for `risk_score`.
* How Tableflow exposes append and upsert outputs (with TTL / right-to-forget) for downstream analytics use cases.

## Demo storyline — happy path

The live demo focuses on a successful payment lifecycle because that gives the cleanest first workshop narrative and keeps the audience focused on platform value rather than exception handling.

Event sequence:

1. Customer profile exists in Postgres.
2. Payment initiation event enters Kafka.
3. Validation/authorization event is produced.
4. Balance update event is produced.
5. Payment status notification confirms successful completion.

## Reference architecture (opinionated)

### Required components (Phase 1)

* **Source/generation:** ShadowTraffic generates ~100 customer profile records and FX rate rows in Postgres (CDC), plus payment/transaction activity (multi-currency) associated to those customers. FX rates update ~every 5 seconds (realistic; often unchanged).
* **Streaming:** Kafka topics for payment initiation, authorization, balance update, and status events (sources only), plus CDC topics for profiles and `fx_rates`.
* **External risk service:** Shared Risk Scoring REST API on Azure Container Apps
  (one public HTTPS workshop URL); Flink `CONNECTION` + Java UDF pre-registered
  per environment.
* **Processing:** Flink produces two data products — `riverflow_payments` (4-way inner join + FX temporal join enrichment; completed payments) and `riverflow_payments_risk_score` (profile temporal join + risk UDF).
* **Serving/sink:** Tableflow on `riverflow_payments` (append) and `riverflow_payments_risk_score` (upsert) only, with Tableflow data TTL for right-to-forget.
* **Consumption:** Databricks/Genie (RiverPulse) answering the business questions above. Completion rate uses a Phase 1 proxy (completed with FX enrichment / initiated_enriched); stall drill-down is Phase 2. Customer exposure window is 24 hours.

### Optional components

* Light PII fields + brief CSFLE talking point.

### Phase 2 extensions

* Failed-payment paths, side-outputs, DLQ / invalid-schema fan-out.
* Progressive / stall-aware payment state (in-flight stage drill-down); progressive upsert deferred from Phase 1.
* Insufficient-funds and/or fraud branches.
* ISO 20022-inspired nested payload.
* `MATCH_RECOGNIZE` pattern detection (skipped for Elevate).
* Full CSFLE walkthrough; deeper Tableflow TTL labs if needed beyond the Phase 1 talking point.
* Evaluate Kafka Lightning Tables as an alternative/complement to Tableflow for real-time serving.
* Validate the design on Confluent Platform/Private Cloud beyond the parallel `cp-rosa` lite path.

## Downstream analytics experience (completed)

Participants use Databricks Genie AI to ask natural-language questions and get answers, for example:

1. Which customers have the highest risk in the last 24 hours? → ranked customer list by aggregated `risk_score`.
2. Which payments currently have the highest operational exception probability? → payment-level list with `risk_reason`.
3. What share of payments completed the full lifecycle? → Phase 1 completion rate proxy (`riverflow_payments` with FX enrichment / risk_score counts). Stall drill-down is Phase 2.

## Data streams

**Customer profile:** `customer_id`, `segment`, `account_tier`, `home_currency`, `country`, optional protected fields for CSFLE discussion.

**Payment event:** `payment_id`, `customer_id`, `source_account`, `destination_account`, `amount`, `currency` (USD, GBP, AUD, CAD, JPY, EUR), `payment_type`, `initiated_at`, `status`.

**FX rate (Postgres → CDC):** `currency_code`, `rate_to_usd`, `updated_at` (versioned for temporal join).

**Derived risk output:** `payment_id`, `risk_score`, `risk_reason`, `enrichment_timestamp` (from external risk UDF after profile TTJ).

## Proposed agenda (with time budget)

1. **Business framing (10 min):** real-time payments as an FSI priority; why low-latency movement matters; customer pressures around responsiveness, visibility, and modernization.
2. **Architecture walkthrough (10 min):** source systems, Kafka topics/event domains, CDC for profiles, Flink enrichment and derived products, Tableflow sinks, CP/CPC portability notes.
3. **Live demo flow (25 min):** seed profiles, generate initiation events, show CDC + streams in Kafka, run Flink to derive `risk_score`, materialize outputs, expose via Tableflow, show downstream consumer view.
4. **Technical discussion (10 min):** topic design, schema/governance, security and PII handling, Cloud-first vs. CP portability.
5. **Decision review (5 min):** validate open design choices with the FSI team; confirm Phase 1 vs. Phase 2.

## Open actions

Elevate / Phase 1 scope above is **locked**. Remaining build work:

- [x] FX rates: Postgres + ShadowTraffic + CDC upserts
- [x] Shared risk API + Flink UDF scaffolding (aws-demo host API; set `enable_risk_udf=true` after building JAR)
- [x] Azure instructor-led Terraform (shared + per-attendee); Flink/Tableflow manual
- [ ] Lab / Genie / deck / script alignment with new Flink patterns
- [x] Update sample payloads and architecture diagrams for FX + UDF

Historical Phoebe-sync items (datasets / NSF review) remain useful for Phase 2 narrative work; see `tmp/FSI_meeting.md`.

*Deferred (Phase 2):* failed-payment/DLQ paths; deeper CP/CPC beyond `cp-rosa` lite.

## Changelog from v1

* Resolved open decisions into a Phase 1 scope table (initially proposed).
* Set `risk_score` to operational exception probability (not fraud).
* Chose a generic instant-payments narrative with a rail-mapping note.
* Converted architecture brainstorm into required / optional / Phase 2 tiers.
* Added explicit business questions and time budgets.
* Completed the downstream Genie analytics section with three concrete prompts.
* Removed draft-only artifacts (duplicated "bonus section" notes and the informal CSFLE aside).
* Added open-actions checklist tying the Phoebe sync next steps to plan confirmation status.

## Changelog — Elevate Phase 1 lock (2026-07)

* Locked Phase 1 with stakeholder review: external risk UDF, FX temporal join, Tableflow TTL, instructor-led Azure delivery.
* Moved FX, UDF risk, Tableflow TTL, and instructor-led Azure out of Phase 2 into Phase 1.
* Explicit Phase 2: failed payments/DLQ, MATCH_RECOGNIZE skip for Elevate, stall drill-down, NSF/fraud, ISO nesting.
* Canonical lock mirrored in `AGENTS.md` and the Phase 1 runbook.


---

## Sources

- [FSI Payments Workshop Draft](https://docs.google.com/document/d/1sD1JD_TXJN3xKdzgkNYLqn9k_kMkPCSuJ42_eo3dFjI)
- Zoom meeting assets: `tmp/Meeting assets for FSI Payment Demo Sync are ready!.eml` (notes: `tmp/FSI_meeting.md`)

