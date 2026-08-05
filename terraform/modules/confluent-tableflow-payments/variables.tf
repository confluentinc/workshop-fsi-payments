variable "environment_id" { type = string }
variable "kafka_cluster_id" { type = string }
variable "s3_bucket_name" { type = string }
variable "provider_integration_id" { type = string }
variable "api_key" {
  type      = string
  sensitive = true
}
variable "api_secret" {
  type      = string
  sensitive = true
}
variable "payments_topic" {
  type    = string
  default = "riverflow_payments"
}
variable "risk_score_topic" {
  type    = string
  default = "riverflow_payments_risk_score"
}
variable "customer_risk_exposure_topic" {
  type    = string
  default = "riverflow_customer_risk_exposure_24h"
}

variable "data_retention_ms" {
  description = "Tableflow data TTL (row expiration). Minimum allowed by Confluent is 2592000000 (30 days)."
  type        = string
  default     = "2592000000"
}

variable "snapshot_retention_ms" {
  description = "Max age of Delta table versions/snapshots to retain (milliseconds)."
  type        = string
  default     = "604800000" # 7 days
}
