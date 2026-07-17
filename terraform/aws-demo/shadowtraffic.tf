# ===============================
# ShadowTraffic Data Generator
# ===============================
# Deploys ShadowTraffic on the PostgreSQL EC2 instance.
# Seeds riverpay.customer_profiles and emits RiverFlow lifecycle events to Kafka.
# License: free-trial env file fetched via HTTP (same pattern as early
# workshop-tableflow-databricks ShadowTraffic Terraform).

locals {
  deploy_shadowtraffic = var.enable_shadowtraffic
  shadowtraffic_dir    = "${path.module}/../../shadowtraffic"
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
        password = var.postgres_db_password
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
    instance_id      = module.postgres.instance_id
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
    host        = module.postgres.public_dns
    user        = var.shadowtraffic_ssh_username
    private_key = file(module.keypair.private_key_path)
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

        # Align existing DB columns with ShadowTraffic `_gen: now` (epoch millis BIGINT).
        # Fresh instances get BIGINT from cloud-init; this covers already-provisioned hosts.
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
