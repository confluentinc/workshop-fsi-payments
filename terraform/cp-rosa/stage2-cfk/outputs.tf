# ===============================
# Stage 2 — Outputs
# ===============================

output "namespace" {
  description = "Namespace where CFK and Confluent Platform run."
  value       = var.namespace
}

output "topics" {
  description = "RiverPay-lite lifecycle topics."
  value = [
    "riverflow.payments.initiation",
    "riverflow.payments.authorization",
    "riverflow.payments.balance_update",
    "riverflow.payments.status",
  ]
}

output "port_forward_command" {
  description = "Default Control Center access (recommended for recordings)."
  value       = "kubectl -n ${var.namespace} port-forward controlcenter-0 9021:9021"
}

output "control_center_url" {
  description = "Local URL after port-forward."
  value       = "http://localhost:9021"
}

output "verify_commands" {
  description = "Quick validation commands."
  value       = <<-EOT
    kubectl -n ${var.namespace} get pods
    kubectl -n ${var.namespace} get kafkatopic
    kubectl -n ${var.namespace} logs -l app=riverpay-producer --tail=20
    kubectl -n ${var.namespace} port-forward controlcenter-0 9021:9021
    # then open http://localhost:9021 and inspect riverflow.payments.* topics
  EOT
}

output "optional_route_hint" {
  description = "Optional OpenShift route for Control Center (after base demo works)."
  value       = <<-EOT
    export APPS_DOMAIN="apps.$$(oc get dns cluster -o jsonpath='{.spec.baseDomain}')"
    sed "s/APPS_DOMAIN/$${APPS_DOMAIN}/g" ../manifests/controlcenter-route-patch.yaml | oc apply -f -
    oc -n ${var.namespace} get routes
    oc -n ${var.namespace} get controlcenter controlcenter -ojsonpath='{.status.restConfig.externalEndpoint}{"\n"}'
  EOT
}
