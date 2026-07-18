# LAB 4: Cleanup (cp-rosa)

## Overview

Tear down Stage 2 (CFK / Confluent Platform / producer), then Stage 1 (ROSA HCP + VPC). Order matters.

### Prerequisites

Completed LAB 2 (and usually LAB 3). Keep `oc` login valid until Stage 2 destroy finishes.

## Steps

### Step 1: Destroy Stage 2

```sh
cd terraform/cp-rosa/stage2-cfk
terraform destroy
```

Approve when prompted.

**Expected result:** Producer manifests, platform CRs, Helm release, and `confluent` namespace resources are removed (PVCs may take a minute to release).

Manual fallback if destroy fails mid-way:

```sh
kubectl delete -f ../manifests/riverpay-producer.yaml -n confluent --ignore-not-found
kubectl delete -f ../manifests/confluent-platform.yaml -n confluent --ignore-not-found
helm uninstall confluent-operator -n confluent || true
kubectl delete namespace confluent --ignore-not-found
```

### Step 2: Destroy Stage 1

```sh
cd ../stage1-rosa
terraform destroy
```

> [!NOTE]
> **Expected Duration**
>
> ROSA cluster deletion often takes **20–40+ minutes**.

### Step 3: Verify cloud cleanup

| Check | Where |
|-------|--------|
| Cluster gone | [OpenShift Cluster Manager](https://console.redhat.com/openshift) — no `riverpay-cp` (or your `cluster_name`) |
| AWS leftovers | EC2 / VPC / IAM roles with your cluster prefixes removed |
| Local kube context | `oc logout` or switch context so you do not target a deleted API |

```sh
aws ec2 describe-vpcs --filters Name=tag:Name,Values="*riverpay*" --query 'Vpcs[].VpcId'
```

(Adjust the filter to match your `cluster_name`.)

### Step 4: Local leftovers (optional)

```sh
cd terraform/cp-rosa/stage1-rosa
rm -f terraform.tfvars
cd ../stage2-cfk
rm -f terraform.tfvars
unset RHCS_TOKEN
```

State files (`.terraform/`, `*.tfstate`) remain unless you remove them intentionally.

## Done

You have removed the cp-rosa RiverPay-lite stack. For the Confluent Cloud payments workshop path, see [`labs/demo/`](../../demo/).
