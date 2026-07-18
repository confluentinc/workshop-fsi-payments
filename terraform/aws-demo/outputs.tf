output "demo_status" {
  description = "High-level demo deployment status and links"
  value = {
    environment_id     = module.confluent_platform.environment_id
    kafka_cluster_id   = module.confluent_platform.kafka_cluster_id
    flink_compute_pool = module.flink.compute_pool_id
    payments_table     = module.flink_payments.payments_table_name
    risk_score_table   = module.flink_payments.risk_score_table_name
    tableflow_topics   = module.tableflow_payments.tableflow_topic_ids
    databricks_catalog = databricks_catalog.main.name
    databricks_schema  = module.databricks.databricks_schema_name
    links = {
      confluent_tableflow = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/tableflow"
      confluent_flink     = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/flink/compute-pools/${module.flink.compute_pool_id}"
      databricks          = var.databricks_host
    }
  }
}

output "workshop_summary" {
  description = "Human-readable workshop summary"
  value = <<-EOT
    RiverPay demo deployed.

    Kafka sources (not Tableflow'd):
      - ${local.customer_profiles_topic} (CDC)
      - ${local.initiation_topic}
      - ${local.authorization_topic}
      - ${local.balance_update_topic}
      - ${local.status_topic}

    Flink data products → Tableflow:
      - ${local.payments_topic} (append — completed payments, 4-way inner join)
      - ${local.risk_score_topic} (upsert — initiation × profile temporal join)

    Databricks catalog: ${databricks_catalog.main.name}
    Databricks schema:  ${module.databricks.databricks_schema_name}
    Views: riverpulse_high_risk_payments, riverpulse_customer_risk_7d, riverpulse_lifecycle_completion

    Next: open Genie and ask the three RiverPulse business questions (LAB3).
  EOT
}

output "postgres_public_dns" {
  value = module.postgres.public_dns
}

# Container-internal path when using docker-compose. For host SSH (LAB4), use
# terraform/aws-demo/sshkey-*.pem on the host filesystem instead.
output "ssh_key_path" {
  value = module.keypair.private_key_path
}

output "ssh_key_filename" {
  description = "SSH private key basename under terraform/aws-demo (use on the host for LAB4)"
  value       = basename(module.keypair.private_key_path)
}

output "confluent_flink" {
  value = {
    compute_pool_id = module.flink.compute_pool_id
    rest_endpoint   = module.flink.flink_rest_endpoint
  }
}

output "confluent_tableflow" {
  value = {
    integration_id = module.tableflow.integration_id
  }
}
