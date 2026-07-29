# ===============================
# Provider Configuration
# ===============================

provider "aws" {
  region = var.cloud_region

  default_tags {
    tags = {
      Created_by  = "terraform"
      Project     = "RiverPay FSI Payments Workshop"
      owner_email = var.confluent_cloud_email
      Environment = var.environment
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "databricks" {
  alias         = "workspace"
  host          = var.databricks_host
  client_id     = var.databricks_service_principal_client_id
  client_secret = var.databricks_service_principal_client_secret
  auth_type     = "oauth-m2m"
}
