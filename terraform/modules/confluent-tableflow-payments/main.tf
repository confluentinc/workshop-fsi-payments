# ===============================
# Tableflow Topics — RiverPay Flink Data Products
# ===============================
# Append: riverflow_payments (completed payments from 4-way inner join)
# Upsert: riverflow_payments_risk_score (temporal join enrichment)
# Raw lifecycle topics are Kafka sources only — not Tableflow-enabled in Phase 1.

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.64.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

resource "time_sleep" "wait_for_flink_topics" {
  create_duration = "120s"
}

resource "confluent_tableflow_topic" "payments" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = var.payments_topic
  table_formats = ["DELTA"]

  byob_aws {
    bucket_name             = var.s3_bucket_name
    provider_integration_id = var.provider_integration_id
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }

  depends_on = [time_sleep.wait_for_flink_topics]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_tableflow_topic" "risk_score" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = var.risk_score_topic
  table_formats = ["DELTA"]

  byob_aws {
    bucket_name             = var.s3_bucket_name
    provider_integration_id = var.provider_integration_id
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }

  depends_on = [time_sleep.wait_for_flink_topics]

  lifecycle {
    prevent_destroy = false
  }
}
