output "topic_names" {
  value = { for k, t in confluent_kafka_topic.lifecycle : k => t.topic_name }
}
