# ===============================
# Root Terraform — RiverPay FSI Payments Self-Service (AWS)
# ===============================
# BYO accounts. One apply provisions infra + CDC + topics + ST + Risk API/UDF
# plumbing. Flink MTs and Tableflow topic enablement are OFF by default —
# attendees complete those in labs/self-service (instructor-led shape).
# Demo mode remains terraform/aws-demo (MTs + Tableflow automated).

resource "random_id" "env_display_id" {
  byte_length = 4
}

locals {
  prefix          = "${var.prefix}-${var.project_name}"
  resource_suffix = random_id.env_display_id.hex

  # Instructor-led: aws-shared injects shared_vpc_id (and related shared_*).
  use_shared = var.shared_vpc_id != ""

  common_tags = {
    Project     = "RiverPay FSI Payments"
    Environment = var.environment
    Created_by  = "Terraform"
    owner_email = var.confluent_cloud_email
    mode        = local.use_shared ? "instructor-led" : "self-service"
  }

  iam_role_name = "${local.prefix}-unified-role-${local.resource_suffix}"

  effective_aws_account_id = local.use_shared ? var.shared_aws_account_id : module.networking[0].aws_account_id
  effective_s3_bucket_arn  = local.use_shared ? var.shared_s3_bucket_arn : module.s3[0].bucket_arn
  effective_s3_bucket_name = local.use_shared ? var.shared_s3_bucket_name : module.s3[0].bucket_name
  effective_s3_bucket_url  = local.use_shared ? var.shared_s3_bucket_url : module.s3[0].bucket_url
  effective_postgres_host = local.use_shared ? (
    var.shared_postgres_hostname != "" ? var.shared_postgres_hostname : var.shared_postgres_public_ip
  ) : module.postgres[0].public_dns
  effective_postgres_db_password       = local.use_shared && var.shared_postgres_db_password != "" ? var.shared_postgres_db_password : var.postgres_db_password
  effective_postgres_debezium_password = local.use_shared && var.shared_postgres_debezium_password != "" ? var.shared_postgres_debezium_password : var.postgres_debezium_password
  effective_ssh_key_path               = local.use_shared ? var.shared_postgres_ssh_private_key_path : module.keypair[0].private_key_path
  effective_risk_api_endpoint = (
    var.shared_risk_api_endpoint != "" ? var.shared_risk_api_endpoint :
    (var.enable_risk_api && !local.use_shared ? "http://${module.postgres[0].public_dns}:8089" : "")
  )
  effective_risk_api_key         = var.shared_risk_api_key != "" ? var.shared_risk_api_key : var.risk_api_key
  effective_dbx_sp_client_id     = var.shared_dbx_sp_client_id != "" ? var.shared_dbx_sp_client_id : var.databricks_service_principal_client_id
  effective_dbx_sp_client_secret = var.shared_dbx_sp_client_secret != "" ? var.shared_dbx_sp_client_secret : var.databricks_service_principal_client_secret

  customer_profiles_topic = "riverflow.riverpay.customer_profiles"
  fx_rates_topic          = "riverflow.riverpay.fx_rates"
  initiation_topic        = "riverflow.payments.initiation"
  authorization_topic     = "riverflow.payments.authorization"
  balance_update_topic    = "riverflow.payments.balance_update"
  status_topic            = "riverflow.payments.status"
  payments_topic          = "riverflow_payments"
  risk_score_topic        = "riverflow_payments_risk_score"
}

# ===============================
# AWS Networking / Keypair / S3 / Postgres
# ===============================

module "networking" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-networking"

  prefix      = local.prefix
  common_tags = local.common_tags
}

module "keypair" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-keypair"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  output_path     = path.module
  common_tags     = local.common_tags
}

module "s3" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-s3"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  common_tags     = local.common_tags
}

module "confluent_platform" {
  source = "../modules/confluent-platform"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  cloud           = "AWS"
  cloud_region    = var.cloud_region
  environment_id  = var.cc_environment_id
  user_email      = var.confluent_cloud_email
}

