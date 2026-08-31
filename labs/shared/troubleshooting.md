# Shared Troubleshooting — RiverPay

Covers **demo** (`labs/demo` + `terraform/aws-demo`), **self-service BYO**
(`labs/self-service` + `terraform/aws` / `terraform/azure`), and
**instructor-led** (`labs/instructor-led` + `terraform/*-shared` / per-attendee + `*-lifecycle-st`).
Operator guide: [`docs/operator-instructor-led.md`](../../docs/operator-instructor-led.md)
(Azure-specific ACR notes: [`docs/operator-azure-elevate.md`](../../docs/operator-azure-elevate.md)).

## Most common (day of)

| Symptom | Fix |
|---------|-----|
| Apply fails looking up SQL warehouse | Set `databricks_sql_warehouse_name` in `terraform.tfvars` to the exact warehouse name in your workspace |
| Tables / views missing in Databricks | Tableflow cold start often needs **30–60+ minutes** before lakehouse/UC publish; check catalog integration + catalog/schema from outputs |
| Empty `riverflow_payments_risk_score` | Confirm ShadowTraffic + initiation + CDC profiles; wait 1–2 minutes for watermarks; instructor-led / self-service: confirm Risk API + UDF (below) |
| Empty / sparse `amount_usd` on completed payments | Confirm `riverflow.riverpay.fx_rates` CDC has rows; FX temporal join needs rates for the payment currency |

## Instructor-led (Azure) — Risk API / UDF

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `az acr build` fails during azure-shared | Azure CLI missing / wrong subscription | Install `az`, `az login` (or set `ARM_*`); confirm SP can create ACR |
| Risk API `/health` fails | Container App not ready / wrong URL | `terraform output -raw risk_api_health_url` from azure-shared; check Container App revision in Azure Portal |
| `/v1/risk` returns 401 | Bad or missing Bearer key | Use `terraform output -raw risk_api_key`; smoke: `services/risk-api/smoke.sh <endpoint> <key>` (bash script — run from Git Bash/WSL on Windows, or `curl` the endpoint directly from PowerShell) |
| Flink UDF returns errors / empty risk | CONNECTION endpoint wrong or timeout | `SHOW CONNECTIONS;` expect `riverpay_risk_api` with **HTTPS** shared URL; UDF timeout is 4s — re-check API latency; retry the smoke `SELECT` once or twice |
| UDF returns `0.28\|risk_api_error` | Client exception (timeout, DNS, TLS) | Soft-fail in `LookupOperationalRisk` — not a scored reason. Retry the Flink `SELECT`; smoke `/health` + `/v1/risk`; confirm CONNECTION endpoint + bearer `token` |
| UDF returns `0.28\|risk_api_http_401` (or other code) | Auth / HTTP failure | Match CONNECTION token to `risk_api_key` output; `risk_api_endpoint_missing` → CONNECTION not injected |
| First UDF smoke takes ~1 minute | Cold Flink + HTTPS | Expected; re-run should be faster. Hang >~2 min → CONNECTION / API |
| UDF not listed in `SHOW USER FUNCTIONS` | Pre-reg skipped | Set `shared_risk_api_endpoint` + JAR path; `enable_risk_udf=true`; re-apply attendee stack |

## Instructor-led (AWS) — Risk API / UDF

Unlike Azure (ACR + Container Apps HTTPS), AWS hosts the Risk API as a plain Docker
container on the shared Postgres EC2 host (`http://<host>:8089`) — no build/registry step.

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Risk API container not running | `docker run` failed on shared EC2 during aws-shared apply | SSH shared host (`terraform output -raw postgres_ssh_username`/`postgres_public_ip` from aws-shared); `sudo docker ps --filter name=risk-api`; `sudo docker logs risk-api` |
| Risk API unreachable from Confluent Cloud | Security group blocks 8089 | Confirm `allowed_cidr_blocks` on aws-shared includes Confluent Cloud egress / `0.0.0.0/0` for the workshop; `curl http://<host>:8089/health` from the host itself first |
| `/v1/risk` returns 401 | Bad or missing Bearer key | Use `terraform output -raw risk_api_key` from aws-shared; smoke: `services/risk-api/smoke.sh <endpoint> <key>` |
| Flink UDF returns errors / empty risk | CONNECTION endpoint wrong scheme | `SHOW CONNECTIONS;` expect `riverpay_risk_api` with a **plain HTTP** (not HTTPS) shared URL — using `https://` against the AWS EC2 endpoint will fail |
| UDF returns `0.28\|risk_api_*` | Soft-fail (timeout / HTTP / missing endpoint) | Same as Azure row above; smoke `http://<host>:8089/health` and `/v1/risk` with bearer key |
| First UDF smoke takes ~1 minute | Cold Flink + API | Expected; hang >~2 min → CONNECTION / Risk API container |
| UDF not listed in `SHOW USER FUNCTIONS` | Pre-reg skipped | Set `shared_risk_api_endpoint` + JAR path; `enable_risk_udf=true`; re-apply attendee stack |

