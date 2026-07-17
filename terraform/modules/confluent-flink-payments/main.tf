# ===============================
# Flink Materialized Tables — RiverPay Payments
# ===============================
# 1. riverflow_payments — 4-way inner join (completed payments only) → append
# 2. riverflow_payments_risk_score — temporal join initiation × profile → upsert
# risk_score = operational exception probability (0–1), NOT fraud.
#
# Progressive/stall-aware payment state is Phase 2 backlog (not progressive upsert).

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.64.0"
    }
  }
}

locals {
  initiation_fqn     = "`${var.environment_name}`.`${var.kafka_cluster_display_name}`.`${var.initiation_topic}`"
  authorization_fqn  = "`${var.environment_name}`.`${var.kafka_cluster_display_name}`.`${var.authorization_topic}`"
  balance_update_fqn = "`${var.environment_name}`.`${var.kafka_cluster_display_name}`.`${var.balance_update_topic}`"
  status_fqn         = "`${var.environment_name}`.`${var.kafka_cluster_display_name}`.`${var.status_topic}`"
  profile_fqn        = "`${var.environment_name}`.`${var.kafka_cluster_display_name}`.`${var.customer_profiles_topic}`"
  flink_properties = {
    "sql.current-catalog"  = var.environment_name
    "sql.current-database" = var.kafka_cluster_display_name
  }
}

# Recreate Flink DDL/MTs when wire format / schema generation changes (e.g. JSON → Avro).
resource "terraform_data" "schema_generation" {
  input = var.schema_generation
}

# --- Profile (CDC) for temporal joins ---

resource "confluent_flink_statement" "profile_upsert" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.customer_profiles_topic}` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_statement" "profile_watermark" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  # CDC profile timestamps are epoch-millis BIGINTs; use Kafka $rowtime for temporal joins.
  statement     = "ALTER TABLE `${var.customer_profiles_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.profile_upsert]
}

# --- Lifecycle topics: append + watermarks ---

resource "confluent_flink_statement" "initiation_append" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.initiation_topic}` SET ('changelog.mode' = 'append');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_statement" "initiation_watermark" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  # Avro timestamp-millis from ShadowTraffic lands as BIGINT in Flink; use Kafka $rowtime.
  statement     = "ALTER TABLE `${var.initiation_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.initiation_append]
}

resource "confluent_flink_statement" "authorization_append" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.authorization_topic}` SET ('changelog.mode' = 'append');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_statement" "authorization_watermark" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.authorization_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.authorization_append]
}

resource "confluent_flink_statement" "balance_update_append" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.balance_update_topic}` SET ('changelog.mode' = 'append');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_statement" "balance_update_watermark" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.balance_update_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.balance_update_append]
}

resource "confluent_flink_statement" "status_append" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.status_topic}` SET ('changelog.mode' = 'append');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_statement" "status_watermark" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement     = "ALTER TABLE `${var.status_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.status_append]
}

# --- Completed payments: 4-way inner join (append data product) ---

resource "confluent_flink_materialized_table" "payments_completed" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  display_name = var.payments_table_name
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  query = <<-SQL
    SELECT
      i.`payment_id`,
      i.`customer_id`,
      i.`source_account`,
      i.`destination_account`,
      i.`amount`,
      i.`currency`,
      i.`payment_type`,
      i.`channel`,
      i.`initiated_at`,
      a.`authorization_code`,
      a.`authorized_at`,
      b.`source_balance_after`,
      b.`destination_balance_after`,
      b.`updated_at` AS `balance_updated_at`,
      s.`status`,
      s.`status_reason`,
      s.`completed_at`
    FROM ${local.initiation_fqn} i
      INNER JOIN ${local.authorization_fqn} a
        ON i.`payment_id` = a.`payment_id`
      INNER JOIN ${local.balance_update_fqn} b
        ON i.`payment_id` = b.`payment_id`
      INNER JOIN ${local.status_fqn} s
        ON i.`payment_id` = s.`payment_id`
  SQL

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [
    confluent_flink_statement.initiation_watermark,
    confluent_flink_statement.authorization_watermark,
    confluent_flink_statement.balance_update_watermark,
    confluent_flink_statement.status_watermark,
  ]

  lifecycle {
    prevent_destroy      = false
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

# --- Risk score: temporal join initiation × profile (upsert data product) ---

resource "confluent_flink_materialized_table" "payments_risk_score" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  display_name = var.risk_score_table_name
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  query = <<-SQL
    SELECT
      p.`payment_id`,
      p.`customer_id`,
      c.`segment`,
      c.`account_tier`,
      p.`amount`,
      p.`currency`,
      p.`payment_type`,
      p.`initiated_at`,
      CASE
        WHEN p.`amount` >= 10000 THEN 0.85
        WHEN p.`amount` >= 5000 AND c.`account_tier` = 'standard' THEN 0.72
        WHEN c.`segment` = 'new_partner' THEN 0.65
        WHEN p.`amount` >= 2500 THEN 0.48
        WHEN c.`account_tier` = 'premium' THEN 0.12
        ELSE 0.28
      END AS `risk_score`,
      CASE
        WHEN p.`amount` >= 10000 THEN 'amount_significantly_above_customer_baseline'
        WHEN p.`amount` >= 5000 AND c.`account_tier` = 'standard' THEN 'high_value_standard_tier'
        WHEN c.`segment` = 'new_partner' THEN 'new_partner_bank_customer'
        WHEN p.`amount` >= 2500 THEN 'elevated_amount_review_recommended'
        WHEN c.`account_tier` = 'premium' THEN 'low_value_established_recipient'
        ELSE 'routine_instant_credit_transfer'
      END AS `risk_reason`,
      CURRENT_TIMESTAMP AS `enrichment_timestamp`
    FROM ${local.initiation_fqn} p
      JOIN ${local.profile_fqn} FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
        ON c.`customer_id` = p.`customer_id`
  SQL

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [
    confluent_flink_statement.profile_watermark,
    confluent_flink_statement.initiation_watermark,
  ]

  lifecycle {
    prevent_destroy      = false
    replace_triggered_by = [terraform_data.schema_generation]
  }
}