module "tableflow" {
  source = "../modules/confluent-tableflow"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  environment_id  = module.confluent_platform.environment_id
  cloud_provider  = "aws"

  customer_iam_role_arn = "arn:aws:iam::${local.effective_aws_account_id}:role/${local.iam_role_name}"

  depends_on = [module.confluent_platform]
}

module "flink" {
  source = "../modules/confluent-flink"

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  cloud                       = "AWS"
  cloud_region                = var.cloud_region
  environment_id              = module.confluent_platform.environment_id
  service_account_id          = module.confluent_platform.service_account_id
  service_account_api_version = module.confluent_platform.service_account_api_version
  service_account_kind        = module.confluent_platform.service_account_kind

  depends_on = [module.confluent_platform]
}

module "postgres" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-postgres"

  prefix              = local.prefix
  vpc_id              = module.networking[0].vpc_id
  subnet_id           = module.networking[0].public_subnet_id
  key_name            = module.keypair[0].key_name
  instance_type       = var.postgres_instance_type
  allowed_cidr_blocks = var.allowed_cidr_blocks
  db_name             = var.postgres_db_name
  db_username         = var.postgres_db_username
  db_password         = var.postgres_db_password
  debezium_password   = var.postgres_debezium_password
  common_tags         = local.common_tags

  depends_on = [module.networking, module.keypair]
}

module "iam" {
  source = "./modules/aws-iam"

  prefix                                    = local.prefix
  resource_suffix                           = local.resource_suffix
  aws_account_id                            = local.effective_aws_account_id
  s3_bucket_arn                             = local.effective_s3_bucket_arn
  s3_bucket_id                              = local.effective_s3_bucket_name
  confluent_iam_role_arn                    = module.tableflow.iam_role_arn
  confluent_external_id                     = module.tableflow.external_id
  databricks_account_id                     = var.databricks_account_id
  databricks_storage_credential_external_id = ""
  common_tags                               = local.common_tags

  depends_on = [module.s3, module.tableflow]
}

module "databricks" {
  source = "../modules/databricks"

  providers = {
    databricks.workspace = databricks.workspace
  }

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  cloud_provider              = "aws"
  iam_role_arn                = module.iam.role_arn
  s3_bucket_url               = local.effective_s3_bucket_url
  user_email                  = var.databricks_user_email
  sso_email                   = var.databricks_sso_email
  service_principal_client_id = local.effective_dbx_sp_client_id
  kafka_cluster_id            = module.confluent_platform.kafka_cluster_id
  sql_warehouse_name          = var.databricks_sql_warehouse_name
  lookup_existing_users       = !local.use_shared
  add_user_to_admins          = !local.use_shared

  depends_on = [module.iam, module.s3, module.tableflow]
}

# IAM trust policy phases (Databricks + Tableflow)
resource "null_resource" "update_iam_trust_policy_phase1" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      aws iam update-assume-role-policy \
        --role-name ${module.iam.role_name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": { "AWS": "arn:aws:iam::414351767826:root" },
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${module.databricks.storage_credential_external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": { "AWS": "arn:aws:iam::${local.effective_aws_account_id}:root" }
            }
          ]
        }'
    EOT
  }

  triggers = {
    storage_credential_id = module.databricks.storage_credential_id
    role_arn              = module.iam.role_arn
  }

  depends_on = [module.databricks, module.iam]
}

resource "time_sleep" "wait_trust_phase1" {
  create_duration = "60s"
  depends_on      = [null_resource.update_iam_trust_policy_phase1]
}

resource "null_resource" "update_iam_trust_policy_phase2" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      aws iam update-assume-role-policy \
        --role-name ${module.iam.role_name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": { "AWS": "${module.tableflow.iam_role_arn}" },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${module.tableflow.external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Principal": { "AWS": "${module.tableflow.iam_role_arn}" },
              "Action": "sts:TagSession"
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": { "AWS": "arn:aws:iam::414351767826:root" },
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${module.databricks.storage_credential_external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": { "AWS": "${module.iam.role_arn}" }
            }
          ]
        }'
    EOT
  }

  triggers = {
    storage_credential_id = module.databricks.storage_credential_id
    phase                 = "final"
  }

  depends_on = [time_sleep.wait_trust_phase1, module.tableflow, module.databricks]
}