## Demo / Self-service — Risk API / ShadowTraffic (BYO)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| AWS Risk API unreachable (demo or self-service) | EC2 SG / container down | `terraform output risk_api_url` (`terraform/aws-demo` or `terraform/aws`); SSH and `sudo docker ps` / `curl localhost:8089/health` |
| Azure self-service Risk API unreachable | Datagen VM / NSG / container | `terraform output risk_api_endpoint`; `terraform output datagen_ssh_command`; then `curl localhost:8089/health` / `sudo docker ps` |
| Azure self-service ST empty topics | Flexible Server SSL / ST container | SSH datagen; `sudo docker logs shadowtraffic-riverpay`; confirm Flexible Server firewall allows VM IP |

## Instructor-led (Azure / AWS) — ShadowTraffic / CDC fan-out

Cloud-agnostic — the `lifecycle-st` phase (`wsa build … --phases lifecycle-st`) and the
shared VM/EC2 Docker layout are identical on both clouds; only SSH user (`azureuser` vs `ec2-user`)
and the aggregator root (`terraform/azure-lifecycle-st` vs `terraform/aws-lifecycle-st`) differ.

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| No profiles / FX in shared Postgres | Shared ST not running | SSH shared VM/EC2; `sudo docker ps --filter name=shadowtraffic-riverpay`; check logs |
| CDC topics empty for one attendee | Connector / include list | Connector **Running**; include `riverpay.customer_profiles,riverpay.fx_rates`; host = shared Postgres IP |
| Lifecycle topics empty | Multi-cluster lifecycle ST missing | After `wsa build`, run the aggregator: `wsa build -w <spec> --run-id … --phases lifecycle-st`. On shared host: `sudo docker ps --filter name=shadowtraffic-lifecycle` |
| Lifecycle ST config errors | Kafka creds / Avro | `sudo docker logs shadowtraffic-lifecycle`; confirm `wsa-phase-inputs.auto.tfvars.json` (in the lifecycle-st phase dir) has bootstrap + SR keys |
| Leftover `shadowtraffic-lifecycle` after clean | Destroyed shared before lifecycle-st | `wsa clean` tears phases down in reverse order (lifecycle-st first); if orphaned: `sudo docker rm -f shadowtraffic-lifecycle` |
| Legacy `st-life-*` containers | Old per-attendee path | Specs set `enable_lifecycle_shadowtraffic: false`; remove leftovers with `sudo docker rm -f st-life-…` |

## Terraform / Docker (demo)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Docker cannot find AWS credentials | Creds not in env / `~/.aws` / `aws-config` | Export keys or run `aws configure` in the container |
| `terraform init` provider errors | Network / mirror | Retry with network; check Docker Desktop network |
| Apply fails on IAM trust update | AWS CLI missing or wrong account | Confirm container has `aws` CLI and correct account |
| Apply fails looking up SQL warehouse | Warehouse name mismatch | Set `databricks_sql_warehouse_name` in `terraform.tfvars` to your warehouse |
| Apply fails missing UDF JAR | `enable_risk_udf=true` but no dist JAR | Build per `udf/riverpay-risk/README.md` or set `enable_risk_udf=false` |

## PostgreSQL / CDC

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Wait-for-Postgres timeout | Host not reachable / SG/NSG | Confirm allowed CIDRs on 5432/22; check VM/instance status |
| No CDC records | Connector / publication | Check connector status in CC; verify `riverpay.customer_profiles` (and `fx_rates`) have rows |
| CDC topic wrong name | Prefix mismatch | Expect `riverflow.riverpay.customer_profiles` and `riverflow.riverpay.fx_rates` |

