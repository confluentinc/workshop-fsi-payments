# Elevate 2026 — Internal Implementation Changelog

**Audience:** Workshop authors / facilitators (Kyle + collaborators).  
**Not** a public release notes file — see root [`CHANGELOG.md`](../CHANGELOG.md) for customer-facing semver bullets when cutting a version.

**Branch / workstream:** Elevate Phase 1 expansions (FX TTJ, risk UDF, Tableflow TTL, Azure instructor-led), driven by stakeholder review (Jeremy, Ahmed Zamzam, Satakshi Raj) and the Ahmed sync.

**Last updated:** 2026-07-27

---

## Why this file exists

Root `CHANGELOG.md` is intentionally terse (features/changed/fixed per tag). This document is the **working memory** for the Elevate delta: decisions, what landed where, defaults, known gaps, and operator notes. Prefer editing here when the implementation story changes; fold a short summary into `CHANGELOG.md` only at release.

Related authoritative docs:

| Doc | Role |
|-----|------|
| [`AGENTS.md`](../AGENTS.md) | Locked Phase 1 scope + delivery paths |
| [`fsi_payments_workshop_plan_v2.md`](fsi_payments_workshop_plan_v2.md) | Plan of record |
| [`fsi_payments_workshop_phase1_runbook.md`](fsi_payments_workshop_phase1_runbook.md) | Build / run / teardown |
| Root [`CHANGELOG.md`](../CHANGELOG.md) | Public release log |

Scratch sources (not authoritative): `tmp/stakeholder_slack_thread.txt`, `tmp/kyle_ahmed_sync.txt`.

---

## Stakeholder decisions captured

| Decision | Outcome |
|----------|---------|
| Pre-provision vs over-automate | Pre-provision infra; attendees write Flink MTs + enable Tableflow |
| Risk scoring | Swap inline CASE → **external Risk Scoring API + Java UDF** |
| FX | **Temporal join** to CDC FX rates; currencies GBP, AUD, CAD, JPY, EUR (+ USD) |
| Tableflow | Enable **data TTL / right-to-forget** talking point |
| `MATCH_RECOGNIZE` | Skip for Elevate Phase 1 |
| Failed payments / DLQ | Phase 2 |
| Cloud roots | Keep **aws-demo**; add **Azure instructor-led** patterned on workshop-tableflow-databricks (`azure-shared` + per-attendee `azure`) |
| Risk API URL | **One shared HTTPS URL** for the workshop; Flink CONNECTION + UDF pre-created; attendees only call the UDF |
| FX updates | ShadowTraffic → Postgres → CDC upserts ~every 5s; rates realistic, often unchanged |
| Genie | Expected *shape*, not brittle golden rows |
| Private UDF endpoints | **AWS-only**; Azure Elevate must use **public HTTPS** |

---

## Delivery modes (after this work)

| Mode | Labs | Terraform | Flink MTs / Tableflow |
|------|------|-----------|------------------------|
| **Demo** | `labs/demo/` | `terraform/aws-demo/` | Automated |
| **Instructor-led Elevate** | `labs/instructor-led/` | `terraform/azure-shared/` + `terraform/azure/` | **Manual** (labs) |

CDC fan-out (instructor-led): shared generators write **Postgres**; **per-attendee CDC** fans out profiles/FX. Lifecycle Kafka events use **one multi-connection ShadowTraffic** (`terraform/*-lifecycle-st`, N Kafka connections × 4 generators) via the `lifecycle-st` WSA phase (`wsa build … --phases lifecycle-st`) — not N per-attendee containers.

---

## Changelog by theme

### 1. Scope & narrative docs

**Updated:** `AGENTS.md`, `USECASE.md`, `README.md`, `labs/shared/recap.md`,  
`context/fsi_payments_workshop_plan_v2.md`, `phase1_runbook.md`, `architecture.md`,  
`facilitator_script.md`, `sample_payloads.md` (partial).

**Substance:**

