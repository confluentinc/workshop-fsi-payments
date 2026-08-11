# ===============================
# AWS instructor-led: multi-cluster lifecycle ShadowTraffic
# ===============================
# Does NOT create Kafka. After wsa build (or manual account applies), collect
# each account's lifecycle_st_cluster output + shared SSH, then apply this root.
# See scripts/wsa-deploy-lifecycle-st.sh

module "lifecycle_st" {
  source = "../modules/lifecycle-shadowtraffic"

  clusters               = var.clusters
  ssh_host               = var.ssh_host
  ssh_user               = var.ssh_user
  ssh_private_key_path   = var.ssh_private_key_path
  shadowtraffic_image    = var.shadowtraffic_image
  initiation_throttle_ms = var.initiation_throttle_ms
  metrics_port           = var.metrics_port
  enabled                = var.enabled
}
