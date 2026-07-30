# Change Log

## [v0.2.0] — 2026-07-28

Detailed author notes: [`context/elevate_2026_internal_changelog.md`](context/elevate_2026_internal_changelog.md).

### Added

- Azure instructor-led path: `terraform/azure-shared` + `terraform/azure`, `labs/instructor-led/`
- AWS instructor-led path: `terraform/aws-shared` + `wsa-spec-aws.yaml` (parity with Azure)
- Multi-cluster lifecycle ShadowTraffic: `terraform/modules/lifecycle-shadowtraffic`, `*-lifecycle-st` roots, `scripts/wsa-deploy-lifecycle-st.sh`
- Shared Risk Scoring API (`services/risk-api/`) + Flink Java UDF (`udf/riverpay-risk/`)
- Azure Container Apps HTTPS deployment for the shared Risk API
- FX rates CDC + Flink temporal join (`flink/fx_conversion.sql`, `amount_usd`)
- ShadowTraffic generator splits: postgres-only (shared) + kafka lifecycle (multi-connection aggregator)
- Tableflow data TTL / right-to-forget (demo TF + instructor-led LAB4)
- Internal Elevate changelog under `context/`
- WSA specs (`wsa-spec-azure.yaml`, `wsa-spec-aws.yaml`) + operator guide (`docs/operator-instructor-led.md`)
- Self-service path: `labs/self-service/`, `terraform/aws/` (MTs/Tableflow off), Azure BYO via empty `shared_*` (datagen VM: full ShadowTraffic + Risk API `:8089`; Elevate keeps shared Container Apps HTTPS)

### Changed

- Phase 1 scope: FX TTJ, external risk UDF, Tableflow TTL, instructor-led Azure + AWS (see `AGENTS.md`)
- ShadowTraffic image pinned to `2.0.3`; initiation `throttleMs` raised to 2500 for demo pacing
- Instructor-led lifecycle traffic: one `shadowtraffic-lifecycle` container × N Kafka connections (not N `st-life-*`)
- `enable_risk_udf` defaults to `true`; JAR path defaults to `udf/riverpay-risk/dist/`
- Completed-payments Flink product includes FX enrichment
- Risk scoring prefers external UDF over inline CASE (CASE remains fallback when UDF off)
- RiverPulse Q2 window: 7 days → **24 hours** (`riverpulse_customer_risk_24h`); Q3 proxy notes FX enrichment on completed payments
- Azure instructor-led: mount `confluent-flink-payments` for changelog/watermark ALTERs (MTs still off) — parity with AWS
- Instructor-led LAB2/LAB3: CDC verify-only wording; LAB3 verifies pre-applied ALTERs (no “ask the instructor”)

## v0.1.2 - 2026-07-16

### Changed

- ShadowTraffic license fetched automatically via HTTP free-trial env file (no `shadowtraffic_license` tfvar)

## v0.1.1 - 2026-07-15

### Changed

- Flink data products: `riverflow_payments` (4-way inner join, append) + `riverflow_payments_risk_score` (upsert)
- Tableflow publishes only those two products (raw lifecycle topics remain Kafka sources)
- Phase 2 backlog: progressive / stall-aware payment state; progressive upsert deferred
- Architecture, README, labs, Genie views, and AGENTS updated to match

## v0.1.0 - 2026-07-15

### Features

- Initial demo-mode workshop scaffold for RiverPay / RiverFlow / RiverPulse
- AWS Terraform root (`terraform/aws-demo`) with Confluent + Databricks modules
- ShadowTraffic generator for customer profiles and payment lifecycle events
- Flink temporal join → operational `risk_score` / `risk_reason`
- Tableflow + Unity Catalog + Genie prompt pack
- Demo labs LAB0–LAB4 and shared troubleshooting/recap