- Phase 1 now includes FX TTJ, external risk UDF, Tableflow TTL, Azure instructor-led path.
- Formal topics: add `riverflow.riverpay.fx_rates`; completed payments gain `amount_usd` via FX join.
- Risk = operational exception probability via shared API + UDF (CASE remains fallback when UDF disabled).
- Deck (`fsi_payments_workshop_deck.md`) **not fully refreshed** — still pre-Elevate in places (deferred).

---

### 2. FX rates (Postgres → CDC → Flink TTJ)

| Area | Change |
|------|--------|
| Postgres seed | `riverpay.fx_rates` in aws-demo + azure-shared cloud-init |
| ShadowTraffic | `fx_rates` updater (~5s); multi-currency payment amounts in full generator |
| CDC include-list | `riverpay.customer_profiles,riverpay.fx_rates` |
| Flink | `flink/fx_conversion.sql`; aws-demo Flink module completed-payments MT includes FX TTJ + `amount_usd` |

---

### 3. Risk Scoring API + Flink UDF

| Path | Purpose |
|------|---------|
| `services/risk-api/` | FastAPI `GET/POST /v1/risk`, `/health`; optional Bearer `RISK_API_KEY` |
| `services/risk-api/smoke.sh` | Operator HTTPS/local smoke (`/health` + `/v1/risk`) |
| `udf/riverpay-risk/` | Java `LookupOperationalRisk`; returns `risk_score\|risk_reason` |
| `udf/riverpay-risk/dist/riverpay-risk-udf-1.0.0.jar` | Built artifact (Maven via Aliyun mirror when Central times out) |
| `flink/risk_udf.sql` | MT pattern using UDF |
| aws-demo `risk-api.tf` | Runs API on Postgres EC2 `:8089` (demo convenience, HTTP) |
| azure-shared `risk-api.tf` | **ACR + Azure Container Apps**, public **HTTPS** workshop URL |
| Flink module | Optional artifact + `CREATE CONNECTION riverpay_risk_api` + `CREATE FUNCTION lookup_operational_risk` |

**Defaults (2026-07-27):**

- `enable_risk_udf = true` (aws-demo + azure instructor-led).
- JAR path default: `../../udf/riverpay-risk/dist/riverpay-risk-udf-1.0.0.jar`.
- UDF HTTP client timeout: **2000 ms** (HTTPS RTT to Container Apps).
- Azure UDF pre-reg still requires `shared_risk_api_endpoint` set (HTTPS from azure-shared output).
- aws-demo Risk API remains HTTP on EC2; Elevate uses Container Apps HTTPS.

**Operator smoke (after azure-shared apply):**

```bash
cd terraform/azure-shared
../../services/risk-api/smoke.sh \
  "$(terraform output -raw risk_api_endpoint)" \
  "$(terraform output -raw risk_api_key)"
```

Requires `az login` on the apply host for `az acr build`.

---

### 4. Tableflow TTL

- Demo TF (`confluent-tableflow-payments`): `data_retention_ms` (30-day min) + snapshot `retention_ms` (7-day).
- Instructor-led LAB4: UI steps to set data TTL / right-to-forget talking point.

---

### 5. Azure instructor-led Terraform

#### `terraform/azure-shared/` (once per workshop)

- Ported/adapted from workshop-tableflow-databricks: RG, VNet, ADLS, Postgres VM, Databricks connector.
- RiverPay cloud-init (`customer_profiles` + `fx_rates`).
- Risk API on **Container Apps (HTTPS)** — replaced earlier VM `:8089` approach.
- ShadowTraffic **postgres-only** container `shadowtraffic-riverpay` (profiles + FX → shared Postgres).
- Monitoring templates updated from leftover `datagen` → `shadowtraffic-riverpay`.
- Provider registrations set to `all` (needed for Microsoft.App / ACR).

#### `terraform/azure/` (per attendee)

