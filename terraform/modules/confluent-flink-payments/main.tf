# ===============================
# Flink Materialized Tables — RiverPay Payments
# ===============================
# 1. riverflow_payments — 4-way inner join + FX temporal join → append
# 2. riverflow_payments_risk_score — temporal join initiation × profile → append
#    (external risk UDF replaces CASE heuristics in Elevate follow-on work)
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
  fx_rates_fqn       = "`${var.environment_name}`.`${var.kafka_cluster_display_name}`.`${var.fx_rates_topic}`"
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

  statement_name = "customer-profiles-enable-upsert"
  statement      = "ALTER TABLE `${var.customer_profiles_topic}` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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
  statement_name = "customer-profiles-watermark"
  statement      = "ALTER TABLE `${var.customer_profiles_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.profile_upsert]
}

# --- FX rates (CDC) for temporal joins ---

resource "confluent_flink_statement" "fx_rates_upsert" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement_name = "fx-rates-enable-upsert"
  statement      = "ALTER TABLE `${var.fx_rates_topic}` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_statement" "fx_rates_watermark" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement_name = "fx-rates-watermark"
  statement      = "ALTER TABLE `${var.fx_rates_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.fx_rates_upsert]
}

# --- Lifecycle topics: append + watermarks ---

resource "confluent_flink_statement" "initiation_append" {
  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement_name = "payments-initiation-enable-append"
  statement      = "ALTER TABLE `${var.initiation_topic}` SET ('changelog.mode' = 'append');"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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
  statement_name = "payments-initiation-watermark"
  statement      = "ALTER TABLE `${var.initiation_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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

  statement_name = "payments-authorization-enable-append"
  statement      = "ALTER TABLE `${var.authorization_topic}` SET ('changelog.mode' = 'append');"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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

  statement_name = "payments-authorization-watermark"
  statement      = "ALTER TABLE `${var.authorization_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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

  statement_name = "balance-update-enable-append"
  statement      = "ALTER TABLE `${var.balance_update_topic}` SET ('changelog.mode' = 'append');"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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

  statement_name = "balance-update-watermark"
  statement      = "ALTER TABLE `${var.balance_update_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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

  statement_name = "payments-status-enable-append"
  statement      = "ALTER TABLE `${var.status_topic}` SET ('changelog.mode' = 'append');"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

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

  statement_name = "payments-status-watermark"
  statement      = "ALTER TABLE `${var.status_topic}` MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;"
  properties     = local.flink_properties
  rest_endpoint  = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }

  depends_on = [confluent_flink_statement.status_append]
}

# --- Completed payments: 4-way inner join + FX temporal join (append data product) ---

