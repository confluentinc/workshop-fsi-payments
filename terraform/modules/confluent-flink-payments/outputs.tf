output "payments_table_name" {
  value = confluent_flink_materialized_table.payments_completed.display_name
}

output "risk_score_table_name" {
  value = confluent_flink_materialized_table.payments_risk_score.display_name
}
