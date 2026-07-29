# ===============================
# Self-service Risk Scoring API on datagen VM (HTTP :8089)
# ===============================
# Elevate instructor-led uses azure-shared Container Apps (HTTPS).
# Azure BYO collates Risk API with ShadowTraffic on the datagen VM (aws-demo parity).

locals {
  deploy_byo_risk_api   = var.enable_risk_api && !local.use_shared && local.deploy_datagen_vm
  risk_api_dir          = "${path.module}/../../services/risk-api"
  risk_api_port         = 8089
  byo_risk_api_endpoint = local.deploy_byo_risk_api ? "http://${azurerm_public_ip.datagen[0].ip_address}:${local.risk_api_port}" : ""
}

resource "null_resource" "byo_risk_api_deploy" {
  count = local.deploy_byo_risk_api ? 1 : 0

  triggers = {
    vm_id       = azurerm_linux_virtual_machine.datagen[0].id
    app_hash    = filesha256("${local.risk_api_dir}/app.py")
    docker_hash = filesha256("${local.risk_api_dir}/Dockerfile")
    req_hash    = filesha256("${local.risk_api_dir}/requirements.txt")
    api_key     = var.risk_api_key
  }

  depends_on = [
    azurerm_linux_virtual_machine.datagen,
    local_file.datagen_ssh_private_key,
  ]

  connection {
    type        = "ssh"
    user        = local.datagen_ssh_user
    private_key = tls_private_key.datagen[0].private_key_pem
    host        = azurerm_public_ip.datagen[0].ip_address
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/risk-api",
      "sudo chown -R ${local.datagen_ssh_user}:${local.datagen_ssh_user} /opt/risk-api",
      "for i in $(seq 1 60); do command -v docker >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1 && break; sleep 5; done",
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
        set -eu
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
        curl -fsS "http://127.0.0.1:${local.risk_api_port}/health"
        echo "BYO Risk API healthy on :${local.risk_api_port}"
      EOT
    ]
  }
}
