# Azure shared — RiverPay Elevate

Provisions **once** per workshop run. Patterned on workshop-tableflow-databricks
`terraform/azure-shared`, adapted for RiverPay (profiles + FX rates + Risk API).

## Owns

- Resource group, VNet/NSG, ADLS Gen2
- Postgres VM (Docker) with `riverpay.customer_profiles` + `riverpay.fx_rates`
- Shared Databricks access connector + external location
- **Risk Scoring API on Azure Container Apps (public HTTPS)** — one workshop URL
- **ShadowTraffic (postgres-only)** — seeds/updates profiles + FX; CDC fans out per attendee

## Data fan-out

| Writer | Destination | Who consumes |
|--------|-------------|--------------|
| Shared ST (`shadowtraffic-riverpay`) | Postgres profiles + FX | Per-attendee CDC connectors |
| Per-attendee ST (`terraform/azure`) | That attendee's Kafka lifecycle topics | That attendee's Flink |

## Risk API (HTTPS)

When `enable_risk_api = true` (default):

1. Creates ACR + Container Apps Environment + Container App
2. Runs `az acr build` from `services/risk-api/` (Azure CLI required on the apply host)
3. Exposes `https://<fqdn>/v1/risk` with Bearer `risk_api_key`

### Smoke test

```bash
terraform output -raw risk_api_endpoint
../../services/risk-api/smoke.sh "$(terraform output -raw risk_api_endpoint)" "$(terraform output -raw risk_api_key)"
```

## ShadowTraffic smoke

```bash
ssh -i "$(terraform output -raw private_key_path)" azureuser@"$(terraform output -raw postgres_public_ip)" \
  'sudo docker ps --filter name=shadowtraffic-riverpay; sudo docker exec postgres-workshop psql -U postgres -d workshop -c "SELECT count(*) FROM riverpay.customer_profiles; SELECT * FROM riverpay.fx_rates;"'
```

## Usage

```bash
cd terraform/azure-shared
cp sample-tfvars terraform.tfvars
az login   # required for ACR build
terraform init && terraform apply
terraform output
```

Pass into per-attendee `terraform/azure`:

- `shared_resource_group_name`, storage/*, `shared_postgres_public_ip`, DB passwords
- `shared_postgres_ssh_private_key_path` = `private_key_path` output
- `shared_risk_api_endpoint` / `shared_risk_api_key`

## Elevate note

Flink UDF private endpoints are **AWS-only**. Azure Elevate must use the
**public HTTPS** Container Apps URL for `CREATE CONNECTION`.
