# ===============================
# Stage 2 — Providers (Helm / Kubernetes)
# ===============================

locals {
  kubeconfig = pathexpand(var.kubeconfig_path)
}

provider "kubernetes" {
  config_path    = local.kubeconfig
  config_context = var.kube_context != "" ? var.kube_context : null
}

provider "helm" {
  kubernetes {
    config_path    = local.kubeconfig
    config_context = var.kube_context != "" ? var.kube_context : null
  }
}
