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
