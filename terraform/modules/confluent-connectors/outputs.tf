# ===============================
# Confluent Connectors Module Outputs
# ===============================

output "connector_id" {
  description = "PostgreSQL CDC connector ID"
  value       = confluent_connector.postgres_cdc.id
}

output "connector_name" {
  description = "PostgreSQL CDC connector name"
  value       = confluent_connector.postgres_cdc.config_nonsensitive["name"]
}

output "connector_status" {
  description = "PostgreSQL CDC connector status"
  value       = confluent_connector.postgres_cdc.status
}

output "topics" {
  description = "Topics created by the connector"
  value = {
    customer_profiles_topic = "${var.topic_prefix}.riverpay.customer_profiles"
    heartbeat_topic         = "__debezium-heartbeat-${var.topic_prefix}"
  }
}
