# LAB 0: Prerequisites (cp-rosa)

## Overview

Confirm local tools and clone this repository for the RiverPay-lite Confluent Platform on ROSA path.

### What You'll Accomplish

- Install / verify `oc`, `kubectl`, `helm`, Terraform, AWS CLI, and Git
- Clone the workshop repo

### Prerequisites

None — this is the first lab.

## Required Accounts (preview)

You will configure these in LAB 1:

- **AWS** account with permissions for VPC, IAM, EC2 (ROSA workers), and ROSA enablement
- **Red Hat** account with access to OpenShift Cluster Manager (OCM) and ROSA

> [!WARNING]
> **Cost**
>
> Stage 1 creates a billable ROSA HCP cluster and worker nodes. Plan to run **[LAB 4: Cleanup](../LAB4_cleanup/LAB4.md)** when you finish.

## Required Tools

| Tool | Purpose |
|------|---------|
| [Git](https://git-scm.com/downloads) | Clone this repo |
| [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.6` | Stage 1 + Stage 2 applies (host install preferred) |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | Credentials / identity checks |
| [OpenShift CLI (`oc`)](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html) | Log in to ROSA |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Inspect pods / port-forward (often bundled with `oc`) |
| [Helm](https://helm.sh/docs/intro/install/) `>= 3` | Used by Stage 2 Terraform provider + manual checks |

<details>
<summary>Install on macOS (Homebrew)</summary>

```sh
brew install git terraform awscli kubernetes helm
brew install openshift-cli   # provides `oc`; formula name may vary
```

If `openshift-cli` is unavailable, download `oc` from the [OpenShift mirror](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/).

</details>

## Steps

### Step 1: Verify tools

```sh
git --version
terraform version
aws --version
oc version --client
kubectl version --client
helm version
```

**Expected result:** Each command prints a version without “command not found.”

### Step 2: Clone this repository

```sh
git clone <this-repo-url>
cd workshop-fsi-payments
```

(Skip clone if you already have the repo open.)

### Step 3: Skim the path layout

```sh
ls labs/cp-rosa
ls terraform/cp-rosa
```

**Expected result:** Labs LAB0–LAB4 and Terraform `stage1-rosa` / `stage2-cfk` / `manifests` are present.

## Next

Continue to **[LAB 1: Account setup](../LAB1_account_setup/LAB1.md)**.
