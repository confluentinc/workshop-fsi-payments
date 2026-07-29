# ===============================
# Shared Infrastructure Outputs
# ===============================
# These values are passed to per-account Terraform (terraform/aws/)
# via `wsa build` as TF_VAR_shared_* variables.

# --- Networking ---

output "vpc_id" {
  description = "Shared VPC ID"
  value       = module.networking.vpc_id
}

output "subnet_id" {
  description = "Shared public subnet ID"
  value       = module.networking.public_subnet_id
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = module.networking.aws_account_id
}

# --- S3 ---

output "s3_bucket_name" {
  description = "Shared S3 bucket name"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "Shared S3 bucket ARN"
  value       = module.s3.bucket_arn
}

output "s3_bucket_url" {
  description = "Shared S3 bucket URL (s3://...)"
  value       = module.s3.bucket_url
}

# --- SSH ---

output "key_name" {
  description = "Shared SSH key pair name"
  value       = module.keypair.key_name
}

output "private_key_path" {
  description = "Absolute path to the shared SSH private key"
  value       = abspath(module.keypair.private_key_path)
}

# WSA aliases for lifecycle multi-cluster ST + per-attendee CDC
output "postgres_ssh_private_key_path" {
  description = "WSA alias: absolute path to shared SSH private key"
  value       = abspath(module.keypair.private_key_path)
}

output "postgres_ssh_username" {
  description = "WSA alias: SSH username on shared Postgres EC2"
  value       = var.ssh_username
}

output "risk_api_endpoint" {
  description = "Shared Risk Scoring API HTTP base URL"
  value       = var.enable_risk_api ? "http://${module.postgres.public_dns}:8089" : null
}

output "risk_api_key" {
  description = "API key for Flink CREATE CONNECTION"
  value       = var.risk_api_key
  sensitive   = true
}

output "shadowtraffic_container" {
  description = "Shared ShadowTraffic container name (postgres profiles + FX)"
  value       = var.enable_shadowtraffic ? "shadowtraffic-riverpay" : null
}

# --- PostgreSQL ---

output "postgres_hostname" {
  description = "Shared PostgreSQL public DNS hostname"
  value       = module.postgres.public_dns
}

output "postgres_public_ip" {
  description = "Shared PostgreSQL public IP"
  value       = module.postgres.public_ip
}

output "postgres_instance_id" {
  description = "Shared PostgreSQL EC2 instance ID"
  value       = module.postgres.instance_id
}

output "postgres_security_group_id" {
  description = "Shared PostgreSQL security group ID"
  value       = module.postgres.security_group_id
}

# --- PostgreSQL Credentials ---

output "postgres_db_password" {
  description = "PostgreSQL admin password (generated or explicit)"
  value       = local.effective_postgres_db_password
  sensitive   = true
}

output "postgres_debezium_password" {
  description = "PostgreSQL Debezium CDC user password (generated or explicit)"
  value       = local.effective_postgres_debezium_password
  sensitive   = true
}

# --- Databricks SP (ephemeral workshop secret) ---

output "dbx_sp_client_id" {
  description = "Databricks service principal Application (Client) ID"
  value       = var.databricks_service_principal_client_id
}

output "dbx_sp_client_secret" {
  description = "Ephemeral OAuth secret for the Databricks service principal (created per workshop, deleted on clean)"
  value       = databricks_service_principal_secret.workshop.secret
  sensitive   = true
}

# --- Monitoring ---

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.cloud_region}.console.aws.amazon.com/cloudwatch/home?region=${var.cloud_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.shared_infra.dashboard_name}"
}

# --- Summary ---

output "shared_infra_summary" {
  description = "Summary of shared infrastructure for wsa build"
  value = {
    vpc_id                 = module.networking.vpc_id
    subnet_id              = module.networking.public_subnet_id
    s3_bucket_arn          = module.s3.bucket_arn
    s3_bucket_url          = module.s3.bucket_url
    key_name               = module.keypair.key_name
    postgres_hostname      = module.postgres.public_dns
    postgres_public_ip     = module.postgres.public_ip
    dbx_external_location  = databricks_external_location.shared.name
    dbx_storage_credential = databricks_storage_credential.shared.name
    ssh_command            = "ssh -i ${module.keypair.private_key_path} ec2-user@${module.postgres.public_dns}"
  }
}
