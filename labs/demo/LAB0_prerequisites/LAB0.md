# LAB 0: Prerequisites

## Overview

Clone this repository, confirm cloud accounts, and build the Terraform Docker image used for the RiverPay demo.

### What You'll Accomplish

- Confirm Confluent Cloud, Databricks, and AWS access
- Install Git and Docker Desktop
- Build the workshop Terraform container

### Prerequisites

None — this is the first lab.

## Required Accounts

- **Confluent Cloud** with OrganizationAdmin or EnvironmentAdmin and a payment method or promo code
- **Databricks** workspace with **Unity Catalog** enabled (paid / trial UC workspace — Free Edition is usually insufficient for external locations + Tableflow + Genie)
- **AWS** account with permissions to create EC2, S3, VPC, and IAM resources

> [!WARNING]
> **Cost**
>
> `terraform apply` creates billable AWS, Confluent Cloud, and Databricks resources. Plan to run **[LAB 4: Cleanup](../LAB4_cleanup/LAB4.md)** when you finish.

## Required Tools

1. **[Git](https://git-scm.com/downloads)**
2. **[Docker Desktop](https://docs.docker.com/get-started/get-docker/)** (or Docker Engine + Compose plugin) installed and running

<details>
<summary>Install on macOS</summary>

```sh
brew install git
brew install --cask docker
```

Launch Docker Desktop and wait until it is running.

</details>

<details>
<summary>Install on Linux</summary>

```sh
# Git (Debian/Ubuntu example)
sudo apt update && sudo apt install -y git

# Docker Engine + Compose plugin — follow:
# https://docs.docker.com/engine/install/
```

Ensure your user can run `docker` without sudo (or prefix commands with `sudo`).

</details>

<details>
<summary>Install on Windows</summary>

1. Install [Git for Windows](https://git-scm.com/download/win)
2. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) (WSL2 backend recommended)
3. Use PowerShell or Git Bash for lab commands

</details>

> [!NOTE]
> **`docker compose` vs `docker-compose`**
>
> Labs use `docker-compose` for compatibility. On current Docker Desktop, `docker compose` (plugin) is equivalent — either form works.

## Steps

### Step 1: Confirm Account Access

1. Sign in to [Confluent Cloud](https://confluent.cloud) and confirm you can open **Administration → API keys**
2. Sign in to your Databricks workspace and confirm **Unity Catalog** is available (Catalog explorer shows catalogs)
3. Confirm AWS credentials work for the target account (`aws sts get-caller-identity` on the host, or you will configure them in LAB 1)

### Step 2: Clone this Repository

```sh
git clone https://github.com/confluentinc/workshop-fsi-payments.git
cd workshop-fsi-payments
```

> [!NOTE]
> If your fork or remote URL differs, use that clone URL instead.

### Step 3: Build the Terraform Docker Image

```sh
cd terraform/aws-demo
docker-compose build
```

> [!NOTE]
> **Expected Result**
>
> The image `workshop-fsi-terraform:latest` builds successfully.

#### Checkpoint

- [ ] Confluent Cloud, Databricks (UC), and AWS access confirmed
- [ ] Docker is running
- [ ] `docker-compose build` completed without errors

## Conclusion

You are ready to configure credentials.

## What's Next

Continue to **[LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)**.

## Troubleshooting

See [shared troubleshooting](../../shared/troubleshooting.md).
