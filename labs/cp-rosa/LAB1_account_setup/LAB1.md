# LAB 1: Account Setup (cp-rosa)

## Overview

Enable ROSA on AWS, obtain an OCM token, and fill Stage 1 `terraform.tfvars`.

### What You'll Accomplish

- Confirm AWS identity and ROSA readiness
- Export `RHCS_TOKEN` (OCM offline token)
- Create `terraform/cp-rosa/stage1-rosa/terraform.tfvars`

### Prerequisites

Complete **[LAB 0](../LAB0_prerequisites/LAB0.md)**.

## Steps

### Step 1: AWS credentials

```sh
aws sts get-caller-identity
aws configure get region
```

**Expected result:** Account ID, ARN, and user/role print successfully. Prefer the same region you will put in `aws_region` (default `us-east-1`).

### Step 2: Enable ROSA (one-time per AWS account)

1. Open the [ROSA getting started](https://console.redhat.com/openshift/create/rosa/getstarted) guide in Red Hat Hybrid Cloud Console.
2. Complete AWS account association / service-linked role prerequisites for ROSA.
3. Optional CLI check (if `rosa` CLI is installed):

   ```sh
   rosa whoami
   rosa verify permissions
   ```

> [!NOTE]
> Stage 1 Terraform creates account roles, operator roles, and OIDC via the `terraform-redhat/rosa-hcp` module. You still need the AWS account eligible for ROSA and a valid OCM token.

### Step 3: OCM offline token

1. Open [https://console.redhat.com/openshift/token/rosa](https://console.redhat.com/openshift/token/rosa)
2. Copy the offline token
3. Export it in your shell (do not commit it):

   ```sh
   export RHCS_TOKEN="<paste-token>"
   ```

**Expected result:** `echo $RHCS_TOKEN` shows a long token string (keep it secret).

### Step 4: Create Stage 1 `terraform.tfvars`

```sh
cd terraform/cp-rosa/stage1-rosa
cp sample-tfvars terraform.tfvars
```

Edit `terraform.tfvars`:

| Variable | Notes |
|----------|--------|
| `cluster_name` | Short, unique, ≤54 chars (e.g. `riverpay-cp`) |
| `aws_region` | Match your AWS region |
| `openshift_version` | Keep default unless you need a specific Y-stream |
| `owner_email` | Your email for tagging / ownership |

### Step 5: Quick sanity check

```sh
test -n "$RHCS_TOKEN" && echo "RHCS_TOKEN is set"
grep -E 'cluster_name|aws_region|owner_email' terraform.tfvars
```

**Expected result:** Token is set; tfvars shows your edited values (no empty `cluster_name`).

## Next

Continue to **[LAB 2: Provision ROSA](../LAB2_provision_rosa/LAB2.md)**.
