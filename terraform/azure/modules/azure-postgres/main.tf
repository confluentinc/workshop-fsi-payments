# Azure Database for PostgreSQL Flexible Server
# Managed PostgreSQL with logical replication for Debezium CDC

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "${var.prefix}-postgres-${var.resource_suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.region
  version                       = "16"
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  administrator_login           = var.admin_username
  administrator_password        = var.admin_password
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true
  zone                          = "1"

  tags = var.common_tags

  lifecycle {
    ignore_changes = [zone]
  }
}

# Enable logical replication (required for Debezium CDC)
resource "azurerm_postgresql_flexible_server_configuration" "wal_level" {
  name      = "wal_level"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "logical"
}

resource "azurerm_postgresql_flexible_server_configuration" "max_worker_processes" {
  name      = "max_worker_processes"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "16"
}

resource "azurerm_postgresql_flexible_server_configuration" "max_replication_slots" {
  name      = "max_replication_slots"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "10"
}

resource "azurerm_postgresql_flexible_server_configuration" "max_wal_senders" {
  name      = "max_wal_senders"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "10"
}

# Allow Azure services to access the server
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Allow all IPs for workshop access (data generator, participant debugging)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "AllowAll"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Create workshop database and Debezium replication user
resource "null_resource" "setup_database" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "⏳ Waiting 30 seconds for Flexible Server to be fully ready..."
      sleep 30

      export PGPASSWORD='${var.admin_password}'
      PGHOST='${azurerm_postgresql_flexible_server.main.fqdn}'

      echo "📦 Creating workshop database..."
      psql -h "$PGHOST" -U ${var.admin_username} -d postgres -p 5432 -c "SELECT 1 FROM pg_database WHERE datname='${var.db_name}'" | grep -q 1 || \
        psql -h "$PGHOST" -U ${var.admin_username} -d postgres -p 5432 -c "CREATE DATABASE ${var.db_name};"

      echo "👤 Creating Debezium replication user..."
      psql -h "$PGHOST" -U ${var.admin_username} -d ${var.db_name} -p 5432 <<SQL
        DO \$\$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${var.debezium_username}') THEN
            CREATE ROLE ${var.debezium_username} WITH LOGIN PASSWORD '${var.debezium_password}' REPLICATION;
          END IF;
        END \$\$;
        GRANT ALL PRIVILEGES ON DATABASE ${var.db_name} TO ${var.debezium_username};
        GRANT ALL ON SCHEMA public TO ${var.debezium_username};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${var.debezium_username};
SQL

      echo "📦 Creating riverpay schema (profiles + FX) for self-service..."
      psql -h "$PGHOST" -U ${var.admin_username} -d ${var.db_name} -p 5432 <<'SQL'
CREATE SCHEMA IF NOT EXISTS riverpay;
CREATE TABLE IF NOT EXISTS riverpay.customer_profiles (
    customer_id VARCHAR(64) PRIMARY KEY,
    partner_bank_id VARCHAR(64) NOT NULL,
    segment VARCHAR(64) NOT NULL,
    account_tier VARCHAR(64) NOT NULL,
    home_currency VARCHAR(3) NOT NULL,
    country VARCHAR(2) NOT NULL,
    full_name VARCHAR(256),
    tax_id VARCHAR(64),
    date_of_birth VARCHAR(32),
    created_at BIGINT,
    updated_at BIGINT
);
CREATE TABLE IF NOT EXISTS riverpay.fx_rates (
    currency_code VARCHAR(3) PRIMARY KEY,
    rate_to_usd DOUBLE PRECISION NOT NULL,
    updated_at BIGINT NOT NULL
);
INSERT INTO riverpay.fx_rates (currency_code, rate_to_usd, updated_at) VALUES
    ('USD', 1.0000, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('GBP', 1.2700, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('AUD', 0.6550, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('CAD', 0.7350, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('JPY', 0.00670, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT),
    ('EUR', 1.0850, (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT)
ON CONFLICT (currency_code) DO NOTHING;
GRANT ALL ON SCHEMA riverpay TO ${var.debezium_username};
GRANT ALL ON ALL TABLES IN SCHEMA riverpay TO ${var.debezium_username};
ALTER DEFAULT PRIVILEGES IN SCHEMA riverpay GRANT ALL ON TABLES TO ${var.debezium_username};
SQL

      echo "✅ Database setup complete!"
    EOT
  }

  triggers = {
    server_id = azurerm_postgresql_flexible_server.main.id
  }

  depends_on = [
    azurerm_postgresql_flexible_server.main,
    azurerm_postgresql_flexible_server_configuration.wal_level,
    azurerm_postgresql_flexible_server_firewall_rule.allow_all
  ]
}
