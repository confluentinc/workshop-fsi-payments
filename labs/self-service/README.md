# Azure / AWS — RiverPay self-service

BYO Confluent Cloud, Databricks, and cloud accounts. Terraform provisions
infra + CDC + lifecycle traffic + Risk API/UDF **plumbing**. You write Flink
MTs and enable Tableflow in the labs (same shape as instructor-led).

| Cloud | Terraform root | Notes |
|-------|----------------|-------|
| **AWS** | [`terraform/aws`](../../terraform/aws/) | Recommended for free-trial / first run |
| **Azure** | [`terraform/azure`](../../terraform/azure/) | Leave all `shared_*` empty |

## Lab path

| Lab | Focus | Est. |
|-----|--------|------|
| [LAB 0: Prerequisites](./LAB0_prerequisites/LAB0.md) | Accounts, Git, Docker, clone, build image | ~10 min |
| [LAB 1: Account setup](./LAB1_account_setup/LAB1.md) | API keys, SP, `terraform.tfvars` | ~15 min |
| [LAB 2: Deploy & explore](./LAB2_deploy_and_explore/LAB2.md) | `terraform apply` + tour CDC/topics/UDF | ~20–45 min |
| [LAB 3: Stream processing](./LAB3_stream_processing/LAB3.md) | Flink MTs: FX TTJ + risk UDF | ~20 min |
| [LAB 4: Tableflow](./LAB4_tableflow/LAB4.md) | Enable Tableflow + data TTL | ~10 min |
| [LAB 5: RiverPulse analytics](./LAB5_riverpulse_analytics/LAB5.md) | Genie — three business questions | ~15 min |
| [LAB 6: Wrap-up & cleanup](./LAB6_cleanup/LAB6.md) | Recap + `terraform destroy` | ~10 min |

## vs other modes

| | Self-service (this) | Instructor-led | Demo |
|--|---------------------|----------------|--------|
| Accounts | You sign up (free trial OK) | Pre-provisioned / claim form | Your accounts |
| Flink MTs | You write SQL | You write SQL | Terraform |
| Tableflow | You enable | You enable | Terraform |
| Risk API | AWS EC2 or Azure datagen VM `:8089` | Shared Container Apps HTTPS | EC2 `:8089` |

Shared troubleshooting: [`labs/shared/troubleshooting.md`](../shared/troubleshooting.md).
