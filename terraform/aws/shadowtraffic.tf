# ===============================
# Per-attendee ShadowTraffic — lifecycle → this Kafka cluster
# ===============================
# Emergency/debug only: runs a kafka-only generator on the shared Postgres
# EC2 (Docker). Instructor-led defaults this off — use terraform/aws-lifecycle-st
# (scripts/wsa-deploy-lifecycle-st.sh) for the normal multi-cluster path.
# Profiles/FX stay on the shared ST instance from aws-shared.

locals {
  deploy_lifecycle_st = var.enable_lifecycle_shadowtraffic && local.use_shared && var.shared_postgres_public_ip != "" && var.shared_postgres_ssh_private_key_path != ""

  shadowtraffic_dir       = "${path.module}/../../shadowtraffic"
  lifecycle_st_generator  = "${local.shadowtraffic_dir}/riverpay-generator-kafka.json"
  lifecycle_st_name_raw   = "st-life-${local.prefix}-${local.resource_suffix}"
  lifecycle_st_container  = substr(lower(replace(local.lifecycle_st_name_raw, "/[^a-zA-Z0-9_.-]/", "-")), 0, 63)
  lifecycle_st_remote_dir = "/opt/shadowtraffic-lifecycle/${local.lifecycle_st_container}"
}

data "http" "lifecycle_shadowtraffic_license" {
  count = local.deploy_lifecycle_st ? 1 : 0
  url   = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

resource "local_file" "lifecycle_shadowtraffic_license" {
  count = local.deploy_lifecycle_st ? 1 : 0

  content         = data.http.lifecycle_shadowtraffic_license[0].response_body
  filename        = "${path.module}/generated/shadow-traffic-license.env"
  file_permission = "0600"
}

resource "local_file" "lifecycle_shadowtraffic_connections" {
  count = local.deploy_lifecycle_st ? 1 : 0

  content = jsonencode({
    kafka = {
      kind = "kafka"
      producerConfigs = {
        "bootstrap.servers"             = module.confluent_platform.bootstrap_endpoint_url
        "security.protocol"             = "SASL_SSL"
        "sasl.mechanism"                = "PLAIN"
        "sasl.jaas.config"              = "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.confluent_platform.kafka_api_key}' password='${module.confluent_platform.kafka_api_secret}';"
        "schema.registry.url"           = module.confluent_platform.schema_registry_endpoint
        "basic.auth.credentials.source" = "USER_INFO"
        "basic.auth.user.info"          = "${module.confluent_platform.schema_registry_api_key}:${module.confluent_platform.schema_registry_api_secret}"
        "key.serializer"                = "io.confluent.kafka.serializers.KafkaAvroSerializer"
        "value.serializer"              = "io.confluent.kafka.serializers.KafkaAvroSerializer"
        "auto.register.schemas"         = "true"
        "use.latest.version"            = "true"
      }
    }
  })

  filename        = "${path.module}/generated/connections/lifecycle-shadowtraffic-connections.json"
  file_permission = "0600"
}

resource "null_resource" "lifecycle_shadowtraffic_deploy" {
  count = local.deploy_lifecycle_st ? 1 : 0

  triggers = {
    host             = var.shared_postgres_public_ip
    ssh_user         = var.shared_postgres_ssh_username
    ssh_private_key  = file(var.shared_postgres_ssh_private_key_path)
    container        = local.lifecycle_st_container
    config_hash      = filesha256(local.lifecycle_st_generator)
    connections_hash = local_file.lifecycle_shadowtraffic_connections[0].content_md5
    license_hash     = md5(local_file.lifecycle_shadowtraffic_license[0].content)
    image            = var.shadowtraffic_image
    bootstrap        = module.confluent_platform.bootstrap_endpoint_url
    metrics_port     = "0" # recreate when lifecycle metrics port strategy changes
  }

  depends_on = [
    module.topics,
    module.confluent_platform,
    local_file.lifecycle_shadowtraffic_connections,
    local_file.lifecycle_shadowtraffic_license,
  ]

  # Use self.triggers so destroy-time connection is valid (no external var refs).
  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    private_key = self.triggers.ssh_private_key
    host        = self.triggers.host
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${local.lifecycle_st_remote_dir}",
      "sudo chown -R ${var.shared_postgres_ssh_username}:${var.shared_postgres_ssh_username} /opt/shadowtraffic-lifecycle",
    ]
  }

  provisioner "file" {
    source      = local.lifecycle_st_generator
    destination = "${local.lifecycle_st_remote_dir}/riverpay-generator.json"
  }

  provisioner "file" {
    source      = "${path.module}/generated/connections/lifecycle-shadowtraffic-connections.json"
    destination = "${local.lifecycle_st_remote_dir}/connections.json"
  }

  provisioner "file" {
    source      = local_file.lifecycle_shadowtraffic_license[0].filename
    destination = "${local.lifecycle_st_remote_dir}/shadow-traffic-license.env"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        set -eu
        REMOTE_DIR="${local.lifecycle_st_remote_dir}"
        CONTAINER="${local.lifecycle_st_container}"

        if ! command -v jq >/dev/null 2>&1; then
          sudo yum install -y jq || sudo dnf install -y jq
        fi

        jq -s '.[0] * {connections: .[1]}' \
          "$REMOTE_DIR/riverpay-generator.json" \
          "$REMOTE_DIR/connections.json" \
          > "$REMOTE_DIR/config.json"

        echo "Wrote $REMOTE_DIR/config.json (kafka lifecycle → this cluster)"
        sudo docker pull ${var.shadowtraffic_image}

        sudo docker rm -f "$CONTAINER" 2>/dev/null || true
        # --metrics-port 0: avoid BindException vs shared ST (and other lifecycle
        # containers) on host network — default Prometheus port 9400 is taken.
        sudo docker run -d --name "$CONTAINER" \
          --network host \
          --restart unless-stopped \
          --env-file "$REMOTE_DIR/shadow-traffic-license.env" \
          -v "$REMOTE_DIR/config.json:/home/config.json:ro" \
          ${var.shadowtraffic_image} \
          --config /home/config.json \
          --metrics-port 0

        echo "Lifecycle ShadowTraffic started as $CONTAINER"
        sleep 20
        status=$(sudo docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
        if [ "$status" != "running" ]; then
          echo "ERROR: container status=$status"
          sudo docker logs "$CONTAINER" 2>&1 || true
          exit 1
        fi
        if sudo docker logs "$CONTAINER" 2>&1 | grep -q 'configuration errors'; then
          echo "ERROR: ShadowTraffic configuration errors"
          sudo docker logs --tail 80 "$CONTAINER" 2>&1 || true
          exit 1
        fi
        echo "Lifecycle generators OK for $CONTAINER"
      EOT
    ]
  }

  # Best-effort cleanup when this attendee stack is destroyed
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "sudo docker rm -f ${self.triggers.container} 2>/dev/null || true",
    ]

    connection {
      type        = "ssh"
      user        = self.triggers.ssh_user
      private_key = self.triggers.ssh_private_key
      host        = self.triggers.host
      timeout     = "5m"
    }
  }
}

