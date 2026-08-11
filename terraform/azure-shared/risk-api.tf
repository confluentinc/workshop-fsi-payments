# ===============================
# Shared Risk Scoring API — Azure Container Apps (HTTPS)
# ===============================
# One public HTTPS URL for all Elevate attendees. Flink UDFs on Azure can only
# reach public endpoints (private UDF endpoints are AWS-only).
#
# Requires: az CLI authenticated for `az acr build` during apply.

locals {
  deploy_risk_api = var.enable_risk_api
  risk_api_dir    = "${path.module}/../../services/risk-api"
  risk_api_image  = "riverpay-risk-api"
  risk_api_tag    = substr(filesha256("${local.risk_api_dir}/app.py"), 0, 12)
  # ACR names: 5–50 alphanumeric, globally unique
  acr_name = substr(lower(replace(replace("${var.prefix}risk${local.resource_suffix}", "-", ""), "_", "")), 0, 50)
}

resource "azurerm_log_analytics_workspace" "risk_api" {
  count = local.deploy_risk_api ? 1 : 0

  name                = "${var.prefix}-risk-law-${local.resource_suffix}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_container_registry" "workshop" {
  count = local.deploy_risk_api ? 1 : 0

  name                = local.acr_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.common_tags
}

resource "azurerm_container_app_environment" "risk_api" {
  count = local.deploy_risk_api ? 1 : 0

  name                       = "${var.prefix}-risk-cae-${local.resource_suffix}"
  location                   = azurerm_resource_group.shared.location
  resource_group_name        = azurerm_resource_group.shared.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.risk_api[0].id
  tags                       = local.common_tags
}

resource "azurerm_user_assigned_identity" "risk_api" {
  count = local.deploy_risk_api ? 1 : 0

  name                = "${var.prefix}-risk-mi-${local.resource_suffix}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "risk_api_acr_pull" {
  count = local.deploy_risk_api ? 1 : 0

  scope                = azurerm_container_registry.workshop[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.risk_api[0].principal_id
}

resource "time_sleep" "risk_api_acr_rbac" {
  count = local.deploy_risk_api ? 1 : 0

  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.risk_api_acr_pull]
}

# Build & push image into ACR (cloud build — no local Docker daemon required)
resource "null_resource" "risk_api_acr_build" {
  count = local.deploy_risk_api ? 1 : 0

  triggers = {
    app_hash    = filesha256("${local.risk_api_dir}/app.py")
    docker_hash = filesha256("${local.risk_api_dir}/Dockerfile")
    req_hash    = filesha256("${local.risk_api_dir}/requirements.txt")
    acr_id      = azurerm_container_registry.workshop[0].id
    tag         = local.risk_api_tag
  }

  depends_on = [azurerm_container_registry.workshop]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      if ! command -v az >/dev/null 2>&1; then
        echo "ERROR: Azure CLI (az) is required to build the Risk API image into ACR."
        exit 1
      fi
      echo "Building ${local.risk_api_image}:${local.risk_api_tag} in ACR ${azurerm_container_registry.workshop[0].name}..."
      az acr build \
        --registry "${azurerm_container_registry.workshop[0].name}" \
        --image "${local.risk_api_image}:${local.risk_api_tag}" \
        --image "${local.risk_api_image}:latest" \
        --file "${local.risk_api_dir}/Dockerfile" \
        "${local.risk_api_dir}"
    EOT
  }
}

resource "azurerm_container_app" "risk_api" {
  count = local.deploy_risk_api ? 1 : 0

  name                         = "riverpay-risk-api"
  container_app_environment_id = azurerm_container_app_environment.risk_api[0].id
  resource_group_name          = azurerm_resource_group.shared.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.risk_api[0].id]
  }

  registry {
    server   = azurerm_container_registry.workshop[0].login_server
    identity = azurerm_user_assigned_identity.risk_api[0].id
  }

  secret {
    name  = "risk-api-key"
    value = var.risk_api_key
  }

  ingress {
    external_enabled           = true
    target_port                = 8089
    transport                  = "http"
    allow_insecure_connections = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "risk-api"
      image  = "${azurerm_container_registry.workshop[0].login_server}/${local.risk_api_image}:${local.risk_api_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PORT"
        value = "8089"
      }

      env {
        name        = "RISK_API_KEY"
        secret_name = "risk-api-key"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8089
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8089
      }
    }
  }

  depends_on = [
    time_sleep.risk_api_acr_rbac,
    null_resource.risk_api_acr_build,
  ]
}
