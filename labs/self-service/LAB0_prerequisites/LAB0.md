# LAB 0: Prerequisites

## Overview

Set up free-trial / BYO accounts and tools for the **self-service** RiverPay workshop.

## Required accounts

- **Confluent Cloud** — [free trial](https://www.confluent.io/confluent-cloud/tryfree/). Add a [payment method](https://docs.confluent.io/cloud/current/billing/overview.html#manage-your-payment-method) or promo code so resources can be created.
- **Databricks** — [Free Edition](https://login.databricks.com/?intent=SIGN_UP&provider=DB_FREE_TIER) is OK for this workshop. Paid / trial workspaces with Unity Catalog are also fine. Confirm a SQL warehouse exists after first login.
- **Cloud provider (pick one path):**
  - **AWS** (recommended) — `terraform/aws`; ShadowTraffic + Risk API on Postgres EC2
  - **Azure** — `terraform/azure` with empty `shared_*`; **datagen VM** runs full ShadowTraffic + Risk API `:8089` (Flexible Server for CDC)

## Required tools

1. [Git](https://git-scm.com/downloads)
2. [Docker Desktop](https://docs.docker.com/get-started/get-docker/) running

<details>
<summary>Install on macOS</summary>

```sh
brew install git
brew install --cask docker
```

</details>

<details>
<summary>Install on Windows</summary>

1. Install [Git for Windows](https://git-scm.com/download/win)
2. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) (WSL2 backend recommended)
3. Use PowerShell or Git Bash for lab commands

</details>

## Initial setup

```sh
git clone https://github.com/confluentinc/workshop-fsi-payments.git
cd workshop-fsi-payments
```

### Build the UDF JAR (required when `enable_risk_udf=true`)

<details open>
<summary>macOS / Linux / Git Bash</summary>

```sh
cd udf/riverpay-risk
docker run --rm -v "$PWD":/ws -w /ws maven:3.9-eclipse-temurin-11 \
  mvn -s settings.xml -q -DskipTests package
mkdir -p dist && cp -f target/riverpay-risk-udf-1.0.0.jar dist/
cd ../..
```

> Git Bash only: if Docker reports it can't find `/ws` inside the container, MSYS is rewriting the path — prefix the `docker run` line with `MSYS_NO_PATHCONV=1`.

</details>

<details>
<summary>Windows (PowerShell)</summary>

```powershell
cd udf/riverpay-risk
docker run --rm -v "${PWD}:/ws" -w /ws maven:3.9-eclipse-temurin-11 `
  mvn -s settings.xml -q -DskipTests package
New-Item -ItemType Directory -Force -Path dist | Out-Null
Copy-Item -Force target/riverpay-risk-udf-1.0.0.jar dist/
cd ../..
```

</details>

### AWS path — Terraform image

```sh
cd terraform/aws
docker-compose build
```

### Azure path — Terraform CLI

Use local Terraform `>= 1.6` + `az login` (Azure self-service does not use the aws docker-compose image).

## Checkpoint

Complete these before moving on to the next lab:

- [ ] Confluent Cloud account ready (payment method or promo)
- [ ] Databricks workspace + warehouse available
- [ ] AWS **or** Azure credentials ready
- [ ] Git + Docker running
- [ ] UDF JAR present under `udf/riverpay-risk/dist/`
- [ ] (AWS) `terraform/aws` image built

## What's next

**[LAB 1: Account setup](../LAB1_account_setup/LAB1.md)**