## ShadowTraffic (demo aws-demo)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| No payment events | Container not running / license | SSH to EC2 (`terraform/aws-demo/sshkey-*.pem`), then `sudo docker logs shadowtraffic-riverpay`; confirm license env file was copied |
| Profiles empty | Stage order / Postgres | Confirm stage 1 completed; check Postgres table count |
| Host `ssh -i` fails with `/workspace/...` | Used container `ssh_key_path` output | Use `./sshkey-*.pem` under `terraform/aws-demo` on the host (see LAB4) |

## Flink

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Empty `risk_score` | Watermark / no join / UDF | Confirm initiation + profile topics; Risk API; wait 1–2 minutes |
| Empty `riverflow_payments` | Incomplete lifecycle / FX miss | Need all four stages for same `payment_id` **and** FX rate for currency |
| Statement failed | Topic/schema not ready | Re-run after CDC healthy; check Flink statement exceptions |

## Tableflow / Databricks / Genie

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Tables missing in UC | Tableflow still `PENDING` / catalog not `CONNECTED` | Confirm Tableflow topics `RUNNING`; wait for UC schema. Demo apply polls up to ~90 min (Tableflow) + ~60 min (UC). Instructor-led: attendees enable Tableflow in LAB4. |
| Apply fails on `riverpulse_views` / `SCHEMA_NOT_FOUND` | UC publish lagged past the wait window | Check Tableflow + catalog in Confluent Cloud; re-apply views target once tables exist (demo) |
| Views missing | SQL statement retries exhausted | Re-run [`sql/riverpulse_views.sql`](../../sql/riverpulse_views.sql) manually in the workshop catalog.schema |
| Genie empty | No data / wrong space | Validate Flink + Tableflow first; attach the workshop catalog/schema to the Genie space |
| Destroy 409 on provider integration | Tableflow still holding integration (Confluent lag) | See [Provider integration 409](#provider-integration-409-on-destroy) below |

## Provider integration 409 on destroy

Same issue as [`workshop-tableflow-databricks`](https://github.com/confluentinc/workshop-tableflow-databricks/blob/main/labs/shared/troubleshooting.md): Confluent returns **409** when deleting a provider integration that Tableflow still references.

```
Error: error deleting provider integration "cspi-…": 409 Conflict
detail: "integration is being used in some confluent resource"
```

**Why:** Destroy order is topics → integration (via `depends_on`), but Confluent can lag after Tableflow disable. If 409 still happens:

1. Drop the integration from state (does **not** call Confluent DELETE — env teardown removes it):

   macOS / Linux / Git Bash:

   ```sh
   # Demo (AWS)
   cd terraform/aws-demo
   docker-compose run --rm terraform -c \
     "terraform state rm 'module.tableflow.confluent_provider_integration.aws[0]'"

   # Instructor-led (Azure) — adjust address from `terraform state list`
   cd terraform/azure
   terraform state rm '…provider_integration…'
   ```

   Windows (PowerShell — use a backtick for line continuation instead of `\`):

   ```powershell
   # Demo (AWS)
   cd terraform/aws-demo
   docker-compose run --rm terraform -c `
     "terraform state rm 'module.tableflow.confluent_provider_integration.aws[0]'"

   # Instructor-led (Azure) — adjust address from `terraform state list`
   cd terraform/azure
   terraform state rm '…provider_integration…'
   ```

2. Re-run destroy (`terraform destroy` or `wsa clean`).

3. If it still sticks, disable Tableflow on `riverflow_payments` / `riverflow_payments_risk_score` / `riverflow_customer_risk_exposure_24h` in the Confluent UI, then destroy again.

Azure instructor-led WSA sets `cleanup.disable_tableflow: true` in [`wsa-spec-azure.yaml`](../../wsa-spec-azure.yaml).

## Getting more help

- Azure / AWS instructor-led operator guide: [`docs/operator-instructor-led.md`](../../docs/operator-instructor-led.md)
- Azure Elevate notes (ACR / Container Apps): [`docs/operator-azure-elevate.md`](../../docs/operator-azure-elevate.md)
- Design runbook: [`context/fsi_payments_workshop_phase1_runbook.md`](../../context/fsi_payments_workshop_phase1_runbook.md)
- Genie prompts: [`sql/genie_prompts.md`](../../sql/genie_prompts.md)
- Lab indexes: [`labs/demo/README.md`](../demo/README.md), [`labs/self-service/README.md`](../self-service/README.md), [`labs/instructor-led/README.md`](../instructor-led/README.md)
