# ROSA + Confluent Platform demo talk track (RiverPay-lite)

**Workshop path**: [`labs/cp-rosa/`](../labs/cp-rosa/) · Terraform: [`terraform/cp-rosa/`](../terraform/cp-rosa/)

## Goals

1. Show Confluent Platform running on ROSA managed by Confluent for Kubernetes
2. Show live **RiverPay** lifecycle data in Control Center (`riverflow.payments.*`)

This path is a **parallel delivery mode** to the Confluent Cloud FSI workshop (`labs/demo/`). It does not include Flink, Tableflow, or Databricks in v1.

## Repos and paths

* CFK examples: [`confluentinc/confluent-kubernetes-examples`](https://github.com/confluentinc/confluent-kubernetes-examples) — `quickstart-deploy/kraft-quickstart`
* This workshop manifests: `terraform/cp-rosa/manifests/` (KRaft-style platform + RiverPay-lite producer)
* OpenShift routes: [CFK routes documentation](https://docs.confluent.io/operator/current/co-routes.html)

## What this demo highlights

* ROSA HCP hosts the platform (provisioned in Stage 1 Terraform)
* CFK installs and manages Confluent Platform through Kubernetes CRs (Stage 2)
* Full stack: KRaft, Kafka, Connect, Schema Registry, ksqlDB, REST Proxy, Control Center
* RiverPay-lite producer streams flattened JSON lifecycle events into formalized topic names

## Assumptions

* AWS + Red Hat/OCM credentials available (see LAB 0–1)
* `oc`, `kubectl`, `helm`, and Terraform installed locally
* Cluster has a default dynamic StorageClass

## Recommended flow (labs)

| Step | Lab | Action |
|------|-----|--------|
| 1 | LAB 0–1 | Tools + ROSA enablement + `RHCS_TOKEN` + Stage 1 tfvars |
| 2 | LAB 2 | `terraform apply` Stage 1 (ROSA HCP) → `oc login` |
| 3 | LAB 3 | `terraform apply` Stage 2 (CFK + CP + producer) |
| 4 | LAB 3 | Port-forward Control Center → show `riverflow.payments.*` |
| 5 | LAB 3 optional | Control Center OpenShift route |
| 6 | LAB 4 | Destroy Stage 2, then Stage 1 |

## Fastest recording path (3–5 minutes of screen time)

Assume Stage 1 + Stage 2 already applied before recording.

### 1. Show ROSA + pods

```shell
oc whoami
kubectl -n confluent get pods
```

### 2. Open Control Center (port-forward)

```shell
kubectl -n confluent port-forward controlcenter-0 9021:9021
```

Open `http://localhost:9021`.

### 3. What to show

* Pods for the CP stack on ROSA
* Control Center loading
* Topics `riverflow.payments.initiation` (and siblings) receiving RiverPay JSON

## Suggested talk track

### Intro

"Here I'm running Confluent Platform directly on Red Hat OpenShift Service on AWS, or ROSA. Confluent for Kubernetes is managing the deployment using Kubernetes-native custom resources."

### Deployment value

"I'm not hand-assembling brokers and Control Center. Stage 1 gave us a ROSA HCP cluster; Stage 2 installed CFK and applied the platform CRs from our RiverPay-lite manifests."

### Platform value

"This brings up Kafka, Connect, Schema Registry, ksqlDB, REST Proxy, and Control Center on ROSA so we can go from cluster to streaming workflow quickly."

### Data value

"Instead of a generic sample topic, we're producing RiverPay payment lifecycle events — initiation through status — so Control Center shows the same narrative language as our FSI workshop, running on Confluent Platform."

## Optional ROSA-native finish (Control Center route)

After port-forward works, patch Control Center for route-based external access (TLS required). See `terraform/cp-rosa/manifests/controlcenter-route-patch.yaml` and LAB 3 Step 4.

```shell
export APPS_DOMAIN="apps.$(oc get dns cluster -o jsonpath='{.spec.baseDomain}')"
sed "s/APPS_DOMAIN/${APPS_DOMAIN}/g" \
  terraform/cp-rosa/manifests/controlcenter-route-patch.yaml | oc apply -f -
oc -n confluent get routes
oc -n confluent get controlcenter controlcenter \
  -ojsonpath='{.status.restConfig.externalEndpoint}{"\n"}'
```

Kafka external route listeners are out of scope for v1.

## Recommended recording options

### Option A: safest (default)

* ROSA console briefly
* `kubectl get pods -n confluent`
* Control Center via port-forward
* RiverPay topics receiving data

### Option B: more ROSA-specific

* Same as A
* Replace port-forward with Control Center OpenShift route
* Show `oc get routes`

## Cleanup

Follow [LAB 4](../labs/cp-rosa/LAB4_cleanup/LAB4.md): destroy Stage 2, then Stage 1.

## Sources

* [Confluent for Kubernetes Scenario Examples](https://github.com/confluentinc/confluent-kubernetes-examples)
* [CFK OpenShift routes](https://docs.confluent.io/operator/current/co-routes.html)
* [CFK overview](https://docs.confluent.io/operator/current/overview.html)
* [CFK quickstart](https://docs.confluent.io/operator/current/co-quickstart.html)
* [terraform-redhat/rosa-hcp](https://registry.terraform.io/modules/terraform-redhat/rosa-hcp/rhcs/latest)
