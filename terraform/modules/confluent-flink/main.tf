# ===============================
# Confluent Flink Module
# ===============================
# Creates Flink Compute Pool and API Keys

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

data "confluent_flink_region" "main" {
  cloud  = upper(var.cloud)
  region = var.cloud_region
}

# ===============================
# Flink Compute Pool
# ===============================

resource "confluent_flink_compute_pool" "main" {
  display_name = "${var.prefix}_flink_compute_pool_${var.resource_suffix}"
  cloud        = upper(var.cloud)
  region       = var.cloud_region
  max_cfu      = var.max_cfu

  environment {
    id = var.environment_id
  }

  timeouts {
    # eastus2 CFU allocation has been observed taking >10m under load; a tight
    # timeout marks the pool tainted, so each WSA retry destroys and recreates
    # it — restarting the clock and never getting past the timeout. Give the
    # backend room to finish provisioning within a single apply.
    create = "30m"
  }
}

# ===============================
# Flink API Key
# ===============================

resource "confluent_api_key" "flink" {
  display_name = "app-manager-flink-api-key"
  description  = "Flink API Key for app-manager service account"

  owner {
    id          = var.service_account_id
    api_version = var.service_account_api_version
    kind        = var.service_account_kind
  }

  managed_resource {
    id          = data.confluent_flink_region.main.id
    api_version = data.confluent_flink_region.main.api_version
    kind        = data.confluent_flink_region.main.kind

    environment {
      id = var.environment_id
    }
  }
}
