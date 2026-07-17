# Shared Troubleshooting — RiverPay Demo

## Most common (day of)

| Symptom | Fix |
|---------|-----|
| Apply fails looking up SQL warehouse | Set `databricks_sql_warehouse_name` in `terraform.tfvars` to the exact warehouse name in your workspace |
| Tables / views missing in Databricks | Tableflow cold start often needs **30–60+ minutes** before S3/UC publish; apply now polls Tableflow `RUNNING` then UC tables. Check catalog integration + `demo_status` catalog/schema |
| Empty `riverflow_payments_risk_score` | Confirm ShadowTraffic is running on EC2 and initiation + CDC profile topics have data; wait 1–2 minutes for watermarks |

## Terraform / Docker

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Docker cannot find AWS credentials | Creds not in env / `~/.aws` / `aws-config` | Export keys or run `aws configure` in the container |
| `terraform init` provider errors | Network / mirror | Retry with network; check Docker Desktop network |
| Apply fails on IAM trust update | AWS CLI missing or wrong account | Confirm container has `aws` CLI and correct account |
| Apply fails looking up SQL warehouse | Warehouse name mismatch | Set `databricks_sql_warehouse_name` in `terraform.tfvars` to your warehouse |

## PostgreSQL / CDC

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Wait-for-Postgres timeout | EC2 not reachable / SG | Confirm `0.0.0.0/0` or your IP on 5432/22; check instance status |
| No CDC records | Connector / publication | Check connector status in CC; verify `riverpay.customer_profiles` has rows |
| CDC topic wrong name | Prefix mismatch | Expect `riverflow.riverpay.customer_profiles` |

## ShadowTraffic

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| No payment events | Container not running / license | SSH to EC2 (host path `terraform/aws-demo/sshkey-*.pem`), then `sudo docker logs shadowtraffic-riverpay`; confirm license env file was copied and free-trial URL is reachable from Terraform |
| Profiles empty | Stage order / Postgres | Confirm stage 1 completed; check Postgres table count |
| Host `ssh -i` fails with `/workspace/...` | Used container `ssh_key_path` output | Use `./sshkey-*.pem` under `terraform/aws-demo` on the host (see LAB4) |

## Flink

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Empty `risk_score` | Watermark / no join matches | Confirm initiation + profile topics have data; wait 1–2 minutes |
| Statement failed | Topic/schema not ready | Re-apply or restart Flink statement after CDC is healthy |

## Tableflow / Databricks / Genie

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Tables missing in UC | Tableflow still `PENDING` / catalog not `CONNECTED` | Confirm Tableflow topics `RUNNING` and S3 has Delta under the bucket; wait for UC schema=`kafka_cluster_id`. Terraform polls up to ~90 min (Tableflow) + ~60 min (UC tables). |
| Apply fails on `riverpulse_views` / `SCHEMA_NOT_FOUND` | UC publish lagged past the wait window | Check Tableflow + catalog in Confluent Cloud; re-apply `-target=null_resource.riverpulse_views` once tables exist |
| Views missing | SQL statement retries exhausted | Re-run [`sql/riverpulse_views.sql`](../../sql/riverpulse_views.sql) manually in the workshop catalog.schema |
| Genie empty | No data / wrong space | Validate Flink + Tableflow first; attach the workshop catalog/schema to the Genie space |
| Destroy 409 on provider integration | Tableflow still holding integration (Confluent lag) | See [Provider integration 409](#provider-integration-409-on-destroy) below |

## Provider integration 409 on destroy

Same issue as [`workshop-tableflow-databricks`](https://github.com/confluentinc/workshop-tableflow-databricks/blob/main/labs/shared/troubleshooting.md): Confluent returns **409** when deleting a provider integration that Tableflow still references.

```
Error: error deleting provider integration "cspi-…": 409 Conflict
detail: "integration is being used in some confluent resource"
```

**Why:** Destroy order is topics → integration (via `depends_on`), but Confluent can lag after Tableflow disable. Terraform now sleeps ~90s on integration destroy to reduce the race; if 409 still happens:

1. Drop the integration from state (does **not** call Confluent DELETE — env teardown removes it):

   ```sh
   cd terraform/aws-demo
   docker-compose run --rm terraform -c \
     "terraform state rm 'module.tableflow.confluent_provider_integration.aws[0]'"
   ```

2. Re-run destroy:

   ```sh
   docker-compose run --rm terraform -c "terraform destroy -auto-approve"
   ```

3. If it still sticks, disable Tableflow on `riverflow_payments` / `riverflow_payments_risk_score` in the Confluent UI, then destroy again.

## Getting more help

- Design runbook: [`context/fsi_payments_workshop_phase1_runbook.md`](../../context/fsi_payments_workshop_phase1_runbook.md)
- Genie prompts: [`sql/genie_prompts.md`](../../sql/genie_prompts.md)
- Lab index: [`labs/demo/README.md`](../demo/README.md)