resource "confluent_flink_materialized_table" "payments_completed" {
  count = var.enable_materialized_tables ? 1 : 0

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
      fx.`rate_to_usd`,
      ROUND(i.`amount` * fx.`rate_to_usd`, 2) AS `amount_usd`,
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
      JOIN ${local.fx_rates_fqn} FOR SYSTEM_TIME AS OF i.`$rowtime` AS fx
        ON fx.`currency_code` = i.`currency`
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
    confluent_flink_statement.fx_rates_watermark,
  ]

  lifecycle {
    prevent_destroy      = false
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

# --- Risk score: profile TTJ + CASE (default) or external UDF (optional) ---

locals {
  risk_case_query = <<-SQL
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

  risk_udf_query = <<-SQL
    SELECT
      enriched.`payment_id`,
      enriched.`customer_id`,
      enriched.`segment`,
      enriched.`account_tier`,
      enriched.`amount`,
      enriched.`currency`,
      enriched.`payment_type`,
      enriched.`initiated_at`,
      CAST(SPLIT_INDEX(enriched.`risk_payload`, '|', 0) AS DOUBLE) AS `risk_score`,
      SPLIT_INDEX(enriched.`risk_payload`, '|', 1) AS `risk_reason`,
      CURRENT_TIMESTAMP AS `enrichment_timestamp`
    FROM (
      SELECT
        p.`payment_id`,
        p.`customer_id`,
        c.`segment`,
        c.`account_tier`,
        p.`amount`,
        p.`currency`,
        p.`payment_type`,
        p.`initiated_at`,
        lookup_operational_risk(p.`amount`, c.`segment`, c.`account_tier`) AS `risk_payload`
      FROM ${local.initiation_fqn} p
        JOIN ${local.profile_fqn} FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
          ON c.`customer_id` = p.`customer_id`
    ) AS enriched
  SQL
}

resource "confluent_flink_artifact" "risk_udf" {
  count = var.enable_risk_udf ? 1 : 0

  cloud          = upper(var.cloud)
  region         = var.cloud_region
  display_name   = "riverpay-risk-udf"
  content_format = "JAR"
  artifact_file  = var.risk_udf_jar_path

  environment {
    id = var.environment_id
  }
}

resource "confluent_flink_statement" "risk_api_connection" {
  count = var.enable_risk_udf ? 1 : 0

  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement_name = "create-risk-api-connection"
  statement      = <<-SQL
    CREATE CONNECTION IF NOT EXISTS riverpay_risk_api
    WITH (
      'type' = 'rest',
      'endpoint' = '${var.risk_api_endpoint}',
      'token' = '${var.risk_api_key}'
    );
  SQL

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

resource "confluent_flink_statement" "risk_udf_function" {
  count = var.enable_risk_udf ? 1 : 0

  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  statement_name = "create-risk-scoring-udf"
  statement      = <<-SQL
    CREATE FUNCTION IF NOT EXISTS lookup_operational_risk
      AS 'io.confluent.riverpay.udf.LookupOperationalRisk'
      USING JAR 'confluent-artifact://${confluent_flink_artifact.risk_udf[0].id}'
      USING CONNECTIONS (`riverpay_risk_api`);
  SQL

  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [
    confluent_flink_artifact.risk_udf,
    confluent_flink_statement.risk_api_connection,
  ]

  lifecycle {
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

resource "confluent_flink_materialized_table" "payments_risk_score" {
  count = var.enable_materialized_tables ? 1 : 0

  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  display_name = var.risk_score_table_name
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  query = var.enable_risk_udf ? local.risk_udf_query : local.risk_case_query

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [
    confluent_flink_statement.profile_watermark,
    confluent_flink_statement.initiation_watermark,
    confluent_flink_statement.risk_udf_function,
  ]

  lifecycle {
    prevent_destroy      = false
    replace_triggered_by = [terraform_data.schema_generation]
  }
}

# --- Customer risk exposure: trailing-24h OVER aggregation over riverflow_payments_risk_score ---
# PRIMARY KEY + upsert changelog.mode collapse the per-event OVER output to one row per customer.

locals {
  customer_risk_exposure_query = <<-SQL
    WITH risk_last_24h AS (
      SELECT
        customer_id,
        segment,
        account_tier,
        COUNT(*) OVER w AS payment_count,
        AVG(risk_score) OVER w AS avg_risk_score,
        MAX(risk_score) OVER w AS max_risk_score,
        `$rowtime` AS updated_at
      FROM ${var.risk_score_table_name}
      WINDOW w AS (
        PARTITION BY customer_id
        ORDER BY `$rowtime`
        RANGE BETWEEN INTERVAL '24' HOUR PRECEDING AND CURRENT ROW
      )
    )
    SELECT * FROM risk_last_24h
  SQL
}

resource "confluent_flink_materialized_table" "customer_risk_exposure" {
  count = var.enable_materialized_tables ? 1 : 0

  organization { id = var.organization_id }
  environment { id = var.environment_id }
  compute_pool { id = var.compute_pool_id }
  principal { id = var.service_account_id }

  display_name = var.customer_risk_exposure_table_name
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  query = local.customer_risk_exposure_query

  constraints {
    name     = "pk_customer_id"
    type     = "PRIMARY_KEY"
    columns  = ["customer_id"]
    enforced = false
  }

  table_options = {
    "changelog.mode"       = "upsert"
    "kafka.cleanup-policy" = "compact"
  }

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [
    confluent_flink_materialized_table.payments_risk_score,
  ]

  lifecycle {
    prevent_destroy      = false
    replace_triggered_by = [terraform_data.schema_generation]
  }
}
