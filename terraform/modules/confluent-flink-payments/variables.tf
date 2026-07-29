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
variable "fx_rates_topic" {
  type    = string
  default = "riverflow.riverpay.fx_rates"
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
  default     = "avro-v2-fx"
}

variable "enable_risk_udf" {
  description = "Use external risk UDF instead of inline CASE heuristics"
  type        = bool
  default     = false
}

variable "enable_materialized_tables" {
  description = "Create Flink MTs for completed payments and risk_score (false = ALTER/UDF only; attendees create MTs in labs)"
  type        = bool
  default     = true
}

variable "risk_api_endpoint" {
  description = "Base URL for shared Risk Scoring API (used in CREATE CONNECTION)"
  type        = string
  default     = ""
}

variable "risk_api_key" {
  description = "API key for Risk Scoring REST CONNECTION"
  type        = string
  sensitive   = true
  default     = ""
}

variable "risk_udf_jar_path" {
  description = "Local path to riverpay-risk-udf JAR when enable_risk_udf=true"
  type        = string
  default     = "../../udf/riverpay-risk/dist/riverpay-risk-udf-1.0.0.jar"
}

variable "cloud" {
  description = "Cloud provider for Flink artifact (AWS / AZURE / GCP)"
  type        = string
  default     = "AWS"
}

variable "cloud_region" {
  description = "Cloud region for Flink artifact"
  type        = string
  default     = "us-east-1"
}
