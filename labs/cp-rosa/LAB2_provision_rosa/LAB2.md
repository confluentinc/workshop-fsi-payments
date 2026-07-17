# LAB 2: Provision ROSA (Stage 1)

## Overview

Apply Stage 1 Terraform to create a VPC and a public **ROSA HCP** cluster with STS roles, managed OIDC, cluster-admin, and an HTPasswd demo user.

### What Terraform Creates

| Layer | Resources |
|-------|-----------|
| **AWS** | VPC, public/private subnets, IAM account + operator roles, OIDC provider |
| **ROSA HCP** | Hosted control plane cluster, worker machine pool, cluster-admin, HTPasswd IDP (`riverpay-demo`) |

### Prerequisites

Complete **[LAB 1](../LAB1_account_setup/LAB1.md)**. `RHCS_TOKEN` must be exported in this shell.

> [!WARNING]
> Apply creates billable ROSA/AWS resources. Tear down with **[LAB 4](../LAB4_cleanup/LAB4.md)** when finished.

## Steps

### Step 1: Initialize and apply

```sh
cd terraform/cp-rosa/stage1-rosa
terraform init
terraform apply
```

Confirm the plan, then approve.

> [!NOTE]
> **Expected Duration**
>
> Often **30–45+ minutes**. Longest step is ROSA cluster creation.

#### While you wait (facilitator / recording)

1. ROSA is the managed OpenShift substrate on AWS; CFK will manage Confluent Platform as Kubernetes CRs in LAB 3
2. Preview the talk track: [`context/cp_rosa_demo_talk_track.md`](../../../context/cp_rosa_demo_talk_track.md)
3. Contrast with the Cloud path: here the story is **platform on OpenShift**, not Flink/Tableflow/Genie

### Step 2: Review outputs

```sh
terraform output cluster_id
terraform output cluster_api_url
terraform output cluster_console_url
terraform output cluster_domain
terraform output next_steps
```

Sensitive values:

```sh
terraform output -raw cluster_admin_username
terraform output -raw cluster_admin_password
```

**Expected result:** API and console URLs are populated; cluster state is ready/stable (see `terraform output cluster_state`).

### Step 3: Log in with `oc`

```sh
oc login "$(terraform output -raw cluster_api_url)" \
  -u "$(terraform output -raw cluster_admin_username)" \
  -p "$(terraform output -raw cluster_admin_password)"
```

Validate:

```sh
oc whoami
oc get nodes
oc get sc
```

**Expected result:** You are authenticated; worker nodes show Ready; at least one StorageClass exists (ROSA default dynamic provisioner).

### Step 4: Optional — OpenShift console

Open `terraform output -raw cluster_console_url` in a browser and confirm the cluster overview.

## Next

Continue to **[LAB 3: Deploy CFK and observe](../LAB3_deploy_and_observe/LAB3.md)**.