- Confluent + Flink + CDC + lifecycle topics; **no** auto Flink MTs / Tableflow (`enable_flink_mts` / `enable_tableflow_topics` forced false).
- **`module.flink_payments`**: changelog.mode + watermarks on CDC + lifecycle (same as AWS); `enable_risk_udf=false` in-module so Azure-specific CONNECTION/UDF resources stay authoritative.
- Optional Risk CONNECTION + UDF pre-reg when endpoint + JAR present.
- **Lifecycle ShadowTraffic** (`shadowtraffic.tf`): optional emergency/debug per-attendee kafka-only ST (`enable_lifecycle_shadowtraffic`, default **false**). Instructor-led uses `terraform/azure-lifecycle-st` via the `lifecycle-st` WSA phase (one multi-Kafka container). Note: the `enable_lifecycle_shadowtraffic` flag gates *this* per-attendee container and is independent of the aggregator phase — the phase reads the always-emitted `lifecycle_st_cluster` output, so it carries no `enabled_var`.

#### Generator split (`shadowtraffic/`)

| File | Role |
|------|------|
| `riverpay-generator.json` | aws-demo / BYO full (Postgres + Kafka) |
| `riverpay-generator-postgres.json` | *-shared profiles + FX |
| `riverpay-generator-kafka.json` | lifecycle template (expanded × N by `lifecycle-shadowtraffic` module) |

---

### 6. Instructor-led labs

**Added:** `labs/instructor-led/` LAB1–LAB6 (first pass):

1. Claim account  
2. Explore environment  
3. Flink (FX TTJ + risk UDF)  
4. Tableflow + TTL  
5. Genie / RiverPulse  
6. Wrap-up  

**Not done:** `labs/demo/` still lag Elevate narrative (no FX/UDF/TTL lab updates).

---

## File inventory (new / major)

```
services/risk-api/          # FastAPI + Dockerfile + smoke.sh
udf/riverpay-risk/          # Java UDF + dist JAR + settings.xml (Aliyun)
flink/fx_conversion.sql
flink/risk_udf.sql
labs/instructor-led/        # LAB1–LAB6
shadowtraffic/riverpay-generator-postgres.json
shadowtraffic/riverpay-generator-kafka.json
terraform/azure-shared/     # Shared Elevate infra
terraform/azure/            # Per-attendee Elevate root (+ modules/)
terraform/aws-shared/       # Instructor-led AWS shared
terraform/aws-lifecycle-st/ # Multi-cluster lifecycle ST (AWS)
terraform/azure-lifecycle-st/
terraform/modules/lifecycle-shadowtraffic/
wsa-spec-aws.yaml
docs/operator-instructor-led.md
terraform/aws-demo/risk-api.tf
```

---

## Defaults cheat sheet

| Variable | aws-demo | azure-shared | azure (attendee) |
|----------|----------|--------------|------------------|
| `enable_risk_api` | true (EC2 HTTP) | true (Container Apps HTTPS) | n/a (consumes shared URL) |
| `enable_risk_udf` | **true** | n/a | **true** (needs endpoint) |
| `enable_shadowtraffic` | true (full) | true (postgres-only) | n/a |
| `enable_lifecycle_shadowtraffic` | n/a | n/a | **false** (use `*-lifecycle-st` aggregator) |
| `enable_flink_mts` | true (via module) | n/a | **false** (ALTERs still via `flink_payments`) |
| `enable_tableflow_topics` | true | n/a | **false** (guard) |

---

## Known gaps / follow-ups (as of 2026-07-27)

### Documentation completed this pass

- Root `CHANGELOG.md` `[Unreleased]` section + link here
- README architecture mermaid (FX, risk API/UDF, TTL) + Elevate lab table
- Deck refreshed for FX / UDF / TTL / dual delivery paths
- Facilitator pre-flight + beats updated for Elevate + demo
- `flink/risk_score.sql` watermark comments clarified
- Demo / instructor-led README cross-links

### Still open

