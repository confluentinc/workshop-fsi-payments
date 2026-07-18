variable "organization_id" { type = string }
variable "environment_id" { type = string }
variable "environment_name" { type = string }
variable "compute_pool_id" { type = string }
variable "service_account_id" { type = string }
variable "kafka_cluster_id" { type = string }
variable "kafka_cluster_display_name" { type = string }
variable "flink_rest_endpoint" { type = string }
variable "flink_api_key" {
  type      = string
  sensitive = true
}
variable "flink_api_secret" {
  type      = string
  sensitive = true
}
variable "customer_profiles_topic" {
  type    = string
  default = "riverflow.riverpay.customer_profiles"
}
variable "initiation_topic" {
  type    = string
  default = "riverflow.payments.initiation"
}
variable "authorization_topic" {
  type    = string
  default = "riverflow.payments.authorization"
}
variable "balance_update_topic" {
  type    = string
  default = "riverflow.payments.balance_update"
}
variable "status_topic" {
  type    = string
  default = "riverflow.payments.status"
}
variable "payments_table_name" {
  description = "Flink MT name for completed payments (4-way inner join, append)"
  type        = string
  default     = "riverflow_payments"
}
variable "risk_score_table_name" {
  description = "Flink MT name for operational risk scores (upsert)"
  type        = string
  default     = "riverflow_payments_risk_score"
}

variable "schema_generation" {
  description = "Bump to recreate Flink statements after wire-format changes (e.g. JSON → Avro)."
  type        = string
  default     = "avro-v1"
}
