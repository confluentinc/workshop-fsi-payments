variable "confluent_cloud_email" {
  description = "Your Confluent Cloud account email — used for EnvironmentAdmin RBAC and AWS resource tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.confluent_cloud_email))
    error_message = "Must be a valid email address (e.g., user@example.com)."
  }
}

variable "prefix" {
  description = "Call sign to use in prefix for resource names"
  type        = string
  default     = "neo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.prefix))
    error_message = "Call sign must be 2-11 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "project_name" {
  description = "Name of this project to use in prefix for resource names"
  type        = string
  default     = "riverpay"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "test", "workshop"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test, workshop."
  }
}

variable "cloud_region" {
  description = "AWS Cloud Region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.cloud_region))
    error_message = "Must be a valid AWS region (e.g., us-east-1)."
  }
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "cc_environment_id" {
  description = "Pre-created Confluent Cloud environment ID (skip creation when set)"
  type        = string
  default     = ""
}

variable "postgres_instance_type" {
  type    = string
  default = "m7i-flex.large"
}

variable "postgres_db_name" {
  type    = string
  default = "workshop"
}

variable "postgres_db_username" {
  type    = string
  default = "postgres"
}

variable "postgres_db_password" {
  type      = string
  default   = "Welcome1"
  sensitive = true
}

variable "postgres_db_port" {
  type    = number
  default = 5432
}

variable "postgres_debezium_username" {
  type    = string
  default = "debezium"
}

variable "postgres_debezium_password" {
  type      = string
  default   = "password"
  sensitive = true
}

variable "databricks_host" {
  description = "Databricks workspace URL"
  type        = string

  validation {
    condition     = can(regex("^https://[a-zA-Z0-9-]+\\.cloud\\.databricks\\.com/?$", var.databricks_host))
    error_message = "Must be a valid Databricks workspace URL."
  }
}

variable "databricks_account_id" {
  description = "Databricks account ID for IAM trust policy"
  type        = string
  sensitive   = true
  default     = ""
}

variable "databricks_user_email" {
  type = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.databricks_user_email))
    error_message = "Must be a valid email address."
  }
}

variable "databricks_service_principal_client_id" {
  type = string
}

variable "databricks_service_principal_client_secret" {
  type      = string
  sensitive = true
}

variable "databricks_sql_warehouse_name" {
  type    = string
  default = "Serverless Starter Warehouse"
}

variable "databricks_sso_email" {
  type    = string
  default = ""
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "table_include_list" {
  type    = string
  default = "riverpay.customer_profiles,riverpay.fx_rates"
}

variable "enable_shadowtraffic" {
  description = "Self-service (!use_shared): deploy full ShadowTraffic on the Postgres EC2"
  type        = bool
  default     = true
}

variable "shadowtraffic_image" {
  type        = string
  description = "ShadowTraffic Docker image (pin 2.x for workshop reproducibility)"
  default     = "shadowtraffic/shadowtraffic:2.0.3"
}

variable "shadowtraffic_ssh_username" {
  type    = string
  default = "ec2-user"
}

variable "enable_risk_api" {
  description = "Deploy shared Risk Scoring API on the Postgres EC2 host (port 8089)"
  type        = bool
  default     = true
}

variable "risk_api_key" {
  description = "Bearer API key for the Risk Scoring API / Flink REST CONNECTION"
  type        = string
  sensitive   = true
  default     = "riverpay-workshop-risk"
}

variable "enable_risk_udf" {
  description = "Upload Flink UDF artifact and score risk via external API (requires built JAR in dist/)"
  type        = bool
  default     = true
}

variable "risk_udf_jar_path" {
  description = "Path to riverpay-risk-udf JAR (build via udf/riverpay-risk/README.md)"
  type        = string
  default     = "../../udf/riverpay-risk/dist/riverpay-risk-udf-1.0.0.jar"
}


variable "enable_flink_mts" {
  description = "Create Flink materialized tables (false for self-service labs — attendees write MTs)"
  type        = bool
  default     = false
}

variable "enable_tableflow_topics" {
  description = "Enable Tableflow on Flink data products (false for self-service — attendees enable in labs)"
  type        = bool
  default     = false
}


# ---------------------
# Instructor-led shared infra (from aws-shared via WSA TF_VAR_shared_*)
# ---------------------

variable "shared_vpc_id" {
  description = "Shared VPC ID from aws-shared (non-empty enables use_shared)"
  type        = string
  default     = ""
}

variable "shared_subnet_id" {
  description = "Shared public subnet ID"
  type        = string
  default     = ""
}

variable "shared_aws_account_id" {
  description = "AWS account ID from aws-shared"
  type        = string
  default     = ""
}

variable "shared_s3_bucket_name" {
  description = "Shared S3 bucket name"
  type        = string
  default     = ""
}

variable "shared_s3_bucket_arn" {
  description = "Shared S3 bucket ARN"
  type        = string
  default     = ""
}

variable "shared_s3_bucket_url" {
  description = "Shared S3 bucket URL (s3://...)"
  type        = string
  default     = ""
}

variable "shared_key_name" {
  description = "Shared EC2 key pair name (optional)"
  type        = string
  default     = ""
}

variable "shared_postgres_hostname" {
  description = "Shared Postgres public DNS"
  type        = string
  default     = ""
}

variable "shared_postgres_public_ip" {
  description = "Shared Postgres public IP"
  type        = string
  default     = ""
}

variable "shared_postgres_db_password" {
  description = "Shared Postgres admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "shared_postgres_debezium_password" {
  description = "Shared Postgres Debezium password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "shared_postgres_ssh_private_key_path" {
  description = "Absolute path to shared Postgres SSH private key"
  type        = string
  default     = ""
}

variable "shared_postgres_ssh_username" {
  description = "SSH username on shared Postgres EC2"
  type        = string
  default     = "ec2-user"
}

variable "shared_risk_api_endpoint" {
  description = "Shared Risk Scoring API base URL"
  type        = string
  default     = ""
}

variable "shared_risk_api_key" {
  description = "Shared Risk Scoring API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "shared_dbx_sp_client_id" {
  description = "Databricks SP client ID from aws-shared"
  type        = string
  default     = ""
}

variable "shared_dbx_sp_client_secret" {
  description = "Ephemeral Databricks SP secret from aws-shared"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_lifecycle_shadowtraffic" {
  description = "Instructor-led emergency/debug: per-account kafka-only ST on shared host. Prefer aggregator terraform/*-lifecycle-st (default false in wsa-spec-aws)."
  type        = bool
  default     = false
}
