# FSI Real-Time Payments Workshop — Plan (v2)

*Author: Kyle Klein · Status: Draft v2 · Cloud-first (Flink + Tableflow); CP/CPC portability is design intent, not yet validated*

## Summary

This plan describes a Cloud-first, happy-path real-time payments workshop and demo for financial services. Phase 1 is deliberately scoped to a small number of reliable "hero moments" so it is fast to build, easy to run within a workshop time box, and reusable/customizable for customers. Everything beyond the Phase 1 core is explicitly deferred to optional or Phase 2 to control scope.

## Working goal

Build a financial services workshop and demo that shows how Confluent can power a real-time payments pipeline with connectors, stream processing, governance-minded design, and downstream data products for analytics and operational visibility.

## Why this workshop matters

There is a gap in existing FSI demo coverage: the team has stronger fraud and market-data material but lacks a reusable real-time payments demo that can be spun up quickly and customized for customers. The workshop emphasizes business relevance, real-time movement and normalization of payment data, and a practical path from source systems to downstream consumption. It can also be reused for the Elevate 2026 DSP session.

## Phase 1 scope decisions (proposed — pending FSI team review)

These decisions resolve the open items from v1 so the build can start. They are Kyle's working recommendation, not yet confirmed with Phoebe's team (JT, Chunks) — treat as proposed until reviewed. Everything not on this list is Phase 2.

| Decision | v1 status | v2 proposed choice | Rationale |
|---|---|---|---|
| Storyline | Open (happy / +NSF / +fraud) | **Happy path only** | Simplest narrative, fastest to build, easiest for workshop timing |
| Payment rail | Open (RTP / FedNow / card / generic) | **Generic instant-payments model** with a "maps to FedNow/RTP-style flows" note | Keeps it reusable without rail-specific modeling |
| `risk_score` meaning | Open (fraud / confidence / sanctions / ops) | **Operational exception probability** | Delivers business value while avoiding "another fraud demo" |
| Payload complexity | Open (flat / ISO 20022 / hybrid) | **Flattened Avro + Schema Registry in Phase 1**, ISO 20022-inspired as Phase 2 | Keeps focus on streaming concepts; Avro enables Flink typed columns |
| PII / security depth | Open | **Light PII + brief CSFLE mention** | Adds FSI credibility without dominating the workshop |
| Flink hero technique | Multiple candidates | **Temporal join** as the required pattern; UDF/lookup optional | One reliable, business-visible enrichment |
| Topics | Open (one canonical vs many) | **Lifecycle-specific Kafka sources** + Flink `riverflow_payments` completed product | Cleaner mapping; completed join replaces optional canonical topic |
| Foreign exchange | Open | **Deferred to Phase 2** (single-currency in Phase 1) | Removes cross-currency complexity |

## Core workshop narrative

**RiverPay** (see `USECASE.md`) needs to process payment events in real time,
enrich them with customer and reference data, compute a payment-oriented risk
signal, and expose trusted outputs to downstream consumers for monitoring,
analytics, and action. The story is told in four layers:

* Ingest customer profile data from Postgres using CDC connectors.
* Stream RiverFlow payment events directly into Kafka using ShadowTraffic.
* Enrich and transform those streams with Flink — producing completed payments (`riverflow_payments`) and an operational `risk_score` data product.
* Publish governed downstream tables through Tableflow for Databricks Delta Lake / Unity Catalog (RiverPulse / Genie).

**Hands-on delivery (v1):** demo mode only — `labs/demo/` + `terraform/aws-demo/`.
Formalized topic names are in `AGENTS.md` and the Phase 1 runbook.

## Business questions the workshop answers

To keep the demo solution-led rather than feature-led, every section ties back to concrete business questions:

* Which payments are most likely to require manual intervention right now?
* Which customers drive the highest operational exception exposure in the last 7 days?
* What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy; stall drill-down is Phase 2)

## Suggested audience

Elevate attendees, FSI solution architects, platform engineers, data engineering teams, and technical decision makers evaluating Cloud now and CP/CPC later.

## Workshop outcomes

By the end, attendees should understand:

* How Confluent supports a real-time payment lifecycle from initiation through status notification.
* How CDC plus event streaming creates a complete operational picture across customer and payment domains.
* How Flink enriches payment events (via temporal join) and derives higher-value data products such as `risk_score`.
* How Tableflow exposes append and upsert outputs for downstream analytics use cases.

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

