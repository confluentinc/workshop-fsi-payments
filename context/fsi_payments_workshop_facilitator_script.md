# FSI Real-Time Payments Workshop — Facilitator Script

*Cloud-first happy-path demo · ~60 minutes · Flink + Tableflow · RiverPay / RiverFlow / RiverPulse*

## How to use this script

Each section lists: a time budget, what you (facilitator) do and say, what participants do, and the expected result on screen. Spoken lines are guidance, not a word-for-word teleprompter — adapt to your audience.

Hands-on path for attendees: `labs/demo/` (LAB0–LAB4) for demo mode, or
`labs/instructor-led/` (LAB1–LAB6) for Elevate. Design details: `context/` +
`AGENTS.md`. Elevate implementation notes:
`context/elevate_2026_internal_changelog.md`.

## Pre-flight (before attendees arrive)

### Demo mode (AWS)

* Prefer a completed `terraform apply` in `terraform/aws-demo` (LAB2) so live demo focuses on observe + Genie.
* Confirm CDC topics `riverflow.riverpay.customer_profiles` and `riverflow.riverpay.fx_rates`, plus four lifecycle topics, have traffic.
* Confirm Flink MTs `riverflow_payments` (completed, with `amount_usd`) and `riverflow_payments_risk_score` have rows.
* Confirm Risk API healthy and UDF path active (`enable_risk_udf=true` default).
* Databricks catalog + RiverPulse views ready; Genie prompts from `sql/genie_prompts.md` bookmarked.

### Elevate instructor-led (Azure)

* `azure-shared` applied: shared Postgres ST running, Risk API HTTPS smoke OK (`services/risk-api/smoke.sh`).
* Per-attendee `azure` applied: CDC + lifecycle ST + risk CONNECTION/UDF pre-registered; Flink MTs / Tableflow **not** auto-created.
* Credential distribution ready for LAB1 claim.

### Shared

* Have `labs/shared/troubleshooting.md` open as fallback.
* Remember: Phase 1 completion rate is a proxy; stall drill-down is backlog.

---

## 1. Business framing — 10 min

**You do:** Open on the business problem, not the architecture. Introduce **RiverPay**.

**You say:** "RiverPay sits behind dozens of regional banks and credit unions. Payments have gone real-time — customers expect instant movement, and ops needs instant visibility. Today I'll show how we take raw RiverFlow payment events, enrich them the moment they happen, and turn them into a trusted RiverPulse signal that tells the business which payments need attention — all without batch jobs."

**You frame the three questions the demo will answer:**
* Which payments are most likely to need manual intervention right now?
* Which customers drive the highest operational exception exposure in the last 24 hours?
* What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy: completed = 4-way join + FX enrichment — stall drill-down is backlog)

**Participants do:** Listen; optionally share their current payments pain points.

**Expected result:** Audience understands this is an operational-visibility story, not a fraud demo.

---

## 2. Architecture walkthrough — 10 min

**You do:** Walk the four-layer story: source → stream → process → serve.

**You say:** "Customer profiles and FX rates live in Postgres and flow in via CDC. Payment events stream into Kafka across initiation, authorization, balance update, and status. Flink builds two data products: completed payments via a four-way inner join plus an FX temporal join for USD-normalized amounts, and an operational `risk_score` via a profile temporal join plus an external risk UDF — exception probability, not fraud. Tableflow publishes those two products to Unity Catalog (with a right-to-forget / TTL talking point) so Genie can answer questions live."

**You say (profile vs payment):** "`segment` and `account_tier` live on the customer profile, not on the payment. The payment carries amount and currency; we temporal-join the profile at initiation time to feed those attributes into the risk UDF — that's the enrichment pattern, not denormalizing segment onto every payment event."

**You say (portability note):** "This is Cloud-first. The same design is intended to run on Confluent Platform and Private Cloud too — worth noting for anyone planning Cloud now, CP/CPC later." *(Internal note: CP/CPC hasn't been built or validated yet — don't imply it's been demonstrated if a customer presses for specifics.)*

**Participants do:** Ask clarifying questions on topic design.

**Expected result:** Everyone can name the four layers before the live demo.

---

## 3. Live demo — 25 min

**You do:** Tour Confluent Cloud (CDC + lifecycle topics + Flink risk table + Tableflow), then Databricks Genie.

**Beat A — CDC + ShadowTraffic (5 min):** Show profiles **and FX rates** landing; mention ShadowTraffic as the generator. On Elevate, call out shared Postgres → per-attendee CDC fan-out.

**Beat B — Flink data products (8 min):** Show `riverflow_payments` (completed + `amount_usd`) and `riverflow_payments_risk_score`; call out a high `risk_score` with readable `risk_reason` from the **external UDF**. Note stall drill-down is Phase 2.

**Beat C — Tableflow TTL + CSFLE (3 min):** Point at Tableflow data TTL / right-to-forget; light PII + "in production we'd protect these with CSFLE — not walking through it today."

**Beat D — RiverPulse / Genie (9 min):** Ask the three prompts; optionally show SQL views as backup. Elevate: judge answer *shape*, not golden rows.

**Participants do:** Follow along in their own demo env if running labs, or watch facilitator screen.

**Expected result:** All three questions answered from trusted tables.

---

## 4. Recap + Phase 2 tease — 10 min

**You do:** Close on outcomes and what's deliberately out of scope.

**You say:** "You saw ingest, stream, enrich, and serve — ending in Genie answers ops can act on. Phase 2 can add NSF/fraud branches, richer ISO-style payloads, pattern detection (`MATCH_RECOGNIZE`), and deeper security labs. Today stayed intentionally happy-path — with FX conversion and an external risk lookup — so the story is reliable."

**Expected result:** Audience leaves with a clear Phase 1 vs Phase 2 mental model.

---

## Recovery cues

* No CDC data → check connector + Postgres; see troubleshooting doc
* Empty risk table → confirm ShadowTraffic + Risk API + UDF CONNECTION; wait 1–2 minutes
* First `lookup_operational_risk` smoke test slow → normal cold path (~1 min); past ~2 min → CONNECTION / Risk API
* Smoke/`risk_reason` shows `risk_api_error` / `risk_api_http_*` → soft-fail from UDF (timeout, bad token, API down); not a real score — smoke the shared Risk API
* Empty `amount_usd` / FX join misses → confirm `riverflow.riverpay.fx_rates` CDC + watermarks
* "Is risk an upsert?" → clarify: *profiles* (and FX) are upsert CDC sources for TTJ; initiation is append; Phase 1 risk MT is one enrichment per initiation (often append changelog). Diagram "upsert" means Tableflow framing of current risk per `payment_id` — verify with `SHOW CREATE TABLE` if challenged
* Genie empty → wait for Tableflow sync; fall back to SQL views
* Destroy/apply issues → LAB4 (demo) or operator azure teardown + shared troubleshooting
