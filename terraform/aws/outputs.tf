output "workshop_status" {
  description = "Self-service deployment status and links"
  value = {
    environment_id     = module.confluent_platform.environment_id
    kafka_cluster_id   = module.confluent_platform.kafka_cluster_id
    flink_compute_pool = module.flink.compute_pool_id
    payments_table     = local.payments_topic
    risk_score_table   = local.risk_score_topic
    flink_mts_created  = var.enable_flink_mts
    tableflow_enabled  = var.enable_tableflow_topics
    tableflow_topics   = var.enable_tableflow_topics ? module.tableflow_payments[0].tableflow_topic_ids : null
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
  value       = <<-EOT
    RiverPay self-service (AWS) deployed.

    Kafka sources:
      - ${local.customer_profiles_topic} (CDC)
      - ${local.fx_rates_topic} (CDC)
      - lifecycle topics (initiation → status)

    Flink MTs created by Terraform: ${var.enable_flink_mts}
    Tableflow topics enabled by Terraform: ${var.enable_tableflow_topics}

    Risk API: ${local.effective_risk_api_endpoint != "" ? local.effective_risk_api_endpoint : "(disabled)"}
    Risk UDF pre-registered: ${var.enable_risk_udf}

    Databricks catalog: ${databricks_catalog.main.name}
    Databricks schema:  ${module.databricks.databricks_schema_name}

    Next: labs/self-service LAB3 (Flink MTs) → LAB4 (Tableflow) → LAB5 (Genie).
  EOT
}

output "postgres_public_dns" {
  value = local.effective_postgres_host
}

output "risk_api_url" {
  description = "Risk Scoring API base URL for Flink CONNECTION"
  value       = local.effective_risk_api_endpoint != "" ? local.effective_risk_api_endpoint : null
}

# Container-internal path when using docker-compose. For host SSH, use
# terraform/aws/sshkey-*.pem on the host filesystem.
output "ssh_key_path" {
  value = local.use_shared ? var.shared_postgres_ssh_private_key_path : module.keypair[0].private_key_path
}

output "demo_status" {
  description = "Alias of workshop_status for scripts that expect demo_status"
  value = {
    environment_id     = module.confluent_platform.environment_id
    kafka_cluster_id   = module.confluent_platform.kafka_cluster_id
    flink_compute_pool = module.flink.compute_pool_id
    payments_table     = local.payments_topic
    risk_score_table   = local.risk_score_topic
    databricks_catalog = databricks_catalog.main.name
    databricks_schema  = module.databricks.databricks_schema_name
    links = {
      confluent_tableflow = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/tableflow"
      confluent_flink     = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/flink/compute-pools/${module.flink.compute_pool_id}"
      databricks          = var.databricks_host
    }
  }
}


output "lifecycle_st_cluster" {
  description = "Cluster credentials for instructor-led multi-connection lifecycle ShadowTraffic"
  sensitive   = true
  value = {
    id                         = var.prefix
    bootstrap_endpoint         = module.confluent_platform.bootstrap_endpoint_url
    kafka_api_key              = module.confluent_platform.kafka_api_key
    kafka_api_secret           = module.confluent_platform.kafka_api_secret
    schema_registry_endpoint   = module.confluent_platform.schema_registry_endpoint
    schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
    schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret
  }
}

# ===============================
# WSA Outputs
# ===============================

output "cc_environment_url" {
  description = "WSA: Confluent Cloud console URL for this environment"
  value       = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}"
}

output "dbx_workspace_url" {
  description = "WSA: Databricks workspace URL"
  value       = var.databricks_host
}

output "dbx_sp_client_id" {
  description = "WSA: Databricks SP client ID"
  value       = local.effective_dbx_sp_client_id
}

output "dbx_sp_client_secret" {
  description = "WSA: Databricks SP secret"
  value       = local.effective_dbx_sp_client_secret
  sensitive   = true
}

output "dbx_catalog_name" {
  description = "WSA: Databricks Unity Catalog name"
  value       = databricks_catalog.main.name
}

output "dbx_schema_name" {
  description = "WSA: Databricks schema name"
  value       = module.databricks.databricks_schema_name
}

output "dbx_sql_warehouse_id" {
  description = "WSA: SQL Warehouse ID"
  value       = module.databricks.sql_warehouse_id
}

