# ===============================
# Stage 1 — Outputs
# ===============================

output "cluster_id" {
  description = "ROSA HCP cluster ID."
  value       = module.hcp.cluster_id
}

output "cluster_api_url" {
  description = "OpenShift API server URL (use with oc login)."
  value       = module.hcp.cluster_api_url
}

output "cluster_console_url" {
  description = "OpenShift web console URL."
  value       = module.hcp.cluster_console_url
}

output "cluster_domain" {
  description = "Cluster DNS domain (apps domain is typically apps.<domain>)."
  value       = module.hcp.cluster_domain
}

output "cluster_state" {
  description = "Cluster state reported by OCM."
  value       = module.hcp.cluster_state
}

output "cluster_current_version" {
  description = "Running OpenShift version."
  value       = module.hcp.cluster_current_version
}

output "cluster_admin_username" {
  description = "Cluster-admin username created with the cluster."
  value       = module.hcp.cluster_admin_username
}

output "cluster_admin_password" {
  description = "Cluster-admin password (sensitive)."
  value       = module.hcp.cluster_admin_password
  sensitive   = true
}

output "htpasswd_username" {
  description = "HTPasswd IDP demo username."
  value       = "riverpay-demo"
}

output "htpasswd_password" {
  description = "HTPasswd IDP demo password (sensitive)."
  value       = random_password.htpasswd.result
  sensitive   = true
}

output "aws_region" {
  description = "AWS region used for this cluster."
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID created for ROSA."
  value       = module.vpc.vpc_id
}

output "next_steps" {
  description = "Commands to log in and proceed to Stage 2."
  value       = <<-EOT
    # 1) Log in to the cluster (cluster-admin from terraform output)
    oc login $(terraform output -raw cluster_api_url) \
      -u $(terraform output -raw cluster_admin_username) \
      -p "$(terraform output -raw cluster_admin_password)"

    # 2) Confirm nodes / storage class
    oc get nodes
    oc get sc

    # 3) Export kubeconfig path for Stage 2 (default kubeconfig is fine if oc login succeeded)
    export KUBECONFIG="$${KUBECONFIG:-$HOME/.kube/config}"

    # 4) Continue with Stage 2
    cd ../stage2-cfk
    cp sample-tfvars terraform.tfvars   # edit if needed
    terraform init
    terraform apply
  EOT
}
