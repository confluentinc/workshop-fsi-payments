# RiverPay instructor-led labs (Elevate)

Pre-provisioned Azure shared infra + per-attendee Confluent/Databricks.
Attendees skip demo-mode credential/deploy labs and go straight to Flink, Tableflow, and Genie.

## Lab path

| Lab | Focus | Est. |
|-----|--------|------|
| [LAB 1: Claim Your Account](./LAB1_claim_account/LAB1.md) | Claim credentials; verify Confluent + Databricks | ~5 min |
| [LAB 2: Explore Your Environment](./LAB2_explore_environment/LAB2.md) | CDC, lifecycle topics, Flink pool, risk CONNECTION/UDF | ~10 min |
| [LAB 3: Stream Processing](./LAB3_stream_processing/LAB3.md) | Flink MTs: FX TTJ + risk UDF | ~20 min |
| [LAB 4: Tableflow](./LAB4_tableflow/LAB4.md) | Enable Tableflow | ~10 min |
| [LAB 5: RiverPulse Analytics](./LAB5_riverpulse_analytics/LAB5.md) | Genie — three business questions | ~15 min |
| [LAB 6: Wrap Up](./LAB6_wrap_up/LAB6.md) | Recap | ~5 min |

## Operator Terraform

1. [`terraform/azure-shared`](../../terraform/azure-shared/) — once per workshop
2. [`terraform/azure`](../../terraform/azure/) — per attendee (no auto Flink MTs / Tableflow topics)
3. WSA / operator guide: [`docs/operator-azure-elevate.md`](../../docs/operator-azure-elevate.md) + [`wsa-spec-azure.yaml`](../../wsa-spec-azure.yaml)

## vs demo mode

| | Demo (`labs/demo` + `aws-demo`) | Instructor-led (this path) |
|--|----------------------------------|----------------------------|
| Cloud | AWS | Azure |
| Flink MTs | Terraform | Attendee SQL |
| Tableflow topics | Terraform | Attendee UI |
| Risk API | EC2 `:8089` + UDF (default on) | Shared Container Apps HTTPS + pre-registered UDF |

Shared troubleshooting: [`labs/shared/troubleshooting.md`](../shared/troubleshooting.md).