# ===============================
# ShadowTraffic Data Generator
# ===============================
# Deploys ShadowTraffic on the PostgreSQL EC2 instance.
# Seeds riverpay.customer_profiles + fx_rates and emits RiverFlow lifecycle events to Kafka.
# License: free-trial env file fetched via HTTP (same pattern as early
# workshop-tableflow-databricks ShadowTraffic Terraform).

locals {
  deploy_shadowtraffic = var.enable_shadowtraffic && !local.use_shared
}

# ===============================
# ShadowTraffic License (HTTP free trial)
# ===============================

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
    kafka = {
      kind = "kafka"
      producerConfigs = {
        "bootstrap.servers"             = module.confluent_platform.bootstrap_endpoint_url
        "security.protocol"             = "SASL_SSL"
        "sasl.mechanism"                = "PLAIN"
        "sasl.jaas.config"              = "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.confluent_platform.kafka_api_key}' password='${module.confluent_platform.kafka_api_secret}';"
        "schema.registry.url"           = module.confluent_platform.schema_registry_endpoint
        "basic.auth.credentials.source" = "USER_INFO"
        "basic.auth.user.info"          = "${module.confluent_platform.schema_registry_api_key}:${module.confluent_platform.schema_registry_api_secret}"
        "key.serializer"                = "io.confluent.kafka.serializers.KafkaAvroSerializer"
        "value.serializer"              = "io.confluent.kafka.serializers.KafkaAvroSerializer"
        "auto.register.schemas"         = "true"
        "use.latest.version"            = "true"
      }
    }
  })

  filename        = "${path.module}/generated/connections/shadowtraffic-connections.json"
  file_permission = "0600"
}

