# FSI Real-Time Payments Workshop — Phase 1 Architecture

Matches the Phase 1 runbook, formalized topic names in `AGENTS.md`, and the
demo Terraform product under `terraform/aws-demo/`.

**Flink data products (Tableflow sinks):**
- `riverflow_payments` — 4-way inner join of lifecycle stages (completed only, append)
- `riverflow_payments_risk_score` — initiation × profile temporal join (upsert)

Raw lifecycle topics remain Kafka sources only (not Tableflow-enabled in Phase 1).
Progressive / stall-aware payment state is Phase 2 backlog.

```mermaid
flowchart LR
    ST["ShadowTraffic"]
    PG[("Postgres<br/>riverpay.customer_profiles")]

    subgraph SRC["Source Systems"]
        ST
        PG
    end

    CDC["Postgres CDC<br/>Source Connector"]
    T_CDC["riverflow.riverpay.customer_profiles"]
    T_INIT["riverflow.payments.initiation"]
    T_AUTH["riverflow.payments.authorization"]
    T_BAL["riverflow.payments.balance_update"]
    T_STAT["riverflow.payments.status"]
    T_PAY[("riverflow_payments<br/>completed / append")]
    T_RISK[("riverflow_payments_risk_score<br/>upsert")]
    FLINK_PAY{{"Flink<br/>4-way inner join"}}
    FLINK_RISK{{"Flink<br/>Temporal Join → risk_score"}}
    TF_PAY["Tableflow append"]
    TF_RISK["Tableflow upsert"]

    subgraph CC["Confluent Cloud — Phase 1"]
        CDC
        subgraph TOPICS["Kafka Sources"]
            T_CDC
            T_INIT
            T_AUTH
            T_BAL
            T_STAT
        end
        subgraph PRODUCTS["Flink Data Products"]
            FLINK_PAY
            FLINK_RISK
            T_PAY
            T_RISK
        end
        subgraph TF["Tableflow"]
            TF_PAY
            TF_RISK
        end
    end

    DL[("Delta Lake /<br/>Unity Catalog")]
    GENIE["RiverPulse / Genie"]

    subgraph DBX["Databricks"]
        DL
        GENIE
    end

    ST --> PG
    ST --> T_INIT
    ST --> T_AUTH
    ST --> T_BAL
    ST --> T_STAT

    PG --> CDC --> T_CDC

    T_CDC --> FLINK_RISK
    T_INIT --> FLINK_RISK
    FLINK_RISK --> T_RISK

    T_INIT --> FLINK_PAY
    T_AUTH --> FLINK_PAY
    T_BAL --> FLINK_PAY
    T_STAT --> FLINK_PAY
    FLINK_PAY --> T_PAY

    T_PAY --> TF_PAY
    T_RISK --> TF_RISK

    TF_PAY --> DL
    TF_RISK --> DL
    DL --> GENIE
```

## Notes

- Happy path only; single currency (USD); flattened Avro payloads (+ Schema Registry).
- `riverflow_payments` emits only when all four lifecycle stages match (`payment_id`).
- Risk hero joins **initiation × customer profile** (temporal) for operational `risk_score` / `risk_reason`.
- Genie completion rate Phase 1 proxy: `completed` (`riverflow_payments`) / `initiated_enriched` (`riverflow_payments_risk_score`).
- Downstream views: `riverpulse_high_risk_payments`, `riverpulse_customer_risk_7d`, `riverpulse_lifecycle_completion`.
- **Phase 2 backlog:** progressive or stall-aware payment state (in-flight stage drill-down). Progressive upsert deferred.
