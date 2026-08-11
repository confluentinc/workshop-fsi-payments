# AWS shared infrastructure (instructor-led)

Provisions **once** per workshop run. Patterned on tableflow `aws-shared` + RiverPay
`azure-shared` (profiles + FX + Risk API HTTP on the Postgres EC2).

Per-attendee environments: [`../aws/`](../aws/) with `shared_*` from these outputs.
Lifecycle Kafka traffic: [`../aws-lifecycle-st/`](../aws-lifecycle-st/) via
[`scripts/wsa-deploy-lifecycle-st.sh`](../../scripts/wsa-deploy-lifecycle-st.sh).

## Owns

| Resource | Notes |
|----------|--------|
| VPC + public subnet | Shared networking |
| S3 | Tableflow / Unity Catalog landing zone |
| SSH keypair | Postgres EC2 + lifecycle ST deploy |
| Postgres EC2 | `riverpay.customer_profiles` + `riverpay.fx_rates`; slots/senders sized for N CDC |
| ShadowTraffic | Postgres-only (`shadowtraffic-riverpay`) |
| Risk Scoring API | HTTP `:8089` on the Postgres host |
| Databricks | Ephemeral SP secret + bucket-root external location |

## Usage

```bash
cd terraform/aws-shared
cp sample-tfvars terraform.tfvars
terraform init && terraform apply
terraform output
# Prefer: wsa build -w wsa-spec-aws.yaml
```

Operator guide: [`docs/operator-instructor-led.md`](../../docs/operator-instructor-led.md).
