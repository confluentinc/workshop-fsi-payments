# Demo labs — RiverPay / RiverFlow / RiverPulse

Hands-on path for the **demo-mode** workshop. Start from the [root README](../../README.md) for architecture and narrative, then work through LAB0–LAB4 in order.

> Instructor-led (Azure) uses a separate path: [`labs/instructor-led/`](../instructor-led/README.md). Demo labs still apply the full AWS pipeline; after apply you should see FX CDC, USD-normalized completed payments, and risk scores from the external UDF (`enable_risk_udf=true` by default).

| Lab | Goal | Time |
|-----|------|------|
| [LAB 0 — Prerequisites](LAB0_prerequisites/LAB0.md) | Accounts, Git, Docker image | ~10 min |
| [LAB 1 — Account setup](LAB1_account_setup/LAB1.md) | API keys, Databricks SP, `terraform.tfvars` | ~15 min |
| [LAB 2 — Deploy and observe](LAB2_deploy_and_observe/LAB2.md) | `terraform apply` + Confluent / Databricks tour | ~20–25 min apply + tour |
| [LAB 3 — RiverPulse analytics](LAB3_riverpulse_analytics/LAB3.md) | Genie answers the three ops questions | ~15 min |
| [LAB 4 — Cleanup](LAB4_cleanup/LAB4.md) | `terraform destroy` + leftover check | ~10 min |

**Shared**

- [Troubleshooting](../shared/troubleshooting.md)
- [Recap / talking points](../shared/recap.md)
- Genie prompts: [`sql/genie_prompts.md`](../../sql/genie_prompts.md)
**Facilitators:** prefer a completed LAB2 apply before the live session so attendees focus on observe + Genie. Speaker notes: [`context/fsi_payments_workshop_facilitator_script.md`](../../context/fsi_payments_workshop_facilitator_script.md).
