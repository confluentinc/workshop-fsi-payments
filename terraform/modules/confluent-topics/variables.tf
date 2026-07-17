variable "kafka_cluster_id" {
  type = string
}

variable "rest_endpoint" {
  type = string
}

variable "api_key" {
  type      = string
  sensitive = true
}

variable "api_secret" {
  type      = string
  sensitive = true
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

variable "partitions" {
  type    = number
  default = 6
}

variable "wire_format" {
  description = "Lifecycle topic wire format. Changing this recreates topics (e.g. schemaless JSON → Avro)."
  type        = string
  default     = "avro"
}
