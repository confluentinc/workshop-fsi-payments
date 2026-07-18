# LAB 3: Deploy CFK and Observe (Stage 2)

## Overview

Apply Stage 2 Terraform to install **Confluent for Kubernetes**, deploy the Confluent Platform stack (KRaft quickstart-style), and start the **RiverPay-lite** producer. Open Control Center via **port-forward** (default). Optionally expose Control Center with an OpenShift route.

### What Terraform Creates

| Layer | Resources |
|-------|-----------|
| **CFK** | Helm release `confluent-operator` in `confluent` |
| **Confluent Platform** | KRaft, Kafka, Connect, Schema Registry, ksqlDB, REST Proxy, Control Center |
| **RiverPay-lite** | Topics `riverflow.payments.*` + JSON producer Deployment |

### Prerequisites

Complete **[LAB 2](../LAB2_provision_rosa/LAB2.md)** and remain logged in with `oc` (`kubectl` uses the same kubeconfig).

## Steps

### Step 1: Initialize and apply Stage 2

```sh
cd terraform/cp-rosa/stage2-cfk
cp sample-tfvars terraform.tfvars
terraform init
terraform apply
```

> [!NOTE]
> **Expected Duration**
>
> Roughly **5–15 minutes** for Helm + manifest apply. Pods may still become Ready afterward — watch them in Step 2.

### Step 2: Confirm pods and topics

```sh
kubectl -n confluent get pods
kubectl -n confluent get kafkatopic
kubectl -n confluent logs -l app=riverpay-producer --tail=30
```

**Expected result:**

- CFK operator and CP component pods are Running (or progressing to Running)
- KafkaTopic objects exist for `riverflow.payments.initiation`, `.authorization`, `.balance_update`, `.status`
- Producer logs show `Produced RiverPay lifecycle for PMT-...`

### Step 3: Open Control Center (port-forward — default)

```sh
kubectl -n confluent port-forward controlcenter-0 9021:9021
```

Open [http://localhost:9021](http://localhost:9021).

**What to show**

1. Cluster / brokers healthy on ROSA
2. Topics `riverflow.payments.*` receiving messages
3. Sample message JSON matching RiverPay lifecycle fields (`payment_id`, `customer_id`, `amount`, …)

Talking points: [`context/cp_rosa_demo_talk_track.md`](../../../context/cp_rosa_demo_talk_track.md)

### Step 4 (optional): Control Center OpenShift route

Use after the port-forward path works. TLS is required for CFK routes.

```sh
export APPS_DOMAIN="apps.$(oc get dns cluster -o jsonpath='{.spec.baseDomain}')"
echo "$APPS_DOMAIN"
sed "s/APPS_DOMAIN/${APPS_DOMAIN}/g" \
  ../../../terraform/cp-rosa/manifests/controlcenter-route-patch.yaml | oc apply -f -

oc -n confluent get routes
oc -n confluent get controlcenter controlcenter \
  -ojsonpath='{.status.restConfig.externalEndpoint}{"\n"}'
```

Open the external endpoint URL from the last command.

> [!NOTE]
> Route exposure is the more ROSA-native finish for Red Hat audiences. Keep port-forward as the reliable default for short recordings.

### Step 5: Capture Stage 2 outputs

```sh
terraform output verify_commands
terraform output topics
```

## Next

When finished demonstrating, continue to **[LAB 4: Cleanup](../LAB4_cleanup/LAB4.md)**.
