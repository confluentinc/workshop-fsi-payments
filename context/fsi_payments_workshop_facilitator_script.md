# FSI Real-Time Payments Workshop — Facilitator Script

*Cloud-first happy-path demo · ~60 minutes · Flink + Tableflow · RiverPay / RiverFlow / RiverPulse*

## How to use this script

Each section lists: a time budget, what you (facilitator) do and say, what participants do, and the expected result on screen. Spoken lines are guidance, not a word-for-word teleprompter — adapt to your audience.

Hands-on path for attendees: `labs/demo/` (LAB0–LAB4). Design details: `context/` + `AGENTS.md`.

## Pre-flight (before attendees arrive)

* Prefer a completed `terraform apply` in `terraform/aws-demo` (LAB2) so live demo focuses on observe + Genie.
* Confirm CDC topic `riverflow.riverpay.customer_profiles` and four lifecycle topics have traffic.
* Confirm Flink MTs `riverflow_payments` (completed) and `riverflow_payments_risk_score` have rows.
* Databricks catalog + RiverPulse views ready; Genie prompts from `sql/genie_prompts.md` bookmarked.
* Have `labs/shared/troubleshooting.md` open as fallback.
* Remember: Phase 1 completion rate is a proxy; stall drill-down is backlog.

---

## 1. Business framing — 10 min

**You do:** Open on the business problem, not the architecture. Introduce **RiverPay**.

**You say:** "RiverPay sits behind dozens of regional banks and credit unions. Payments have gone real-time — customers expect instant movement, and ops needs instant visibility. Today I'll show how we take raw RiverFlow payment events, enrich them the moment they happen, and turn them into a trusted RiverPulse signal that tells the business which payments need attention — all without batch jobs."

**You frame the three questions the demo will answer:**
* Which payments are most likely to need manual intervention right now?
* Which customers drive the highest operational exception exposure in the last 7 days?
* What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy — stall drill-down is backlog)

**Participants do:** Listen; optionally share their current payments pain points.

**Expected result:** Audience understands this is an operational-visibility story, not a fraud demo.

---

## 2. Architecture walkthrough — 10 min

**You do:** Walk the four-layer story: source → stream → process → serve.

**You say:** "Customer profiles live in Postgres and flow in via CDC. Payment events stream into Kafka across initiation, authorization, balance update, and status. Flink builds two data products: completed payments via a four-way inner join, and an operational `risk_score` via a temporal join to the customer profile — exception probability, not fraud. Tableflow publishes those two products to Unity Catalog so Genie can answer questions live."

**You say (portability note):** "This is Cloud-first. The same design is intended to run on Confluent Platform and Private Cloud too — worth noting for anyone planning Cloud now, CP/CPC later." *(Internal note: CP/CPC hasn't been built or validated yet — don't imply it's been demonstrated if a customer presses for specifics.)*

**Participants do:** Ask clarifying questions on topic design.

**Expected result:** Everyone can name the four layers before the live demo.

---

## 3. Live demo — 25 min

**You do:** Tour Confluent Cloud (CDC + lifecycle topics + Flink risk table + Tableflow), then Databricks Genie.

**Beat A — CDC + ShadowTraffic (5 min):** Show profiles landing; mention ShadowTraffic as the generator collaborators know.

**Beat B — Flink data products (8 min):** Show `riverflow_payments` (completed only) and `riverflow_payments_risk_score`; call out a high `risk_score` with readable `risk_reason`. Note stall drill-down is Phase 2.

**Beat C — CSFLE talking point (2 min):** Point at light PII fields; "in production we'd protect these with CSFLE — not walking through it today."

**Beat D — RiverPulse / Genie (10 min):** Ask the three prompts; optionally show SQL views as backup.

**Participants do:** Follow along in their own demo env if running labs, or watch facilitator screen.

**Expected result:** All three questions answered from trusted tables.

---

## 4. Recap + Phase 2 tease — 10 min

**You do:** Close on outcomes and what's deliberately out of scope.

**You say:** "You saw ingest, stream, enrich, and serve — ending in Genie answers ops can act on. Phase 2 can add NSF/fraud branches, richer ISO-style payloads, pattern detection, and deeper security labs. Today stayed intentionally happy-path so the story is reliable."

**Expected result:** Audience leaves with a clear Phase 1 vs Phase 2 mental model.

---

## Recovery cues

* No CDC data → check connector + Postgres; see troubleshooting doc
* Empty risk table → confirm ShadowTraffic + watermarks; wait 1–2 minutes
* Genie empty → wait for Tableflow sync; fall back to SQL views
* Destroy/apply issues → LAB4 + shared troubleshooting