resource "time_sleep" "wait_trust_phase2" {
  create_duration = "30s"
  depends_on      = [null_resource.update_iam_trust_policy_phase2]
}

resource "databricks_external_location" "main" {
  count    = local.use_shared ? 0 : 1
  provider = databricks.workspace

  name            = "${local.prefix}-external-location-${local.resource_suffix}"
  url             = local.effective_s3_bucket_url
  credential_name = module.databricks.storage_credential_name
  comment         = "External location for Unity Catalog and Tableflow S3 access"
  force_destroy   = true
  skip_validation = true

  depends_on = [time_sleep.wait_trust_phase2]
}

resource "databricks_grants" "external_location" {
  count    = local.use_shared ? 0 : 1
  provider = databricks.workspace

  external_location = databricks_external_location.main[0].name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE", "CREATE_EXTERNAL_VOLUME",
      "READ_FILES", "WRITE_FILES", "CREATE_MANAGED_STORAGE", "EXTERNAL_USE_LOCATION"
    ]
  }

  grant {
    principal = local.effective_dbx_sp_client_id
    privileges = [
      "ALL_PRIVILEGES", "MANAGE", "CREATE_EXTERNAL_TABLE", "CREATE_EXTERNAL_VOLUME",
      "READ_FILES", "WRITE_FILES", "CREATE_MANAGED_STORAGE", "EXTERNAL_USE_LOCATION"
    ]
  }

  depends_on = [module.databricks]
}

resource "databricks_catalog" "main" {
  provider = databricks.workspace

  name          = "${local.prefix}-${local.resource_suffix}"
  comment       = "RiverPulse catalog for Confluent Tableflow integration"
  storage_root  = "${local.effective_s3_bucket_url}${local.prefix}/catalog/"
  force_destroy = true

  depends_on = [module.databricks, databricks_external_location.main]
}

resource "databricks_grants" "catalog" {
  provider = databricks.workspace

  catalog = databricks_catalog.main.name

  grant {
    principal  = var.databricks_user_email
    privileges = ["ALL_PRIVILEGES", "USE_CATALOG", "CREATE_SCHEMA", "USE_SCHEMA", "EXTERNAL_USE_SCHEMA"]
  }

  grant {
    principal  = local.effective_dbx_sp_client_id
    privileges = ["ALL_PRIVILEGES", "USE_CATALOG", "CREATE_SCHEMA", "USE_SCHEMA", "EXTERNAL_USE_SCHEMA", "CREATE_TABLE"]
  }

  depends_on = [databricks_catalog.main]
}

# ===============================
# Lifecycle topics + CDC + ShadowTraffic
# ===============================

module "topics" {
  source = "../modules/confluent-topics"

  kafka_cluster_id     = module.confluent_platform.kafka_cluster_id
  rest_endpoint        = module.confluent_platform.kafka_rest_endpoint
  api_key              = module.confluent_platform.kafka_api_key
  api_secret           = module.confluent_platform.kafka_api_secret
  initiation_topic     = local.initiation_topic
  authorization_topic  = local.authorization_topic
  balance_update_topic = local.balance_update_topic
  status_topic         = local.status_topic
  wire_format          = "avro-v1"

  depends_on = [module.confluent_platform]
}

module "connectors" {
  source = "../modules/confluent-connectors"

  prefix               = local.prefix
  environment_id       = module.confluent_platform.environment_id
  kafka_cluster_id     = module.confluent_platform.kafka_cluster_id
  service_account_id   = module.confluent_platform.service_account_id
  postgres_hostname    = local.effective_postgres_host
  postgres_port        = var.postgres_db_port
  database_name        = var.postgres_db_name
  debezium_username    = var.postgres_debezium_username
  debezium_password    = local.effective_postgres_debezium_password
  table_include_list   = var.table_include_list
  topic_prefix         = "riverflow"
  ssh_key_path         = local.use_shared ? "" : local.effective_ssh_key_path
  initial_wait_seconds = local.use_shared ? 0 : 90

