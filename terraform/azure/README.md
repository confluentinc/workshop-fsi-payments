# Azure per-attendee — RiverPay instructor-led **or** self-service

## Modes

| Mode | How | Data gen / Risk API |
|------|-----|---------------------|
| **Instructor-led** | Fill `shared_*` from `azure-shared` | Shared ST VM + shared Container Apps HTTPS |
| **Self-service (BYO)** | Leave `shared_*` empty | **Datagen VM**: full ShadowTraffic + Risk API `:8089` HTTP |

## Automated (both modes)

- Confluent Cloud env + Kafka (Azure) + Flink compute pool
- Tableflow provider integration + Azure identity for ADLS
- CDC → profiles + FX
- Lifecycle Kafka topics
- Risk CONNECTION + UDF when endpoint + JAR are available
- Flink MTs / Tableflow topics: **not** auto-created (labs)

## Self-service BYO extras

When `shared_*` is empty:

1. Flexible Server Postgres (CDC source)
2. Small **datagen VM** (Docker) running:
   - ShadowTraffic → Flexible Server (profiles/FX) + this Kafka cluster (lifecycle)
   - Risk Scoring API on `:8089`
3. Flink UDF CONNECTION points at `http://<datagen-ip>:8089`

```bash
cd terraform/azure
cp sample-tfvars terraform.tfvars
# leave shared_* empty; set Confluent/Databricks/Azure creds
terraform init && terraform apply
terraform output risk_api_endpoint
terraform output datagen_ssh_command
```

## Instructor-led usage

Set `shared_*` from `azure-shared` outputs (see [`docs/operator-azure-elevate.md`](../../docs/operator-azure-elevate.md)). Lifecycle ST runs on the shared Postgres VM; Risk API is the shared Container Apps HTTPS URL.

Labs: [`labs/self-service/`](../../labs/self-service/) or [`labs/instructor-led/`](../../labs/instructor-led/).
