# Terraform AWS — RiverPay self-service

BYO AWS + Confluent Cloud + Databricks. Provisions the RiverPay pipeline
**without** auto-creating Flink MTs or enabling Tableflow topics.

Attendees complete Flink + Tableflow in [`labs/self-service/`](../../labs/self-service/).

## Defaults

| Flag | Default | Meaning |
|------|---------|---------|
| `enable_flink_mts` | `false` | ALTER + Risk UDF only; no `riverflow_payments` / risk MTs |
| `enable_tableflow_topics` | `false` | No Tableflow topic enablement / Genie views |
| `enable_shadowtraffic` | `true` | Profiles, FX, lifecycle → Kafka |
| `enable_risk_api` | `true` | Risk API on Postgres EC2 `:8089` |
| `enable_risk_udf` | `true` | Upload JAR + `CREATE CONNECTION` / FUNCTION |

For a fully automated demo, use [`../aws-demo`](../aws-demo/) instead.

## Usage

```bash
cd terraform/aws
cp sample-tfvars terraform.tfvars
# fill credentials — see labs/self-service/LAB1
docker-compose run --rm terraform -c "terraform init"
docker-compose run --rm terraform -c "terraform apply -auto-approve"
```

Requires UDF JAR: `udf/riverpay-risk/dist/riverpay-risk-udf-1.0.0.jar` (see UDF README).

Databricks **Free Edition** is allowed; Unity Catalog / Tableflow sync can be slower — see troubleshooting.
