# ===============================
# Shared Risk Scoring API (demo host)
# ===============================
# Runs on the Postgres EC2 instance as a public HTTP service for Flink UDF
# external connectivity. Elevate instructor-led should prefer a single Azure
# HTTPS URL; this gives aws-demo a working shared endpoint.

locals {
  deploy_risk_api = var.enable_risk_api && !local.use_shared
  risk_api_dir    = "${path.module}/../../services/risk-api"
  risk_api_port   = 8089
}

resource "null_resource" "risk_api_deploy" {
  count = local.deploy_risk_api ? 1 : 0

  triggers = {
    instance_id = module.postgres[0].instance_id
    app_hash    = filesha256("${local.risk_api_dir}/app.py")
    docker_hash = filesha256("${local.risk_api_dir}/Dockerfile")
    req_hash    = filesha256("${local.risk_api_dir}/requirements.txt")
    api_key     = var.risk_api_key
  }

  depends_on = [
    module.postgres,
    module.keypair,
  ]

  connection {
    type        = "ssh"
    user        = var.shadowtraffic_ssh_username
    private_key = file(module.keypair[0].private_key_path)
    host        = module.postgres[0].public_dns
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/risk-api",
      "sudo chown -R ${var.shadowtraffic_ssh_username}:${var.shadowtraffic_ssh_username} /opt/risk-api",
    ]
  }

  provisioner "file" {
    source      = "${local.risk_api_dir}/app.py"
    destination = "/opt/risk-api/app.py"
  }

  provisioner "file" {
    source      = "${local.risk_api_dir}/Dockerfile"
    destination = "/opt/risk-api/Dockerfile"
  }

  provisioner "file" {
    source      = "${local.risk_api_dir}/requirements.txt"
    destination = "/opt/risk-api/requirements.txt"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        set -e
        # Wait for Docker (postgres user-data installs it)
        for i in $(seq 1 60); do
          if command -v docker >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
            break
          fi
          sleep 5
        done
        command -v docker >/dev/null 2>&1 || { echo "Docker not available"; exit 1; }

        cd /opt/risk-api
        sudo docker build -t riverpay-risk-api:local .
        sudo docker rm -f riverpay-risk-api 2>/dev/null || true
        sudo docker run -d --name riverpay-risk-api \
          --restart unless-stopped \
          -p ${local.risk_api_port}:8089 \
          -e PORT=8089 \
          -e RISK_API_KEY='${var.risk_api_key}' \
          riverpay-risk-api:local

        sleep 3
        curl -fsS "http://127.0.0.1:${local.risk_api_port}/health" || {
          echo "Risk API health check failed"
          sudo docker logs riverpay-risk-api 2>&1 || true
          exit 1
        }
        echo "Risk API is healthy on :${local.risk_api_port}"
      EOT
    ]
  }
}
