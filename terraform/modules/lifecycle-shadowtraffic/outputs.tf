output "container_name" {
  description = "Docker container name on the shared VM"
  value       = var.container_name
}

output "cluster_count" {
  description = "Number of Kafka clusters in the generated config"
  value       = length(var.clusters)
}

output "config_path" {
  description = "Local path to generated multi-cluster config (null when no clusters)"
  value       = local.parse ? local_file.config[0].filename : null
}

output "deployed" {
  description = "Whether the lifecycle ST container was deployed"
  value       = local.deploy
}