* **Source/generation:** ShadowTraffic generates ~100 customer profile records in Postgres (to demonstrate CDC) plus payment/transaction activity associated to those customers.
* **Streaming:** Kafka topics for payment initiation, authorization, balance update, and status events (sources only).
* **Processing:** Flink produces two data products — `riverflow_payments` (4-way inner join of lifecycle stages; completed payments only) and `riverflow_payments_risk_score` (temporal join initiation × profile).
* **Serving/sink:** Tableflow on `riverflow_payments` (append) and `riverflow_payments_risk_score` (upsert) only.
* **Consumption:** Databricks/Genie (RiverPulse) answering the business questions above. Completion rate uses a Phase 1 proxy (completed / initiated_enriched); stall drill-down is Phase 2.

### Optional components

* External UDF or key-search lookup from Postgres (or simulated).
* Light PII fields + brief CSFLE talking point.

### Phase 2 extensions

* Progressive / stall-aware payment state (in-flight stage drill-down); progressive upsert deferred from Phase 1.
* Insufficient-funds and/or fraud branches.
* ISO 20022-inspired nested payload.
* `MATCH_RECOGNIZE` pattern detection and foreign-exchange/cross-currency lookup.
* Materialized tables and Tableflow Data TTL deep dive.
* Evaluate Kafka Lightning Tables as an alternative/complement to Tableflow for real-time serving.
* Validate the design on Confluent Platform/Private Cloud (CP/CPC portability is currently asserted as design intent, not demonstrated).
* Self-service / instructor-led delivery modes; Azure parity.

## Downstream analytics experience (completed)

Participants use Databricks Genie AI to ask natural-language questions and get answers, for example:

1. Which customers have the highest risk in the last 7 days? → ranked customer list by aggregated `risk_score`.
2. Which payments currently have the highest operational exception probability? → payment-level list with `risk_reason`.
3. What share of payments completed the full lifecycle? → Phase 1 completion rate proxy (`riverflow_payments` / risk_score counts). Stall drill-down is Phase 2.

## Data streams

**Customer profile:** `customer_id`, `segment`, `account_tier`, `home_currency`, `country`, optional protected fields for CSFLE discussion.

**Payment event:** `payment_id`, `customer_id`, `source_account`, `destination_account`, `amount`, `currency`, `payment_type`, `initiated_at`, `status`.

**Derived risk output:** `payment_id`, `risk_score`, `risk_reason`, `enrichment_timestamp`.

## Proposed agenda (with time budget)

1. **Business framing (10 min):** real-time payments as an FSI priority; why low-latency movement matters; customer pressures around responsiveness, visibility, and modernization.
2. **Architecture walkthrough (10 min):** source systems, Kafka topics/event domains, CDC for profiles, Flink enrichment and derived products, Tableflow sinks, CP/CPC portability notes.
3. **Live demo flow (25 min):** seed profiles, generate initiation events, show CDC + streams in Kafka, run Flink to derive `risk_score`, materialize outputs, expose via Tableflow, show downstream consumer view.
4. **Technical discussion (10 min):** topic design, schema/governance, security and PII handling, Cloud-first vs. CP portability.
5. **Decision review (5 min):** validate open design choices with the FSI team; confirm Phase 1 vs. Phase 2.

## Open actions (pending FSI team review)

From the FSI Payment Demo Sync with Phoebe. Full meeting notes and checklist live in `tmp/FSI_meeting.md`.

- [x] Kyle: collect / organize meeting notes and share with Phoebe for review *(this repo / plan v2)*
- [x] Kyle: assess Tableflow for the demo *(included in Phase 1 required components)*
- [ ] Phoebe: draft flow + example datasets (initiation, validation/authorization, balance update, status) for team feedback
- [ ] Phoebe: after vacation (~July 10), review happy path vs. NSF/fraud paths with JT and Chunks before development proceeds
- [ ] Confirm Phase 1 scope table above with FSI team (closes "proposed" status)

*Deferred (already Phase 2):* Kyle investigate CP/CPC port via Kubernetes repo — see Phase 2 extensions.

## Changelog from v1

* Resolved all open decisions and open questions into a single Phase 1 scope table (proposed, pending FSI team review).
* Set `risk_score` to operational exception probability (not fraud).
* Chose a generic instant-payments narrative with a rail-mapping note.
* Converted architecture brainstorm into required / optional / Phase 2 tiers.
* Added explicit business questions and time budgets.
* Completed the downstream Genie analytics section with three concrete prompts.
* Removed draft-only artifacts (duplicated "bonus section" notes and the informal CSFLE aside).
* Added open-actions checklist tying the Phoebe sync next steps to plan confirmation status.


---

## Sources

- [FSI Payments Workshop Draft](https://docs.google.com/document/d/1sD1JD_TXJN3xKdzgkNYLqn9k_kMkPCSuJ42_eo3dFjI)
- Zoom meeting assets: `tmp/Meeting assets for FSI Payment Demo Sync are ready!.eml` (notes: `tmp/FSI_meeting.md`)

