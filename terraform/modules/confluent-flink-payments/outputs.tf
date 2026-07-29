output "payments_table_name" {
  value = var.enable_materialized_tables ? confluent_flink_materialized_table.payments_completed[0].display_name : var.payments_table_name
}

output "risk_score_table_name" {
  value = var.enable_materialized_tables ? confluent_flink_materialized_table.payments_risk_score[0].display_name : var.risk_score_table_name
}

output "risk_udf_artifact_id" {
  description = "Flink artifact ID when enable_risk_udf=true"
  value       = var.enable_risk_udf ? confluent_flink_artifact.risk_udf[0].id : null
}

output "materialized_tables_enabled" {
  value = var.enable_materialized_tables
}
