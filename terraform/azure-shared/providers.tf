provider "azurerm" {
  features {}
  # Avoid "all" — registering every RP (e.g. Microsoft.DataMigration) often
  # times out on workshop subscriptions. Core + explicit RPs for this stack.
  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.App",                 # Container Apps (Risk API)
    "Microsoft.ContainerRegistry",   # ACR for Risk API image
    "Microsoft.OperationalInsights", # Log Analytics for Container Apps env
    "Microsoft.Insights",            # Monitor alerts / metrics
    "Microsoft.Databricks",          # Access Connector
  ]
}

provider "databricks" {
  alias     = "workspace"
  host      = var.databricks_host
  auth_type = "azure-client-secret"
}
