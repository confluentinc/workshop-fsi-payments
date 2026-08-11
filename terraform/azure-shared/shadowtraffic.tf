# ===============================
# ShadowTraffic — shared Postgres (profiles + FX)
# ===============================
# Elevate fan-out model:
#   shared ST writes Postgres → per-attendee CDC → each Kafka cluster
# Lifecycle Kafka traffic: one multi-connection ST via terraform/azure-lifecycle-st
# (scripts/wsa-deploy-lifecycle-st.sh). Per-attendee st-life-* is emergency/debug only.

locals {
  deploy_shadowtraffic    = var.enable_shadowtraffic
  shadowtraffic_dir       = "${path.module}/../../shadowtraffic"
  shadowtraffic_generator = "${local.shadowtraffic_dir}/riverpay-generator-postgres.json"
}

data "http" "shadowtraffic_license" {
  count = local.deploy_shadowtraffic ? 1 : 0
  url   = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

resource "local_file" "shadowtraffic_license" {
  count = local.deploy_shadowtraffic ? 1 : 0

  content         = data.http.shadowtraffic_license[0].response_body
  filename        = "${path.module}/generated/shadow-traffic-license.env"
  file_permission = "0600"
}

resource "local_file" "shadowtraffic_connections" {
  count = local.deploy_shadowtraffic ? 1 : 0

  content = jsonencode({
    postgres = {
      kind        = "postgres"
      tablePolicy = "create"
      connectionConfigs = {
        host     = "localhost"
        port     = 5432
        username = var.postgres_db_username
        password = local.effective_postgres_db_password
        db       = var.postgres_db_name
      }
    }
  })

  filename        = "${path.module}/generated/connections/shadowtraffic-connections.json"
  file_permission = "0600"
}

resource "null_resource" "shadowtraffic_deploy" {
  count = local.deploy_shadowtraffic ? 1 : 0

  triggers = {
    vm_id            = azurerm_linux_virtual_machine.postgres.id
    config_hash      = filesha256(local.shadowtraffic_generator)
    connections_hash = local_file.shadowtraffic_connections[0].content_md5
    license_hash     = md5(local_file.shadowtraffic_license[0].content)
    image            = var.shadowtraffic_image
  }

  depends_on = [
    azurerm_linux_virtual_machine.postgres,
    local_file.ssh_private_key,
    local_file.shadowtraffic_connections,
    local_file.shadowtraffic_license,
  ]

  connection {
    type        = "ssh"
    user        = var.vm_admin_username
    private_key = tls_private_key.shared.private_key_pem
    host        = azurerm_public_ip.postgres.ip_address
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/shadowtraffic",
      "sudo chown -R ${var.vm_admin_username}:${var.vm_admin_username} /opt/shadowtraffic",
      "for i in $(seq 1 60); do sudo docker ps --format '{{.Names}}' | grep -q postgres-workshop && break; sleep 5; done",
      "for i in $(seq 1 60); do sudo docker exec postgres-workshop pg_isready -U postgres >/dev/null 2>&1 && break; sleep 5; done",
    ]
  }

  provisioner "file" {
    source      = local.shadowtraffic_generator
    destination = "/opt/shadowtraffic/riverpay-generator.json"
  }

  provisioner "file" {
    source      = "${path.module}/generated/connections/shadowtraffic-connections.json"
    destination = "/opt/shadowtraffic/connections.json"
  }

  provisioner "file" {
    source      = local_file.shadowtraffic_license[0].filename
    destination = "/opt/shadowtraffic/shadow-traffic-license.env"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        # remote-exec uses /bin/sh (dash on Ubuntu) — no pipefail
        set -eu
        if ! command -v jq >/dev/null 2>&1; then
          sudo apt-get update -y && sudo apt-get install -y jq
        fi

        jq -s '.[0] * {connections: .[1]}' \
          /opt/shadowtraffic/riverpay-generator.json \
          /opt/shadowtraffic/connections.json \
          > /opt/shadowtraffic/config.json

        echo "Wrote /opt/shadowtraffic/config.json (postgres-only profiles + FX)"

        echo "Ensuring riverpay.fx_rates exists and is seeded..."
        sudo docker exec -i postgres-workshop psql -U ${var.postgres_db_username} -d ${var.postgres_db_name} -v ON_ERROR_STOP=1 <<'SQL'
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
ALTER TABLE riverpay.fx_rates OWNER TO debezium;
GRANT ALL PRIVILEGES ON TABLE riverpay.fx_rates TO debezium;
SQL

        echo "Ensuring riverpay.customer_profiles timestamp columns are BIGINT..."
        sudo docker exec -i postgres-workshop psql -U ${var.postgres_db_username} -d ${var.postgres_db_name} -v ON_ERROR_STOP=1 <<'SQL'
DO $align$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'riverpay'
      AND table_name = 'customer_profiles'
      AND column_name = 'created_at'
      AND data_type LIKE 'timestamp%'
  ) THEN
    ALTER TABLE riverpay.customer_profiles
      ALTER COLUMN created_at TYPE BIGINT USING NULL,
      ALTER COLUMN updated_at TYPE BIGINT USING NULL;
    RAISE NOTICE 'Converted created_at/updated_at to BIGINT';
  ELSE
    RAISE NOTICE 'created_at/updated_at already non-timestamp; leaving as-is';
  END IF;
END
$align$;
SQL

        echo "Pulling ShadowTraffic image ${var.shadowtraffic_image}..."
        sudo docker pull ${var.shadowtraffic_image}

        sudo docker rm -f shadowtraffic-riverpay 2>/dev/null || true
        sudo docker run -d --name shadowtraffic-riverpay \
          --network host \
          --restart unless-stopped \
          --env-file /opt/shadowtraffic/shadow-traffic-license.env \
          -v /opt/shadowtraffic/config.json:/home/config.json:ro \
          ${var.shadowtraffic_image} \
          --config /home/config.json

        echo "ShadowTraffic (postgres) started"
        sleep 20
        sudo docker ps -a --filter name=shadowtraffic-riverpay
        status=$(sudo docker inspect -f '{{.State.Status}}' shadowtraffic-riverpay 2>/dev/null || echo missing)
        if [ "$status" != "running" ]; then
          echo "ERROR: ShadowTraffic container status=$status (expected running)"
          sudo docker logs shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        if sudo docker logs shadowtraffic-riverpay 2>&1 | grep -q 'configuration errors'; then
          echo "ERROR: ShadowTraffic reported configuration errors"
          sudo docker logs --tail 80 shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        echo "ShadowTraffic postgres generators running (profiles + FX → CDC fan-out)"
      EOT
    ]
  }
}
