# ===============================
# Per-attendee ShadowTraffic — lifecycle → this Kafka cluster
# ===============================
# Runs a kafka-only generator on the shared Postgres VM (Docker).
# Profiles/FX stay on the shared ST instance from azure-shared.

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
          sudo apt-get update -y && sudo apt-get install -y jq
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
# Self-service ShadowTraffic — full generator on datagen VM
# ===============================
# Profiles+FX → Flexible Server; lifecycle → this Kafka cluster.

locals {
  deploy_byo_shadowtraffic = var.enable_shadowtraffic && !local.use_shared && local.deploy_datagen_vm
  byo_st_generator         = "${local.shadowtraffic_dir}/riverpay-generator.json"
}

data "http" "byo_shadowtraffic_license" {
  count = local.deploy_byo_shadowtraffic ? 1 : 0
  url   = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

resource "local_file" "byo_shadowtraffic_license" {
  count = local.deploy_byo_shadowtraffic ? 1 : 0

  content         = data.http.byo_shadowtraffic_license[0].response_body
  filename        = "${path.module}/generated/byo-shadow-traffic-license.env"
  file_permission = "0600"
}

resource "local_file" "byo_shadowtraffic_connections" {
  count = local.deploy_byo_shadowtraffic ? 1 : 0

  content = jsonencode({
    postgres = {
      kind        = "postgres"
      tablePolicy = "create"
      connectionConfigs = {
        host     = module.postgres[0].fqdn
        port     = var.postgres_db_port
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

  filename        = "${path.module}/generated/connections/byo-shadowtraffic-connections.json"
  file_permission = "0600"
}

resource "null_resource" "byo_shadowtraffic_deploy" {
  count = local.deploy_byo_shadowtraffic ? 1 : 0

  triggers = {
    vm_id            = azurerm_linux_virtual_machine.datagen[0].id
    host             = azurerm_public_ip.datagen[0].ip_address
    ssh_user         = local.datagen_ssh_user
    ssh_private_key  = tls_private_key.datagen[0].private_key_pem
    config_hash      = filesha256(local.byo_st_generator)
    connections_hash = local_file.byo_shadowtraffic_connections[0].content_md5
    license_hash     = md5(local_file.byo_shadowtraffic_license[0].content)
    image            = var.shadowtraffic_image
    bootstrap        = module.confluent_platform.bootstrap_endpoint_url
  }

  depends_on = [
    module.postgres,
    module.topics,
    module.connectors,
    module.confluent_platform,
    azurerm_linux_virtual_machine.datagen,
    local_file.byo_shadowtraffic_connections,
    local_file.byo_shadowtraffic_license,
    null_resource.byo_risk_api_deploy,
  ]

  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    private_key = self.triggers.ssh_private_key
    host        = self.triggers.host
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/shadowtraffic",
      "sudo chown -R ${local.datagen_ssh_user}:${local.datagen_ssh_user} /opt/shadowtraffic",
      "for i in $(seq 1 60); do command -v docker >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1 && break; sleep 5; done",
    ]
  }

  provisioner "file" {
    source      = local.byo_st_generator
    destination = "/opt/shadowtraffic/riverpay-generator.json"
  }

  provisioner "file" {
    source      = "${path.module}/generated/connections/byo-shadowtraffic-connections.json"
    destination = "/opt/shadowtraffic/connections.json"
  }

  provisioner "file" {
    source      = local_file.byo_shadowtraffic_license[0].filename
    destination = "/opt/shadowtraffic/shadow-traffic-license.env"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        set -eu
        if ! command -v jq >/dev/null 2>&1; then
          sudo apt-get update -y && sudo apt-get install -y jq
        fi

        jq -s '.[0] * {connections: .[1]}' \
          /opt/shadowtraffic/riverpay-generator.json \
          /opt/shadowtraffic/connections.json \
          > /opt/shadowtraffic/config.json

        echo "Wrote BYO ShadowTraffic config (postgres=Flexible Server, kafka=this cluster)"
        sudo docker pull ${var.shadowtraffic_image}
        sudo docker rm -f shadowtraffic-riverpay 2>/dev/null || true
        sudo docker run -d --name shadowtraffic-riverpay \
          --network host \
          --restart unless-stopped \
          --env-file /opt/shadowtraffic/shadow-traffic-license.env \
          -v /opt/shadowtraffic/config.json:/home/config.json:ro \
          ${var.shadowtraffic_image} \
          --config /home/config.json

        sleep 20
        status=$(sudo docker inspect -f '{{.State.Status}}' shadowtraffic-riverpay 2>/dev/null || echo missing)
        if [ "$status" != "running" ]; then
          sudo docker logs shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        if sudo docker logs shadowtraffic-riverpay 2>&1 | grep -q 'configuration errors'; then
          sudo docker logs --tail 80 shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        echo "BYO ShadowTraffic running"
      EOT
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "sudo docker rm -f shadowtraffic-riverpay 2>/dev/null || true",
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