resource "null_resource" "shadowtraffic_deploy" {
  count = local.deploy_shadowtraffic ? 1 : 0

  triggers = {
    instance_id      = module.postgres[0].instance_id
    config_hash      = filesha256("${local.shadowtraffic_dir}/riverpay-generator.json")
    connections_hash = local_file.shadowtraffic_connections[0].content_md5
    license_hash     = md5(local_file.shadowtraffic_license[0].content)
  }

  depends_on = [
    module.postgres,
    module.keypair,
    module.confluent_platform,
    module.topics,
    module.connectors,
    local_file.shadowtraffic_connections,
    local_file.shadowtraffic_license,
  ]

  connection {
    type        = "ssh"
    host        = module.postgres[0].public_dns
    user        = var.shadowtraffic_ssh_username
    private_key = file(module.keypair[0].private_key_path)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/shadowtraffic",
      "sudo chmod 777 /opt/shadowtraffic",
    ]
  }

  provisioner "file" {
    source      = "${local.shadowtraffic_dir}/riverpay-generator.json"
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
        set -e
        # Ensure jq exists for config merge
        if ! command -v jq >/dev/null 2>&1; then
          sudo dnf install -y jq || sudo yum install -y jq
        fi

        jq -s '.[0] * {connections: .[1]}' \
          /opt/shadowtraffic/riverpay-generator.json \
          /opt/shadowtraffic/connections.json \
          > /opt/shadowtraffic/config.json

        echo "Wrote /opt/shadowtraffic/config.json"
        sudo docker rm -f shadowtraffic-riverpay 2>/dev/null || true

        # Ensure FX rates table exists (fresh hosts get it from cloud-init; this covers already-provisioned hosts).
        echo "Ensuring riverpay.fx_rates exists and is seeded..."
        sudo docker exec -i postgres-workshop psql -U postgres -d workshop -v ON_ERROR_STOP=1 <<'SQL'
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
        sudo docker exec -i postgres-workshop psql -U postgres -d workshop -v ON_ERROR_STOP=1 <<'SQL'
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

        echo "Pulling ShadowTraffic image..."
        sudo docker pull ${var.shadowtraffic_image}

        sudo docker run -d --name shadowtraffic-riverpay \
          --network host \
          --restart unless-stopped \
          --env-file /opt/shadowtraffic/shadow-traffic-license.env \
          -v /opt/shadowtraffic/config.json:/home/config.json:ro \
          ${var.shadowtraffic_image} \
          --config /home/config.json

        echo "ShadowTraffic started"
        sleep 20
        sudo docker ps -a --filter name=shadowtraffic-riverpay
        status=$(sudo docker inspect -f '{{.State.Status}}' shadowtraffic-riverpay 2>/dev/null || echo missing)
        if [ "$status" != "running" ]; then
          echo "ERROR: ShadowTraffic container status=$status (expected running)"
          sudo docker logs shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        # Fail fast on config validation errors (crash-loop with restart policy can still show Up briefly)
        if sudo docker logs shadowtraffic-riverpay 2>&1 | grep -q 'configuration errors'; then
          echo "ERROR: ShadowTraffic reported configuration errors"
          sudo docker logs --tail 80 shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        echo "ShadowTraffic is running without configuration errors"
      EOT
    ]
  }
}
