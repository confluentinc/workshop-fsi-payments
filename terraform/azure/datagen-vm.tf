# ===============================
# Self-service datagen VM (Azure BYO)
# ===============================
# When shared_* is empty: Flexible Server holds Postgres; this VM runs Docker for
# ShadowTraffic (profiles+FX+lifecycle) and the Risk Scoring API (:8089 HTTP).
# Elevate shared mode keeps ST + Risk API on azure-shared (VM + Container Apps).

locals {
  deploy_datagen_vm = !local.use_shared && (var.enable_shadowtraffic || var.enable_risk_api)
  datagen_ssh_user  = var.datagen_vm_admin_username
}

resource "tls_private_key" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "datagen_ssh_private_key" {
  count = local.deploy_datagen_vm ? 1 : 0

  content         = tls_private_key.datagen[0].private_key_pem
  filename        = "${path.module}/sshkey-datagen-${local.resource_suffix}.pem"
  file_permission = "0600"
}

resource "azurerm_virtual_network" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  name                = "${local.prefix}-datagen-vnet-${local.resource_suffix}"
  location            = var.cloud_region
  resource_group_name = local.effective_resource_group_name
  address_space       = ["10.20.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  name                 = "${local.prefix}-datagen-subnet-${local.resource_suffix}"
  resource_group_name  = local.effective_resource_group_name
  virtual_network_name = azurerm_virtual_network.datagen[0].name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  name                = "${local.prefix}-datagen-nsg-${local.resource_suffix}"
  location            = var.cloud_region
  resource_group_name = local.effective_resource_group_name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRiskAPI"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8089"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  subnet_id                 = azurerm_subnet.datagen[0].id
  network_security_group_id = azurerm_network_security_group.datagen[0].id
}

resource "azurerm_public_ip" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  name                = "${local.prefix}-datagen-pip-${local.resource_suffix}"
  location            = var.cloud_region
  resource_group_name = local.effective_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  name                = "${local.prefix}-datagen-nic-${local.resource_suffix}"
  location            = var.cloud_region
  resource_group_name = local.effective_resource_group_name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.datagen[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.datagen[0].id
  }
}

resource "azurerm_linux_virtual_machine" "datagen" {
  count = local.deploy_datagen_vm ? 1 : 0

  name                = "${local.prefix}-datagen-${local.resource_suffix}"
  resource_group_name = local.effective_resource_group_name
  location            = var.cloud_region
  size                = var.datagen_vm_size
  admin_username      = local.datagen_ssh_user

  network_interface_ids = [azurerm_network_interface.datagen[0].id]

  admin_ssh_key {
    username   = local.datagen_ssh_user
    public_key = tls_private_key.datagen[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/datagen-cloud-init.yaml.tpl", {
    admin_username = local.datagen_ssh_user
  }))

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-datagen"
    Role = "shadowtraffic-risk-api"
  })

  depends_on = [azurerm_resource_group.main]
}
