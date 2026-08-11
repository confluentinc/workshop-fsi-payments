output "tableflow_topic_ids" {
  value = {
    payments               = confluent_tableflow_topic.payments.id
    risk_score              = confluent_tableflow_topic.risk_score.id
    customer_risk_exposure  = confluent_tableflow_topic.customer_risk_exposure.id
  }
}
