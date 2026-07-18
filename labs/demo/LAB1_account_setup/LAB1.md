# LAB 1: Account Setup

## Overview

Configure Confluent Cloud, Databricks, and AWS credentials for the RiverPay demo Terraform apply.

### What You'll Accomplish

- Create a Confluent Cloud API key
- Create a Databricks service principal (OAuth M2M)
- Fill `terraform.tfvars` from `sample-tfvars`

### Prerequisites

Complete **[LAB 0](../LAB0_prerequisites/LAB0.md)**.

## Steps

### Step 1: Confluent Cloud API Key

1. Sign in to [Confluent Cloud](https://confluent.cloud)
2. Navigate to **Administration → API keys** (cloud API key with OrganizationAdmin or EnvironmentAdmin)
3. Create a key and save the **key** and **secret**

### Step 2: Databricks Service Principal

Account console vs workspace is the usual friction point — use the **account console** for the SP and account ID.

**Docs (bookmark these):**

- [Authorize service principal access with OAuth (M2M)](https://docs.databricks.com/aws/en/dev-tools/auth/oauth-m2m) — create SP, generate OAuth secret, copy client ID + secret
- [Manage service principals](https://docs.databricks.com/aws/en/admin/users-groups/service-principals) — add the SP to a workspace
- Account ID: open [https://accounts.cloud.databricks.com](https://accounts.cloud.databricks.com) → user menu / account settings (UUID used as IAM trust external ID)

**Steps:**

1. In the **Databricks account console**, create a **service principal**
2. Open the SP → **Secrets** → **Generate secret** (OAuth client secret; shown once)
3. Note:
   - **Application ID** / client ID
   - OAuth **secret**
   - Workspace URL (`https://dbc-….cloud.databricks.com`)
   - **Account ID**
4. Add the SP to the target workspace and grant it permission to use Unity Catalog and a SQL warehouse (workspace admin can refine grants after apply if needed)
5. Confirm a SQL warehouse exists (default name Terraform looks up: `Serverless Starter Warehouse`)

### Step 3: AWS Credentials

Ensure one of the following works:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional session token), or
2. Host `~/.aws/credentials` (mounted into the Terraform container), or
3. Run `aws configure` inside the container (persists under `terraform/aws-demo/aws-config/`)

### Step 4: Create `terraform.tfvars`

```sh
cd terraform/aws-demo
cp sample-tfvars terraform.tfvars
```

Edit `terraform.tfvars` and fill in:

| Variable | Description |
|----------|-------------|
| `confluent_cloud_email` | Your CC login email |
| `prefix` | Short call sign (e.g. `neo`) |
| `cloud_region` | AWS region (e.g. `us-east-1`) |
| `confluent_cloud_api_key` / `secret` | Cloud API key pair |
| `databricks_host` | `https://dbc-….cloud.databricks.com` |
| `databricks_account_id` | Account ID for IAM trust (external ID) — required |
| `databricks_user_email` | Your Databricks user |
| `databricks_service_principal_client_id` / `secret` | SP OAuth credentials |
| `databricks_sql_warehouse_name` | Optional; uncomment in `sample-tfvars` if not `Serverless Starter Warehouse` |

> [!NOTE]
> **ShadowTraffic license**
>
> Terraform automatically fetches the ShadowTraffic free-trial license over HTTP at apply time. You do not need to set a license in `terraform.tfvars`.

> [!WARNING]
> Never commit `terraform.tfvars` — it is gitignored.

#### Checkpoint

- [ ] `terraform.tfvars` filled with non-empty required values (including `databricks_account_id`)
- [ ] SQL warehouse name matches your workspace (or default)
- [ ] AWS credentials available to Docker

## Conclusion

Credentials are ready for a full demo deploy.

## What's Next

Continue to **[LAB 2: Deploy and Observe](../LAB2_deploy_and_observe/LAB2.md)**.

## Troubleshooting

See [shared troubleshooting](../../shared/troubleshooting.md).
