# RiverPay Instant Payments Workshop — Stakeholder Brief

*Author: Kyle Klein · Status: Proposed for feedback · ~10-minute read*

This brief describes a proposed Confluent Cloud workshop/demo for **real-time
instant payments** in financial services. It is intentionally scoped for Phase
1: a happy-path story that is fast to build, easy to run in a workshop time
box, and reusable for customer conversations (including Elevate 2026 DSP).

**Please comment inline or reply with feedback on the questions at the end.**
Nothing here is locked until the FSI team reviews it.

---

## Why this exists

The FSI team has strong fraud and market-data demo material, but lacks a
reusable **real-time payments** demo that can be spun up quickly and customized
for customers. Instant payments is a priority conversation for many FSI
accounts; this workshop fills that gap without becoming “another fraud demo.”

---

## The story: RiverPay

Rather than saying “a financial institution,” the workshop uses a fictitious
company so the narrative is concrete and memorable.

**RiverPay** is a mid-size instant-payments processor based in Kansas City. It
does not run a retail bank. It sits behind ~40 regional banks and credit
unions and gives their end customers instant money movement — payments
infrastructure for banks that do not want to build that infrastructure
themselves.

### Company vs product (important naming)

| Name | What it is | Analogy |
|---|---|---|
| **RiverPay** | The company | The processor / business |
| **RiverFlow** | RiverPay’s instant-payments product | The “rail” — the path a payment travels |
| **RiverPulse** | RiverPay’s real-time ops & analytics experience | “Ask what’s happening right now” |

**What “rail” means here:** in payments, a rail is the network/path money
moves on (e.g. FedNow, RTP, ACH). RiverFlow is a *fictitious* rail-like
product that **maps to FedNow/RTP-style flows**. It is not claiming to be a
real, certified rail. That keeps the workshop reusable without rail-specific
modeling.

```text
RiverPay (company)
├── RiverFlow  — instant-payments rail (lifecycle events in Kafka)
└── RiverPulse — ops visibility (Tableflow + Databricks Genie)
```

### Who cares (personas)

- **Dana Ruiz, VP of Payment Operations** — “Which payments need a human right now?”
- **Marcus Chen, Head of Data Platform** — “Can we get trusted data to analytics without building/maintaining custom pipelines?”
- **Priya Anand, Compliance & Risk** — light PII / CSFLE talking point only (not a full security deep dive)

---

## The business problem

Partner banks want instant-payments parity with large nationals. RiverPay’s
ops tooling is still batch-oriented (end-of-day completed vs. failed reports).
Between report runs, the team is flying blind: they cannot answer *which
payment needs attention right now*.

This is an **operational visibility** story. The workshop’s `risk_score` is
**operational exception probability** (“how likely is Dana’s team going to
need to touch this?”), paired with a human-readable `risk_reason` — **not** a
fraud score.

### Three questions the demo answers

1. Which RiverFlow payments are most likely to need manual intervention right now?
2. Which customers drive the highest operational exception exposure in the last 7 days?
3. What is the RiverFlow lifecycle completion rate from initiation to completed status? (Phase 1 proxy; stall drill-down is Phase 2)

---

## How it works (happy path)

One successful payment moves through four stages:

1. Customer profile already exists in Postgres (RiverPay’s system of record).
2. **Initiation** event enters Kafka.
3. **Authorization** (validation) event is produced.
4. **Balance update** event is produced.
5. **Status** notification confirms successful completion.

Behind the scenes, Confluent Cloud:

1. **CDC** streams customer profiles from Postgres into Kafka.
2. **ShadowTraffic** generates the payment lifecycle events (demo data).
3. **Flink** temporally joins profile × payment activity to produce `risk_score`.
4. **Tableflow** materializes append (payments) and upsert (`risk_score`) tables.
5. **Databricks Genie** (RiverPulse) answers the business questions in natural language.

Topic naming: Kafka streams use the `riverflow.*` prefix; company-owned
Postgres schema uses `riverpay` (`riverpay.customer_profiles`). The Flink
risk output topic/table is `riverflow_payments_risk_score`.

---

## Architecture (Phase 1)

See the authoritative diagram in
[`fsi_payments_workshop_architecture.md`](fsi_payments_workshop_architecture.md).
Summary: ShadowTraffic → Postgres CDC + RiverFlow lifecycle topics → Flink
temporal join (`riverflow_payments_risk_score`) → Tableflow → Unity Catalog →
RiverPulse / Genie.

Formalized topic names:

| Resource | Name |
|----------|------|
| CDC | `riverflow.riverpay.customer_profiles` |
| Lifecycle sources | `riverflow.payments.{initiation,authorization,balance_update,status}` |
| Completed payments MT | `riverflow_payments` (append) |
| Risk MT | `riverflow_payments_risk_score` (upsert) |

**Phase 1 is Confluent Cloud only.** CP/CPC portability is design intent for
later, not demonstrated yet.

---

## Phase 1 scope (proposed)

| Decision | Proposed choice | Why |
|---|---|---|
| Storyline | Happy path only | Fastest to build; clean workshop narrative |
| Payment model | Generic instant-payments (maps to FedNow/RTP-style) | Reusable; no rail-specific modeling |
| `risk_score` | Operational exception probability + `risk_reason` | Business value without becoming a fraud demo |
| Payloads | Flattened JSON | Keep focus on streaming concepts |
| Security | Light PII + brief CSFLE mention | Credibility without a security deep dive |
| Flink pattern | Temporal join (profile × payment) | One reliable, visible enrichment |
| Topics | Lifecycle-specific (+ optional canonical) | Maps cleanly to the event sequence |
| Currency | Single currency (USD) | Defers FX complexity |

**Explicitly Phase 2 (not in the first build):** NSF / fraud branches, ISO
20022 nested payloads, FX / cross-currency, Lightning Tables evaluation,
CP/CPC validation.

---

## What we want from you

Please react to any of the following — even a quick “agree / change this” is
enough:

1. **Narrative fit** — Does RiverPay / RiverFlow / RiverPulse land well for
   customer conversations, or should we stay more generic?
2. **Happy path only** — OK for Phase 1, or do you need an NSF/fraud branch
   in v1?
3. **`risk_score` as ops exception probability** — Right framing, or should
   it lean closer to fraud / sanctions / confidence?
4. **Cloud-first** — Agree that CP/CPC is a later port, or is on-prem
   demonstration required sooner?
5. **Downstream** — Is Databricks + Genie the right “RiverPulse” experience
   for your audiences, or do you need alternate sinks called out?
6. **Anything missing** for a first customer-facing workshop?

---

## Related detail (optional deeper reading)

| Doc | Contents |
|---|---|
| `USECASE.md` | Full RiverPay narrative and naming rationale |
| `context/fsi_payments_workshop_plan_v2.md` | Plan of record, agenda, Phase 1/2 split |
| `context/fsi_payments_workshop_architecture.md` | Architecture diagram + legend |
| `context/fsi_payments_workshop_sample_payloads.md` | Example JSON for each topic/table |
| `context/fsi_payments_workshop_phase1_runbook.md` | Build / run / teardown steps |
