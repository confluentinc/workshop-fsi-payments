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
  default = "riverpay.customer_profiles"
}

variable "enable_shadowtraffic" {
  type    = bool
  default = true
}

variable "shadowtraffic_image" {
  type    = string
  default = "shadowtraffic/shadowtraffic:latest"
}

variable "shadowtraffic_ssh_username" {
  type    = string
  default = "ec2-user"
}
