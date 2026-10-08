# Generator demo overlay — Current SF 2026

**Additive changes to the stock ShadowTraffic generator ([`../../../shadowtraffic/riverpay-generator.json`](../../../shadowtraffic/riverpay-generator.json)).**
Do **not** edit the workshop generators in place — apply these as an overlay (jq merge) or copy to a
`*-demo.json` variant, so the workshop labs keep working.

Both items below are **optional** — the current Video 3 narrative (exception-probability by `segment`)
needs neither. Add them only if we want a literal "by partner bank" slice or a "stuck" drill-down.

---

## 1. `partner_bank` field (for a "by partner bank" slice)

Add to the `payment_initiation` generator **value** and its Avro schema hint:

```jsonc
// value block
"partner_bank": {
  "_gen": "oneOf",
  "choices": [
    "Cascade Credit Union", "Granite State Bank", "Harbor Point Financial",
    "Meridian Trust", "Northwind Savings", "Sierra Community Bank",
    "Summit Federal", "Tidewater Bank"
  ]
}
```

```jsonc
// avroSchemaHint → value → fields (append)
{ "name": "partner_bank", "type": "string" }
```

> Alternative with zero generator change: derive a partner bank from `customer_id` in Flink SQL
> (a lookup table / CASE), or just slice by `segment` (already present). Prefer this if we want to
> avoid touching the generator at all.

## 2. Partial / "stuck" lifecycles (for `flink/stuck_payments.sql`)

Today every initiation **forks once** onto all four stages (`oneTimeKeys` + `maxEvents: 1`), so every
payment completes. To create stalled payments, make a fraction of initiations **not** fork to
`payment_status` (and optionally not to `authorization`):

- Easiest: a second, small initiation generator stream whose keys are **excluded** from the
  status fork (e.g. a separate `payment_id` prefix like `PMT-STUCK-*` that the status generator's
  lookup does not match).
- TODO: confirm the cleanest ShadowTraffic pattern (fork-on-lookup with a filtered key set) —
  see https://docs.shadowtraffic.io/fork/key/#forking-on-a-lookup and `oneTimeKeys`.
- Keep the stuck fraction small (e.g. ~5%) so the happy-path volume still dominates.

---

## Applying as an overlay (non-destructive)

```sh
# Example: merge an additive fragment onto the stock generator without editing it.
jq -s '.[0] * .[1]' \
  ../../../shadowtraffic/riverpay-generator.json \
  generator-demo-fragment.json \
  > /tmp/riverpay-generator-demo.json
```

(Author `generator-demo-fragment.json` here if we proceed — left out until item 1/2 are confirmed needed.)
