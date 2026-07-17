# Slide 1: Real-Time Payments, Powered by Confluent
- Cloud-first workshop: from raw payment events to trusted, real-time operational signals
- Featuring CDC, Flink stream processing, and Tableflow
- RiverPay narrative (maps to FedNow/RTP-style flows)

---

# Slide 2: Payments Went Real-Time — Operations Must Too
- Partner banks expect instant money movement; RiverPay ops needs instant visibility
- Batch reporting can't answer "which payment needs attention right now?"
- This is an operational-visibility story, not another fraud demo

---

# Slide 3: Three Business Questions This Workshop Answers
- Which payments are most likely to need manual intervention right now?
- Which customers drive the highest operational exception exposure in the last 7 days?
- What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy; stall drill-down is backlog)

---

# Slide 4: A Four-Layer Real-Time Payments Pipeline
- Source: customer profiles in Postgres via CDC
- Stream: RiverFlow payment lifecycle events into Kafka
- Process: Flink — completed payments (4-way join) + operational risk_score (temporal join)
- Serve: Tableflow publishes governed tables to RiverPulse (Databricks Genie)

---

# Slide 5: The Payment Lifecycle We Demo
- Customer profile exists in Postgres
- Payment initiation → validation/authorization
- Balance update → status notification (success)
- Happy path only, for the cleanest first narrative

---

# Slide 6: CDC + Event Streaming = Complete Operational Picture
- Customer reference data flows in continuously via CDC — no batch export
- Payment events stream directly into Kafka as they happen
- ShadowTraffic generates demo-friendly profiles + lifecycle traffic

---

# Slide 7: Flink Data Products
- `riverflow_payments` — 4-way inner join (completed payments only, append)
- `riverflow_payments_risk_score` — temporal join initiation × profile (upsert)
- risk_score = operational exception probability (not fraud)
- Stall / in-flight stage drill-down deferred to Phase 2

---

# Slide 8: Tableflow — No Lakehouse Pipeline to Maintain
- Tableflow publishes the two Flink data products (not raw lifecycle topics)
- Delta Lake + Unity Catalog without custom ETL
- Marcus (data platform) gets governed tables; Dana (ops) gets Genie answers

---

# Slide 9: RiverPulse / Genie — Ask the Business Questions Live
- Highest exception-probability payments
- Highest-risk customers (last 7 days)
- Lifecycle completion rate (Phase 1 proxy; stall drill-down is backlog)

---

# Slide 10: Security Talking Point (Light Touch)
- Profiles include light PII fields
- Production: protect with CSFLE
- Not a full CSFLE lab in Phase 1

---

# Slide 11: Phase 1 vs Phase 2
- Phase 1: happy path, flat Avro payloads, completed-payments join + risk_score, demo mode (AWS)
- Phase 2: stall-aware / progressive payment state, NSF/fraud, ISO 20022 nesting, MATCH_RECOGNIZE, FX, full CSFLE, CP/CPC, self-service/instructor-led

---

# Slide 12: Recap + Next Steps
- RiverFlow streams + Flink data products + Tableflow + RiverPulse
- Reusable for Elevate / customer workshops
- Hands-on path: labs/demo LAB0–LAB4
