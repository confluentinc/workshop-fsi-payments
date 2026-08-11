# ===============================
# Kafka Topics — RiverFlow Payment Lifecycle
# ===============================

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

locals {
  lifecycle_topics = {
    initiation     = var.initiation_topic
    authorization  = var.authorization_topic
    balance_update = var.balance_update_topic
    status         = var.status_topic
  }
}

# Changing wire_format recreates topics so prior schemaless JSON is wiped.
resource "terraform_data" "wire_format" {
  input = var.wire_format
}

resource "confluent_kafka_topic" "lifecycle" {
  for_each = local.lifecycle_topics

  kafka_cluster {
    id = var.kafka_cluster_id
  }

  topic_name       = each.value
  partitions_count = var.partitions
  rest_endpoint    = var.rest_endpoint

  config = {
    "cleanup.policy" = "delete"
    "retention.ms"   = "604800000" # 7 days
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }

  lifecycle {
    prevent_destroy      = false
    replace_triggered_by = [terraform_data.wire_format]
  }
}
