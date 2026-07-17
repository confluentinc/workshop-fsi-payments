# Troubleshooting — cp-rosa

Focused on ROSA HCP + CFK + Control Center. For the Confluent Cloud / Databricks path, see [`labs/shared/troubleshooting.md`](../shared/troubleshooting.md).

## Most common (day of)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `RHCS_TOKEN` / rhcs provider auth errors | Missing or expired OCM token | Re-copy token from [console.redhat.com/openshift/token/rosa](https://console.redhat.com/openshift/token/rosa); `export RHCS_TOKEN=...` |
| Stage 1 fails on account/operator roles | ROSA not enabled / IAM permissions | Complete [ROSA getting started](https://console.redhat.com/openshift/create/rosa/getstarted); ensure IAM create-role permissions |
| Stage 1 hangs a long time | Normal for ROSA create | Wait 30–45+ min; check OCM console cluster status |
| `oc login` certificate / unreachable API | Wrong URL, private cluster, or still provisioning | Re-check `cluster_api_url` and `cluster_state`; wait until ready |
| CFK Helm install fails | Bad kubeconfig / context | `oc whoami`; `kubectl config current-context`; set `kubeconfig_path` in Stage 2 tfvars |
| Pods Pending (PVC) | No default StorageClass | `oc get sc`; ensure ROSA default provisioner exists |
| Control Center port-forward fails | Pod not Ready / wrong name | `kubectl -n confluent get pods`; wait for `controlcenter-0` Running |
| Producer CrashLoop / no messages | Kafka not ready yet | Re-apply producer after brokers Ready; check `kubectl -n confluent logs -l app=riverpay-producer` |
| Route to Control Center fails TLS / no endpoint | Domain typo or CFK route not reconciled | Verify `APPS_DOMAIN`; `oc get routes -n confluent`; fall back to port-forward |

## Stage 1 (ROSA)

### Provider / token

```sh
echo "token length: ${#RHCS_TOKEN}"
terraform -chdir=terraform/cp-rosa/stage1-rosa providers
```

### Cluster state in OCM

Use the Hybrid Cloud Console → Clusters, or:

```sh
terraform -chdir=terraform/cp-rosa/stage1-rosa output cluster_state
terraform -chdir=terraform/cp-rosa/stage1-rosa output cluster_id
```

### Workers not Ready

```sh
oc get nodes
oc get events -A --sort-by='.lastTimestamp' | tail -40
```

## Stage 2 (CFK / CP)

### Operator not installing

```sh
helm list -n confluent
kubectl -n confluent get pods
kubectl -n confluent describe pod -l app=confluent-operator
```

### CRDs missing when applying manifests

Wait for CFK install; Stage 2 already sleeps ~45s after Helm. Manual retry:

```sh
kubectl apply -f terraform/cp-rosa/manifests/confluent-platform.yaml
```

### OpenShift SCC / permission issues

CFK on OpenShift usually works with the quickstart CRs. If pods are CreateContainerConfigError / SCC denied, check:

```sh
oc get scc
oc adm policy who-can use scc anyuid -n confluent
```

Consult [CFK OpenShift docs](https://docs.confluent.io/operator/current/overview.html) and the `security/openshift-security` examples in [confluent-kubernetes-examples](https://github.com/confluentinc/confluent-kubernetes-examples).

## Control Center

### Port-forward

```sh
kubectl -n confluent get pod controlcenter-0
kubectl -n confluent port-forward controlcenter-0 9021:9021
```

If the local port is busy: `kubectl -n confluent port-forward controlcenter-0 19021:9021` and open `http://localhost:19021`.

### Optional route

```sh
oc -n confluent get routes
oc -n confluent get controlcenter controlcenter -o yaml | less
```

Prefer port-forward if the route endpoint is empty or browsers show certificate errors during a live demo.

## Cleanup stuck

1. Destroy Stage 2 first (or manual `kubectl`/`helm` deletes in LAB 4)
2. Then Stage 1 `terraform destroy`
3. If OCM still shows the cluster, delete it in the console and re-run destroy to clear AWS IAM/VPC leftovers
