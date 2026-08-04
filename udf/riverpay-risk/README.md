# RiverPay Risk UDF (Confluent Cloud Flink)

Java scalar UDF that calls the shared Risk Scoring API and returns
`risk_score|risk_reason` for Flink SQL to split.

- Class: `io.confluent.riverpay.udf.LookupOperationalRisk`
- Connection prefix: `riverpay_risk_api` (must match `CREATE FUNCTION … USING CONNECTIONS`)

## Build

```bash
cd udf/riverpay-risk
docker run --rm -v "$PWD":/ws -w /ws maven:3.9-eclipse-temurin-11 \
  mvn -s settings.xml -q -DskipTests package
mkdir -p dist && cp -f target/riverpay-risk-udf-1.0.0.jar dist/
```

HTTP client timeout is 4s (HTTPS RTT to Azure Container Apps / Confluent egress).

## Register (per Confluent environment)

```sql
CREATE CONNECTION IF NOT EXISTS riverpay_risk_api
WITH (
  'type' = 'rest',
  'endpoint' = 'https://<shared-risk-api-host>',
  'token' = '<workshop-api-key>'
);

CREATE FUNCTION IF NOT EXISTS lookup_operational_risk
  AS 'io.confluent.riverpay.udf.LookupOperationalRisk'
  USING JAR 'confluent-artifact://<artifact-id>'
  USING CONNECTIONS (`riverpay_risk_api`);
```

See `flink/risk_udf.sql` for the materialized-table pattern.
