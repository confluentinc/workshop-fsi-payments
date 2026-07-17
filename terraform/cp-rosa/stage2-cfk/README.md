# Stage 2: CFK + Confluent Platform + RiverPay-lite

Installs Confluent for Kubernetes (Helm), applies the KRaft quickstart-style platform CRs, and deploys a RiverPay-lite JSON producer for the four lifecycle topics.

## Prerequisites

1. Stage 1 applied successfully ([`../stage1-rosa/`](../stage1-rosa/))
2. Logged in with `oc` (kubeconfig current context points at the ROSA cluster)
3. `kubectl` and `helm` on PATH
4. Cluster has a default StorageClass

## Apply

```sh
cd terraform/cp-rosa/stage2-cfk
cp sample-tfvars terraform.tfvars

terraform init
terraform apply
```

**Expected duration:** ~5–15 minutes (CFK install + pod scheduling). Kafka/Control Center pods may still be becoming Ready after apply returns — use `kubectl get pods -n confluent -w`.

## Observe

```sh
terraform output verify_commands
kubectl -n confluent get pods
kubectl -n confluent port-forward controlcenter-0 9021:9021
```

Open http://localhost:9021 and inspect `riverflow.payments.*`.

Optional OpenShift route:

```sh
terraform output -raw optional_route_hint
```

## Destroy

```sh
terraform destroy
```

Then destroy Stage 1.
