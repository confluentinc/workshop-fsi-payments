# LAB 1: Account Setup

## Overview

Configure Confluent Cloud, Databricks, and cloud credentials for self-service Terraform.

### Prerequisites

Complete **[LAB 0](../LAB0_prerequisites/LAB0.md)**.

## Choose your cloud path

| Path | Directory | Labs apply command |
|------|-----------|--------------------|
| **AWS** (recommended) | `terraform/aws` | `docker-compose run --rm terraform -c "…"` |
| **Azure** | `terraform/azure` | `terraform` on host + `az login` |

## Steps

### Step 1: Confluent Cloud API key

1. Sign in to [Confluent Cloud](https://confluent.cloud) (or [start a free trial](https://www.confluent.io/confluent-cloud/tryfree/))
2. **Administration → API keys** → create a **Cloud resource management** key, scoped to a service account with the `OrganizationAdmin` or `EnvironmentAdmin` role (Terraform needs this to create the environment, cluster, and Flink resources)
3. Save **key** and **secret**

### Step 2: Databricks service principal

1. In the **Databricks account console**, create a **service principal**
2. Generate an OAuth **secret** (shown once)
3. Note Application (client) ID, secret, workspace URL, and **account ID**
4. Add the SP to your workspace; ensure it can use Unity Catalog and a SQL warehouse
5. Free Edition: log into the workspace once so a warehouse can provision

Docs: [OAuth M2M](https://docs.databricks.com/aws/en/dev-tools/auth/oauth-m2m)

### Step 3a: AWS credentials

Use env vars, `~/.aws/credentials`, or `aws configure` (persists under `terraform/aws/aws-config/` in the container).

### Step 3b: Azure credentials

macOS / Linux / Git Bash:

```sh
az login
# optional: export ARM_SUBSCRIPTION_ID=…
```

Windows (PowerShell):

```powershell
az login
# optional: $env:ARM_SUBSCRIPTION_ID = "…"
```

### Step 4: Create `terraform.tfvars`

**AWS:**

```sh
cd terraform/aws
cp sample-tfvars terraform.tfvars
```

**Azure:**

```sh
cd terraform/azure
cp sample-tfvars terraform.tfvars
```

Fill in:

| Variable | Notes |
|----------|--------|
| `confluent_cloud_email` | Your login email |
| `prefix` | Short call sign (e.g. `neo`) |
| `cloud_region` | e.g. `us-east-1` or `eastus2` |
| `confluent_cloud_api_key` / `secret` | From Step 1 |
| `databricks_host` | Workspace URL |
| `databricks_account_id` | Required on AWS for IAM trust |
| `databricks_user_email` | Your user |
| `databricks_service_principal_client_id` / `secret` | From Step 2 |

Leave self-service flags as in `sample-tfvars`:

- `enable_flink_mts = false`
- `enable_tableflow_topics = false` (AWS)
- Azure already omits auto MTs / Tableflow topics

Leave all `shared_*` variables empty (as in `sample-tfvars`).

> ShadowTraffic license is fetched automatically at apply time.

## Checkpoint

- [ ] `terraform.tfvars` filled (no secrets committed to git)
- [ ] Confluent + Databricks + cloud auth verified
- [ ] Self-service flags leave Flink MTs / Tableflow for later labs

## What's next

**[LAB 2: Deploy & explore](../LAB2_deploy_and_explore/LAB2.md)**
