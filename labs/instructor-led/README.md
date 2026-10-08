# RiverPay instructor-led labs (Elevate)

Pre-provisioned Azure shared infra + per-attendee Confluent/Databricks.
Attendees skip demo-mode credential/deploy labs and go straight to Flink, Tableflow, and Genie.

> **Before you start — network access.** The Flink SQL Workspace talks to a
> **separate host** from the Console (`flink.<region>.<cloud>.confluent.cloud`,
> e.g. `flink.eastus2.azure.confluent.cloud`). Strict corporate VPNs / firewalls /
> SSL-inspection proxies can block it, so the Console loads but the Workspace shows
> **"Failed to fetch"** / **"The current Flink endpoint is not allowed to access the
> statements."** This is a **network** issue, not your account or credentials.
> - **On a corporate VPN/network and hitting this?** Switch to a **non-corporate
>   network** (personal hotspot / guest Wi-Fi) or a personal device.
> - **Operators:** send the requirements to the customer's IT **before** the event —
>   allowlist `confluent.cloud` **and** the regional Flink host, and **exempt both
>   from TLS/SSL inspection**. Details:
>   [shared troubleshooting → Flink](../shared/troubleshooting.md#flink).

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
