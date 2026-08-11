variable "clusters" {
  description = "Per-attendee Kafka/SR credentials from account terraform outputs (lifecycle_st_cluster)"
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
  description = "Shared Postgres/datagen VM public IP (azure-shared postgres_public_ip)"
  type        = string
}

variable "ssh_user" {
  description = "SSH username on the shared VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_private_key_path" {
  description = "Absolute path to shared VM SSH private key"
  type        = string
}

variable "shadowtraffic_image" {
  description = "ShadowTraffic Docker image (pin 2.x)"
  type        = string
  default     = "shadowtraffic/shadowtraffic:2.0.3"
}

variable "initiation_throttle_ms" {
  description = "throttleMs on each cluster payment_initiation generator"
  type        = number
  default     = 2500
}

variable "metrics_port" {
  description = "Prometheus metrics port (0 = random; avoid :9400 used by shared Postgres ST)"
  type        = number
  default     = 0
}

variable "enabled" {
  description = "When false, skip deploy"
  type        = bool
  default     = true
}
