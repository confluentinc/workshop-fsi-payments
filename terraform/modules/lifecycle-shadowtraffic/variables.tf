variable "clusters" {
  description = "Per-attendee Kafka/SR credentials (one connection + 4 lifecycle generators each)"
  type = list(object({
    id                         = string
    bootstrap_endpoint         = string
    kafka_api_key              = string
    kafka_api_secret           = string
    schema_registry_endpoint   = string
    schema_registry_api_key    = string
    schema_registry_api_secret = string
  }))
  default = []
}

variable "ssh_host" {
  description = "Shared Postgres/datagen VM public IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH username on the shared VM"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Absolute path to SSH private key for the shared VM"
  type        = string
}

variable "shadowtraffic_image" {
  description = "ShadowTraffic Docker image (pin 2.x)"
  type        = string
  default     = "shadowtraffic/shadowtraffic:2.0.3"
}

variable "generator_template_path" {
  description = "Path to riverpay-generator-kafka.json (single-cluster template)"
  type        = string
  default     = ""
}

variable "container_name" {
  description = "Docker container name for the multi-cluster lifecycle ST"
  type        = string
  default     = "shadowtraffic-lifecycle"
}

variable "remote_dir" {
  description = "Remote directory for config/license on the shared VM"
  type        = string
  default     = "/opt/shadowtraffic-lifecycle"
}

variable "initiation_throttle_ms" {
  description = "Override throttleMs on each cluster's payment_initiation generator (ST 2.0 is faster)"
  type        = number
  default     = 2500
}

variable "metrics_port" {
  description = "Prometheus metrics port (0 = random; avoid collision with shared Postgres ST on 9400)"
  type        = number
  default     = 0
}

variable "enabled" {
  description = "When false, skip deploy (empty clusters also skips)"
  type        = bool
  default     = true
}
