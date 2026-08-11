# Slide 1: Real-Time Payments, Powered by Confluent
- Cloud-first workshop: from raw payment events to trusted, real-time operational signals
- Featuring CDC, Flink stream processing, Tableflow, and an external risk UDF
- RiverPay narrative (maps to FedNow/RTP-style flows)
- Delivery: **demo** (AWS, automated), **self-service** (BYO, you write Flink + Tableflow), or **instructor-led Elevate** (Azure, attendees write Flink + Tableflow)

---

# Slide 2: Payments Went Real-Time — Operations Must Too
- Partner banks expect instant money movement; RiverPay ops needs instant visibility
- Batch reporting can't answer "which payment needs attention right now?"
- This is an operational-visibility story, not another fraud demo

---

# Slide 3: Three Business Questions This Workshop Answers
- Which payments are most likely to need manual intervention right now?
- Which customers drive the highest operational exception exposure in the last 24 hours?
- What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy: completed = 4-way join + FX enrichment; stall drill-down is backlog)

---

# Slide 4: A Four-Layer Real-Time Payments Pipeline
- Source: customer profiles **and FX rates** in Postgres via CDC
- Stream: RiverFlow payment lifecycle events into Kafka (multi-currency)
- Process: Flink — completed payments (4-way join + **FX temporal join**) + operational risk_score (**profile TTJ + external risk UDF**)
- Serve: Tableflow publishes governed tables to RiverPulse (Databricks Genie), with **data TTL / right-to-forget**

---

# Slide 5: The Payment Lifecycle We Demo
- Customer profile exists in Postgres; FX rates update continuously
- Payment initiation → validation/authorization
- Balance update → status notification (success)
- Happy path only, for the cleanest first narrative

---

# Slide 6: CDC + Event Streaming = Complete Operational Picture
- Customer reference data + FX rates flow in continuously via CDC — no batch export
- Payment events stream directly into Kafka as they happen
- ShadowTraffic generates demo-friendly profiles, FX updates, and lifecycle traffic
- Elevate: shared Postgres ST fans out via per-attendee CDC; lifecycle ST is per Kafka cluster

---

# Slide 7: Flink Data Products
- `riverflow_payments` — 4-way inner join + FX TTJ → `rate_to_usd` / `amount_usd` (append)
- `riverflow_payments_risk_score` — profile temporal join + **lookup_operational_risk** UDF (one row per payment)
- `riverflow_customer_risk_exposure_24h` — trailing-24h `OVER` aggregate per customer (genuine upsert)
- risk_score = operational exception probability (not fraud), with human-readable `risk_reason`
- Shared Risk Scoring API: one workshop HTTPS URL; CONNECTION + UDF pre-registered
- Stall / in-flight stage drill-down deferred to Phase 2

---

# Slide 8: Tableflow — No Lakehouse Pipeline to Maintain
- Tableflow publishes the three Flink data products (not raw lifecycle topics)
- Delta Lake + Unity Catalog without custom ETL
- **Data TTL** on Tableflow topics — right-to-forget / retention talking point
- Marcus (data platform) gets governed tables; Dana (ops) gets Genie answers

---

# Slide 9: RiverPulse / Genie — Ask the Business Questions Live
- Highest exception-probability payments
- Highest-risk customers (last 24 hours)
- Lifecycle completion rate (Phase 1 proxy: 4-way join + FX; stall drill-down is backlog)
- Expect the *shape* of answers; avoid brittle golden-row checks in Elevate

---

# Slide 10: Security Talking Point (Light Touch)
- Profiles include light PII fields
- Production: protect with CSFLE
- Tableflow TTL for retention / right-to-forget
- Not a full CSFLE lab in Phase 1

---

# Slide 11: Phase 1 vs Phase 2
- Phase 1: happy path, flat Avro, FX TTJ, risk UDF, Tableflow TTL; **demo (AWS)** + **self-service (BYO)** + **instructor-led Elevate (Azure)**
- Phase 2: stall-aware / progressive payment state, NSF/fraud/DLQ, ISO 20022 nesting, MATCH_RECOGNIZE, full CSFLE, deeper CP/CPC

---

# Slide 12: Delivery Paths
- **Demo:** `labs/demo/` + `terraform/aws-demo` — full pipeline automated
- **Self-service (BYO):** `labs/self-service/` + `terraform/aws` / `terraform/azure` — you sign up; write Flink MTs and enable Tableflow yourself
- **Elevate instructor-led:** `labs/instructor-led/` + `azure-shared` / `azure` — pre-provisioned; attendees write Flink MTs and enable Tableflow
- **Confluent Platform on ROSA (parallel):** `labs/cp-rosa/` — CFK + Control Center; no Flink / Tableflow / Databricks yet
- Same RiverPay narrative and topic names across the Confluent Cloud paths

---

# Slide 13: Recap + Next Steps
- RiverFlow streams + Flink data products (FX + risk UDF) + Tableflow TTL + RiverPulse
- Reusable for Elevate / customer workshops
- Hands-on: demo LAB0–LAB4, self-service LAB0–LAB6, or instructor-led LAB1–LAB6
