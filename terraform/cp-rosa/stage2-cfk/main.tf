# ===============================
# Stage 2 — CFK Helm + Confluent Platform + RiverPay-lite
# ===============================
# Requires Stage 1 complete and `oc login` into the ROSA cluster.
# kubectl must be on PATH for local-exec applies (CRDs are not known at plan time).

locals {
  manifests_dir = abspath("${path.module}/../manifests")
  platform_yaml = "${local.manifests_dir}/confluent-platform.yaml"
  producer_yaml = "${local.manifests_dir}/riverpay-producer.yaml"
}

resource "kubernetes_namespace_v1" "confluent" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "riverpay-cp-rosa"
      "workshop.mode"             = "cp-rosa"
    }
  }
}

resource "helm_release" "confluent_operator" {
  name             = "confluent-operator"
  repository       = "https://packages.confluent.io/helm"
  chart            = "confluent-for-kubernetes"
  namespace        = kubernetes_namespace_v1.confluent.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600
  version          = var.cfk_chart_version != "" ? var.cfk_chart_version : null

  depends_on = [kubernetes_namespace_v1.confluent]
}

# Allow CFK CRDs / webhook to settle before applying platform CRs.
resource "time_sleep" "wait_cfk_crds" {
  depends_on      = [helm_release.confluent_operator]
  create_duration = "45s"
}

resource "null_resource" "apply_confluent_platform" {
  triggers = {
    platform_sha = filesha256(local.platform_yaml)
    namespace    = var.namespace
    release      = helm_release.confluent_operator.id
    yaml_path    = local.platform_yaml
  }

  provisioner "local-exec" {
    command = "kubectl apply -f '${local.platform_yaml}' --namespace '${var.namespace}'"
    environment = {
      KUBECONFIG = local.kubeconfig
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f '${self.triggers.yaml_path}' --namespace '${self.triggers.namespace}' --ignore-not-found=true || true"
    environment = {
      KUBECONFIG = pathexpand("~/.kube/config")
    }
  }

  depends_on = [time_sleep.wait_cfk_crds]
}

resource "time_sleep" "wait_kafka_ready" {
  depends_on      = [null_resource.apply_confluent_platform]
  create_duration = "${var.wait_for_control_center_seconds}s"
}

resource "null_resource" "apply_riverpay_producer" {
  triggers = {
    producer_sha = filesha256(local.producer_yaml)
    namespace    = var.namespace
    platform     = null_resource.apply_confluent_platform.id
    yaml_path    = local.producer_yaml
  }

  provisioner "local-exec" {
    command = "kubectl apply -f '${local.producer_yaml}' --namespace '${var.namespace}'"
    environment = {
      KUBECONFIG = local.kubeconfig
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f '${self.triggers.yaml_path}' --namespace '${self.triggers.namespace}' --ignore-not-found=true || true"
    environment = {
      KUBECONFIG = pathexpand("~/.kube/config")
    }
  }

  depends_on = [time_sleep.wait_kafka_ready]
}
