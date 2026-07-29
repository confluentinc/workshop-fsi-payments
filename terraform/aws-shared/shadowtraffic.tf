# ===============================
# ShadowTraffic — shared Postgres (profiles + FX)
# ===============================
# Instructor-led fan-out: shared ST → Postgres → per-attendee CDC → each Kafka.
# Lifecycle Kafka traffic: terraform/*-lifecycle-st (multi-connection ST).

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
    instance_id      = module.postgres.instance_id
    config_hash      = filesha256(local.shadowtraffic_generator)
    connections_hash = local_file.shadowtraffic_connections[0].content_md5
    license_hash     = md5(local_file.shadowtraffic_license[0].content)
    image            = var.shadowtraffic_image
  }

  depends_on = [
    module.postgres,
    module.keypair,
    local_file.shadowtraffic_connections,
    local_file.shadowtraffic_license,
  ]

  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = file(module.keypair.private_key_path)
    host        = module.postgres.public_dns
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/shadowtraffic",
      "sudo chown -R ${var.ssh_username}:${var.ssh_username} /opt/shadowtraffic",
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
        set -eu
        if ! command -v jq >/dev/null 2>&1; then
          sudo yum install -y jq || sudo dnf install -y jq
        fi

        jq -s '.[0] * {connections: .[1]}' \
          /opt/shadowtraffic/riverpay-generator.json \
          /opt/shadowtraffic/connections.json \
          > /opt/shadowtraffic/config.json

        # Align riverpay schema / FX seed (same as azure-shared)
        sudo docker exec -i postgres-workshop psql -U ${var.postgres_db_username} -d ${var.postgres_db_name} <<'SQL'
CREATE SCHEMA IF NOT EXISTS riverpay;
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
        status=$(sudo docker inspect -f '{{.State.Status}}' shadowtraffic-riverpay 2>/dev/null || echo missing)
        if [ "$status" != "running" ]; then
          echo "ERROR: ShadowTraffic container status=$status"
          sudo docker logs shadowtraffic-riverpay 2>&1 || true
          exit 1
        fi
        echo "ShadowTraffic postgres generators running (profiles + FX → CDC fan-out)"
      EOT
    ]
  }
}