  depends_on = [module.postgres, module.confluent_platform, module.keypair]
}

# ShadowTraffic deploy is in shadowtraffic.tf

resource "confluent_api_key" "tableflow" {
  display_name = "${local.prefix}-tableflow-${local.resource_suffix}"

  owner {
    id          = module.confluent_platform.service_account_id
    api_version = module.confluent_platform.service_account_api_version
    kind        = module.confluent_platform.service_account_kind
  }

  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"

    environment {
      id = module.confluent_platform.environment_id
    }
  }

  depends_on = [module.confluent_platform]
}

module "catalog_integration" {
  source = "../modules/confluent-catalog-integration"

  prefix           = local.prefix
  resource_suffix  = local.resource_suffix
  environment_id   = module.confluent_platform.environment_id
  kafka_cluster_id = module.confluent_platform.kafka_cluster_id

  databricks_workspace_url    = var.databricks_host
  databricks_catalog_name     = databricks_catalog.main.name
  databricks_sp_client_id     = var.databricks_service_principal_client_id
  databricks_sp_client_secret = var.databricks_service_principal_client_secret

  api_key    = confluent_api_key.tableflow.id
  api_secret = confluent_api_key.tableflow.secret

  depends_on = [
    module.connectors,
    databricks_catalog.main,
    confluent_api_key.tableflow,
  ]
}

module "flink_payments" {
  source = "../modules/confluent-flink-payments"

  organization_id            = module.confluent_platform.organization_id
  environment_id             = module.confluent_platform.environment_id
  environment_name           = module.confluent_platform.environment_name
  kafka_cluster_id           = module.confluent_platform.kafka_cluster_id
  kafka_cluster_display_name = module.confluent_platform.kafka_cluster_display_name
  compute_pool_id            = module.flink.compute_pool_id
  service_account_id         = module.confluent_platform.service_account_id
  flink_api_key              = module.flink.flink_api_key
  flink_api_secret           = module.flink.flink_api_secret
  flink_rest_endpoint        = module.flink.flink_rest_endpoint

  customer_profiles_topic = local.customer_profiles_topic
  fx_rates_topic          = local.fx_rates_topic
  initiation_topic        = local.initiation_topic
  authorization_topic     = local.authorization_topic
  balance_update_topic    = local.balance_update_topic
  status_topic            = local.status_topic
  payments_table_name     = local.payments_topic
  risk_score_table_name   = local.risk_score_topic
  schema_generation       = "avro-v5-risk-udf"

  cloud        = "AWS"
  cloud_region = var.cloud_region

  enable_risk_udf   = var.enable_risk_udf
  risk_api_endpoint = var.enable_risk_udf ? local.effective_risk_api_endpoint : ""
  risk_api_key      = local.effective_risk_api_key
  risk_udf_jar_path = "${path.module}/${var.risk_udf_jar_path}"

  # Self-service: ALTER + UDF plumbing only; attendees create MTs in labs
  enable_materialized_tables = var.enable_flink_mts

  # Wait until CDC + Avro lifecycle schemas exist, then brief catalog settle
  depends_on = [
    module.connectors,
    module.topics,
    null_resource.wait_for_schemas,
    time_sleep.wait_for_data,
    null_resource.risk_api_deploy,
  ]
}

# Poll Schema Registry until CDC profile + all lifecycle Avro subjects exist.
# Prevents Flink ALTER from racing empty/schemaless topics.
resource "null_resource" "wait_for_schemas" {
  count = (var.enable_shadowtraffic && !local.use_shared) ? 1 : 0

  triggers = {
    connections_hash = local_file.shadowtraffic_connections[0].content_md5
    config_hash      = filesha256("${path.module}/../../shadowtraffic/riverpay-generator.json")
    script_hash      = filesha256("${path.module}/scripts/wait_for_schemas.sh")
    wire_format      = "avro-v3-rowtime"
  }

  depends_on = [
    module.connectors,
    module.topics,
    null_resource.shadowtraffic_deploy,
  ]

  provisioner "local-exec" {
    environment = {
      SR_URL    = module.confluent_platform.schema_registry_endpoint
      SR_KEY    = module.confluent_platform.schema_registry_api_key
      SR_SECRET = module.confluent_platform.schema_registry_api_secret
    }
    command = "bash ${path.module}/scripts/wait_for_schemas.sh"
  }
}

