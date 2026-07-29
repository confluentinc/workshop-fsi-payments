# ===============================
# Multi-cluster lifecycle ShadowTraffic
# ===============================
# One Docker container on the shared Postgres/datagen host with N Kafka
# connections and 4×N generators (initiation/auth/balance/status per attendee).

locals {
  # Always expand config when clusters are provided (dry-run / inspect without SSH).
  # Docker deploy additionally needs enabled + SSH target.
  parse  = length(var.clusters) > 0
  deploy = var.enabled && local.parse && var.ssh_host != "" && var.ssh_private_key_path != ""

  template_path = var.generator_template_path != "" ? var.generator_template_path : "${path.module}/../../../shadowtraffic/riverpay-generator-kafka.json"
  # Always load the single-cluster template (local file); expansion is a no-op when clusters=[].
  base = jsondecode(file(local.template_path))

  # Expand template generators once per cluster: unique names, connection, fork targets, payment_id prefix.
  generators = flatten([
    for c in var.clusters : [
      for g in local.base.generators : merge(
        { for k, v in g : k => v if !contains(["name", "connection", "fork", "vars", "localConfigs"], k) },
        {
          name       = "${g.name}-${c.id}"
          connection = "kafka-${c.id}"
        },
        try(g.vars, null) != null ? {
          vars = merge(
            g.vars,
            g.name == "payment_initiation" ? {
              payment_id = merge(g.vars.payment_id, {
                expr = "${replace(c.id, "/[^A-Za-z0-9]/", "")}-PMT-~d"
              })
            } : {}
          )
        } : {},
        try(g.fork, null) != null ? {
          fork = merge(g.fork, {
            key = merge(g.fork.key, {
              name = "${g.fork.key.name}-${c.id}"
            })
          })
        } : {},
        try(g.localConfigs, null) != null ? {
          localConfigs = merge(
            g.localConfigs,
            g.name == "payment_initiation" ? { throttleMs = var.initiation_throttle_ms } : {}
          )
        } : {}
      )
    ]
  ])

  schedule = {
    stages = [{
      generators = flatten([
        for c in var.clusters : [for g in local.base.generators : "${g.name}-${c.id}"]
      ])
    }]
  }

  connections = {
    for c in var.clusters : "kafka-${c.id}" => {
      kind = "kafka"
      producerConfigs = {
        "bootstrap.servers"             = c.bootstrap_endpoint
        "security.protocol"             = "SASL_SSL"
        "sasl.mechanism"                = "PLAIN"
        "sasl.jaas.config"              = "org.apache.kafka.common.security.plain.PlainLoginModule required username='${c.kafka_api_key}' password='${c.kafka_api_secret}';"
        "schema.registry.url"           = c.schema_registry_endpoint
        "basic.auth.credentials.source" = "USER_INFO"
        "basic.auth.user.info"          = "${c.schema_registry_api_key}:${c.schema_registry_api_secret}"
        "key.serializer"                = "io.confluent.kafka.serializers.KafkaAvroSerializer"
        "value.serializer"              = "io.confluent.kafka.serializers.KafkaAvroSerializer"
        "auto.register.schemas"         = "true"
        "use.latest.version"            = "true"
      }
    }
  }

  config_object = merge(
    { for k, v in local.base : k => v if !contains(["generators", "schedule", "connections"], k) },
    {
      generators  = local.generators
      schedule    = local.schedule
      connections = local.connections
    }
  )

  config_json = jsonencode(local.config_object)
  cluster_ids = join(",", [for c in var.clusters : c.id])
}

data "http" "license" {
  count = local.deploy ? 1 : 0
  url   = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

resource "local_file" "license" {
  count = local.deploy ? 1 : 0

  content         = data.http.license[0].response_body
  filename        = "${path.module}/generated/shadow-traffic-license.env"
  file_permission = "0600"
}

resource "local_file" "config" {
  count = local.parse ? 1 : 0

  content         = local.config_json
  filename        = "${path.module}/generated/lifecycle-multi-cluster-config.json"
  file_permission = "0600"
}

resource "null_resource" "deploy" {
  count = local.deploy ? 1 : 0

  triggers = {
    host            = var.ssh_host
    ssh_user        = var.ssh_user
    ssh_private_key = file(var.ssh_private_key_path)
    container       = var.container_name
    remote_dir      = var.remote_dir
    image           = var.shadowtraffic_image
    metrics_port    = tostring(var.metrics_port)
    config_hash     = local_file.config[0].content_md5
    license_hash    = md5(local_file.license[0].content)
    cluster_ids     = local.cluster_ids
  }

  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    private_key = self.triggers.ssh_private_key
    host        = self.triggers.host
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.remote_dir}",
      "sudo chown -R ${var.ssh_user}:${var.ssh_user} ${var.remote_dir}",
    ]
  }

  provisioner "file" {
    source      = local_file.config[0].filename
    destination = "${var.remote_dir}/config.json"
  }

  provisioner "file" {
    source      = local_file.license[0].filename
    destination = "${var.remote_dir}/shadow-traffic-license.env"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        set -eu
        REMOTE_DIR="${var.remote_dir}"
        CONTAINER="${var.container_name}"
        IMAGE="${var.shadowtraffic_image}"
        METRICS_PORT="${var.metrics_port}"

        if ! command -v jq >/dev/null 2>&1; then
          if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -y && sudo apt-get install -y jq
          elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y jq
          elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y jq
          fi
        fi

        echo "Pulling $IMAGE..."
        sudo docker pull "$IMAGE"

        sudo docker rm -f "$CONTAINER" 2>/dev/null || true
        # metrics-port 0 (or non-9400): shared Postgres ST already binds :9400 on host network
        sudo docker run -d --name "$CONTAINER" \
          --network host \
          --restart unless-stopped \
          --env-file "$REMOTE_DIR/shadow-traffic-license.env" \
          -v "$REMOTE_DIR/config.json:/home/config.json:ro" \
          "$IMAGE" \
          --config /home/config.json \
          --metrics-port "$METRICS_PORT"

        echo "Lifecycle multi-cluster ShadowTraffic started as $CONTAINER (clusters: ${local.cluster_ids})"
        sleep 25
        status=$(sudo docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
        if [ "$status" != "running" ]; then
          echo "ERROR: container status=$status"
          sudo docker logs "$CONTAINER" 2>&1 || true
          exit 1
        fi
        if sudo docker logs "$CONTAINER" 2>&1 | grep -q 'configuration errors'; then
          echo "ERROR: ShadowTraffic configuration errors"
          sudo docker logs --tail 120 "$CONTAINER" 2>&1 || true
          exit 1
        fi
        echo "Lifecycle multi-cluster generators OK"
      EOT
    ]
  }

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
