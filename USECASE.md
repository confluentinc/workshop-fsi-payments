# RiverPay — Fictitious FSI Use Case Narrative

This document gives the workshop a concrete company to tell the story about,
instead of "a financial institution." It's meant to be dropped into the deck,
facilitator script, and runbook wherever they currently say generic phrases
like "a financial institution processes payments." It does not change any
locked/proposed Phase 1 scope decisions in `context/fsi_payments_workshop_plan_v2.md`
— it's a narrative skin on top of that scope.

## Naming rationale

"River" was the required starting point. Other options considered, kept here
in case this needs revisiting or a sub-brand is useful later:

| Name | Read |
|---|---|
| **RiverPay** *(selected)* | Short, modern, unambiguously a payments company. |
| RiverStone Financial | General-purpose, stability-coded — better fit for a broad retail bank story than a payments-specific one. |
| Riverbend Payments | Payments-specific; "bend" nods at flow/movement, slightly softer than RiverPay. |
| Confluence Bank | Plays on "confluence" (where rivers merge) as a metaphor for streams converging in real time — clever, but reads as an in-joke referencing the vendor's own name, so it's better suited to an internal-only version than a customer-facing one. |

Sub-brand names for RiverPay's own products (useful for slide/script flavor,
optional to use):

- **RiverFlow** — RiverPay's instant-payments rail/service (the four-stage lifecycle).
- **RiverPulse** — RiverPay's real-time operations and analytics experience (the Genie-powered "ask a question, get an answer" layer).

## Company profile

**RiverPay** is a fictitious mid-size instant-payments processor. It doesn't
operate its own retail bank; instead, it's the technology and rails layer that
sits behind a network of ~40 regional banks and credit unions, giving their
customers instant money movement without each bank having to build FedNow/RTP
connectivity itself. Think "payments infrastructure for banks that don't want
to build payments infrastructure."

- **HQ / footprint:** Kansas City, MO — a deliberately unglamorous, credible
  regional-processor location (not NYC/SF), reinforcing the "serves community
  banks" story.
- **Customers:** ~40 partner banks and credit unions, each bringing their own
  end customers (the "customer profile" data in the demo represents these
  end customers, sourced from RiverPay's Postgres system of record).
- **Products:**
  - **RiverFlow** — the instant-payments rail. Generic instant-payments
    model that "maps to FedNow/RTP-style flows" (per the locked narrative
    choice) without claiming to literally be FedNow or RTP — RiverPay is a
    fictitious processor, not a real-world payment rail.
  - **RiverPulse** — the operational visibility layer partner banks use to
    answer "what's happening with payments right now," which is exactly the
    gap this workshop's Flink + Tableflow + Genie stack fills.

## Business problem (why RiverPay needs this)

RiverPay's partner banks are pushing hard for instant-payments parity with
the big national banks, but RiverPay's current operational tooling is
batch-based: end-of-day reports on completed vs. failed payments, no
real-time signal on payments that are stuck or likely to need a human. As
instant-payments volume grows, RiverPay's ops team is flying blind between
report runs — exactly the gap called out in the workshop's core narrative
("batch reporting can't answer 'which payment needs attention right now?'").

This is deliberately an **operational-visibility story, not a fraud story** —
consistent with the existing `risk_score` framing as operational exception
probability, not a fraud score.

## Personas

Useful if the facilitator script wants a "who are we solving this for" beat:

- **Dana Ruiz, VP of Payment Operations** — owns the question "which
  payments need manual intervention right now?" Currently pulls a stale
  end-of-day report and reacts after the fact.
- **Marcus Chen, Head of Data Platform** — owns getting trusted, governed
  data into the hands of analytics without building and maintaining custom
  pipelines to Databricks. Cares about Tableflow's "no pipeline to build or
  maintain" pitch.
- **Priya Anand, Compliance & Risk Lead** — the audience for the light-PII /
  CSFLE talking point. Wants assurance that customer data is protected
  without derailing the demo into a full security deep dive.

## Mapping the workshop onto RiverPay

| Workshop element | RiverPay framing |
|---|---|
| Customer profile (Postgres → CDC) | RiverPay's partner-bank end customers: `customer_id`, `segment`, `account_tier`, `home_currency`, `country`. |
| Payment event (Kafka lifecycle topics) | A RiverFlow instant payment moving through initiation → authorization → balance update → status. |
| `risk_score` / `risk_reason` (Flink temporal join) | RiverPulse's operational exception signal — "how likely is Dana's team going to need to touch this payment." |
| Tableflow append + upsert tables | The trusted data products behind RiverPulse. |
| Databricks Genie | The natural-language front end of RiverPulse — Dana or Marcus just asks a question instead of waiting on a report. |
| Three business questions (plan_v2) | Reframed as: *"Which RiverFlow payments need Dana's team right now? Which partner-bank customers are driving the most exposure this week? Where in the lifecycle are payments stalling?"* |

## Guardrails

- Stay inside the current Phase 1 scope in `plan_v2.md` (proposed, pending
  FSI team review): happy path only, single currency, generic instant-payments
  rail, light PII + CSFLE talking point only. This narrative doesn't imply
  any scope expansion.
- Don't describe RiverFlow as literally FedNow or RTP — it "maps to" that
  style of rail, matching the existing locked narrative language, to avoid
  implying RiverPay is a real, certified rail participant.
- If this narrative gets adopted, the deck/script/runbook/labs should use
  RiverPay/RiverFlow/RiverPulse (and personas as needed). Demo-mode labs,
  README, deck, facilitator script, and Phase 1 runbook have been updated
  accordingly; keep them consistent when editing.
