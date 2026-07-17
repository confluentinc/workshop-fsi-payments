# Change Log

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
