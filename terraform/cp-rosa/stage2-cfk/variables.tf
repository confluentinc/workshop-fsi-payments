# ===============================
# Stage 2 — Variables
# ===============================

variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig for the ROSA cluster (after Stage 1 oc login)."
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "Optional kubectl context name. Leave empty to use the current context."
  default     = ""
}

variable "namespace" {
  type        = string
  description = "Namespace for CFK and Confluent Platform."
  default     = "confluent"
}

variable "cfk_chart_version" {
  type        = string
  description = "Optional Confluent for Kubernetes Helm chart version. Empty = latest from the repo."
  default     = ""
}

variable "wait_for_control_center_seconds" {
  type        = number
  description = "Seconds to wait after applying CP manifests before considering Stage 2 complete."
  default     = 120
}
