# Terraform: CP on ROSA (RiverPay-lite)

Two-stage Terraform for the **cp-rosa** workshop path:

| Stage | Directory | Provisions |
|-------|-----------|------------|
| 1 | [`stage1-rosa/`](stage1-rosa/) | VPC + ROSA HCP cluster (STS roles, OIDC, admin user) |
| 2 | [`stage2-cfk/`](stage2-cfk/) | CFK Helm + Confluent Platform CRs + RiverPay-lite producer |

Manifests live in [`manifests/`](manifests/).

## Why two stages?

ROSA must finish before Helm/Kubernetes providers can talk to the API. Apply Stage 1, log in with `oc`, then apply Stage 2.

## Prerequisites

- Terraform `>= 1.6`
- AWS credentials with IAM + VPC permissions
- Red Hat account with ROSA enabled; OCM offline token (`RHCS_TOKEN`)
- Local tools for Stage 2: `oc`, `kubectl`, `helm`

See [`labs/cp-rosa/`](../../labs/cp-rosa/) for the full walkthrough.

## Cost warning

ROSA HCP and worker nodes are billable. Tear down Stage 2, then Stage 1, when finished ([LAB 4](../../labs/cp-rosa/LAB4_cleanup/LAB4.md)).