resource "time_sleep" "wait_for_data" {
  create_duration = "30s"
  depends_on = [
    null_resource.wait_for_schemas,
  ]
}

module "tableflow_payments" {
  count  = var.enable_tableflow_topics ? 1 : 0
  source = "../modules/confluent-tableflow-payments"

  environment_id          = module.confluent_platform.environment_id
  kafka_cluster_id        = module.confluent_platform.kafka_cluster_id
  s3_bucket_name          = local.effective_s3_bucket_name
  provider_integration_id = module.tableflow.integration_id
  payments_topic          = local.payments_topic
  risk_score_topic        = local.risk_score_topic

  api_key    = confluent_api_key.tableflow.id
  api_secret = confluent_api_key.tableflow.secret

  # Explicit create/destroy edge: topics before provider integration on destroy.
  # (Also implied by provider_integration_id = module.tableflow.integration_id.)
  depends_on = [
    module.tableflow,
    module.flink_payments,
    module.catalog_integration,
    confluent_api_key.tableflow,
  ]
}

# Note: when enable_flink_mts=false, attendees create MTs in labs before Tableflow.

# Poll Tableflow until both topics are RUNNING and the Unity catalog integration
# is CONNECTED. A fixed sleep is not enough — cold starts often stay PENDING for
# 30–60+ minutes before the first S3/UC publish.
resource "null_resource" "wait_for_tableflow" {
  count = var.enable_tableflow_topics ? 1 : 0
  triggers = {
    payments_topic   = local.payments_topic
    risk_score_topic = local.risk_score_topic
    script_hash      = filesha256("${path.module}/scripts/wait_for_tableflow.sh")
  }

  provisioner "local-exec" {
    environment = {
      TABLEFLOW_API_KEY    = confluent_api_key.tableflow.id
      TABLEFLOW_API_SECRET = confluent_api_key.tableflow.secret
      ENVIRONMENT_ID       = module.confluent_platform.environment_id
      KAFKA_CLUSTER_ID     = module.confluent_platform.kafka_cluster_id
      PAYMENTS_TOPIC       = local.payments_topic
      RISK_SCORE_TOPIC     = local.risk_score_topic
    }
    command = "bash ${path.module}/scripts/wait_for_tableflow.sh"
  }

  depends_on = [
    module.tableflow_payments,
    module.catalog_integration,
    confluent_api_key.tableflow,
  ]
}

# RiverPulse ops views for Genie.
# Waits for Tableflow→UC base tables, then creates each view as its own SQL statement
# (Databricks Statement Execution API rejects multi-statement batches).
resource "null_resource" "riverpulse_views" {
  count = var.enable_tableflow_topics ? 1 : 0
  triggers = {
    catalog_name = databricks_catalog.main.name
    schema_name  = module.databricks.databricks_schema_name
    script_hash  = filesha256("${path.module}/scripts/create_riverpulse_views.sh")
    views_gen    = "v3-after-tableflow-poll"
  }

  provisioner "local-exec" {
    environment = {
      DB_HOST          = var.databricks_host
      DB_CLIENT_ID     = var.databricks_service_principal_client_id
      DB_CLIENT_SECRET = var.databricks_service_principal_client_secret
      DB_WAREHOUSE_ID  = module.databricks.sql_warehouse_id
      DB_CATALOG       = databricks_catalog.main.name
      DB_SCHEMA        = module.databricks.databricks_schema_name
    }
    command = "bash ${path.module}/scripts/create_riverpulse_views.sh"
  }

  depends_on = [null_resource.wait_for_tableflow]
}