1. **Live smoke** — checklist in `docs/operator-instructor-led.md` / `docs/operator-azure-elevate.md`.
2. **Azure self-service ShadowTraffic** — **addressed**: BYO datagen VM runs full ST + Risk API `:8089`; Elevate keeps shared ACA HTTPS.
3. **Instructor-led lab polish (Ahmed 2026-07-29)**
   - **Addressed:** Azure mounts `confluent-flink-payments` for changelog/watermark ALTERs (MTs still off); LAB3 no longer “ask the instructor”; LAB2 clarifies CDC is pre-provisioned.
   - **Deferred:** Attendee-created CDC connector (keep Terraform-provisioned until timing from Ahmed).
   - **Addressed (docs):** reused dispenser / used-env guidance in operator guide + LAB1.
4. **Promote `[Unreleased]` → `v0.2.0`** when cutting a release.
5. **Optional:** Azure Flexible Server SSL quirks for ShadowTraffic postgres connection — validate on first apply; add `sslmode` if needed.

### WSA stage_paths fix (2026-07-28)

- `wsa-spec-azure.yaml`: stage `services/risk-api/`, `shadowtraffic/`, `udf/riverpay-risk/dist/` so local-copy `wsa build` can hash/upload those paths from azure-shared / azure.
- `azure-shared` azurerm: `resource_provider_registrations = "core"` + App/ACR/Insights/Databricks (avoid `"all"` / DataMigration timeout).
- `azure-shared` ST remote-exec: use `pgadmin` (`var.postgres_db_username`); `set -eu` not `pipefail` (Ubuntu `/bin/sh` = dash).
- `azure-shared` SSH outputs: `abspath(...)` so WSA per-account `file(shared_postgres_ssh_private_key_path)` resolves (key lives under `azure-shared/`, not `azure/`).
- Flink REST `CREATE CONNECTION`: use `'token'` (bearer) not `'api-key'` — matches Risk API auth + current CC allowed types.
- Elevate lifecycle ST: `--metrics-port 0` so host-network containers don't collide with shared ST on Prometheus `:9400`.
- Flink `CREATE FUNCTION … USING CONNECTIONS`: connection name is an identifier (backticks), not a string literal.

### Azure BYO datagen VM (2026-07-27)

- `terraform/azure/datagen-vm.tf` — VNet/NSG/VM when `!use_shared`
- Risk API collocated on VM (HTTP); removed BYO Container Apps path
- Full `riverpay-generator.json` ST → Flexible Server + attendee Kafka
- Elevate shared unchanged (Container Apps HTTPS + shared ST VM)

### Self-service added (2026-07-27)

- `labs/self-service/` LAB0–LAB6 (signup → IL-shaped Flink/Tableflow/Genie → destroy)
- `terraform/aws/` from aws-demo with `enable_flink_mts` / `enable_tableflow_topics` default **false**; module `enable_materialized_tables`
- Risk API: Postgres host HTTP + UDF on AWS; **Azure BYO** datagen VM HTTP `:8089`; **Elevate** shared Container Apps HTTPS
- Databricks Free Edition allowed
- Azure BYO: Flexible Server + datagen VM (full ST + Risk API); Elevate: shared ST VM + ACA

### P1 completed this pass (2026-07-27)

- `wsa-spec-azure.yaml` (account_count: 2 dry-run default)
- `docs/operator-azure-elevate.md` (build/clean, shared injection map, smoke checklist, teardown)
- azure-shared outputs: `postgres_ssh_private_key_path` / `postgres_ssh_username` for WSA `TF_VAR_shared_*`
- `labs/shared/troubleshooting.md` Elevate Risk API / ST / FX sections
- Genie prompts: `amount_usd` / FX optional prompt
- LAB2 UDF smoke `SELECT` + CONNECTION check
- Instructor-led README → operator guide link

### Intentionally deferred (Phase 2 / stakeholder)

- `MATCH_RECOGNIZE`, NSF/fraud/DLQ, ISO 20022 nesting, full CSFLE walkthrough, stall-aware progressive state.

---

## How to update this file

When landing more Elevate work:

1. Add a dated subsection under the relevant theme (or a new `## YYYY-MM-DD` dump at the bottom if cross-cutting).
2. Keep **Known gaps** honest.
3. At release time, add **one short bullet group** to root `CHANGELOG.md` (e.g. `v0.2.0 — Elevate Phase 1 expansions`) and link here for detail.
