locals {
  build_time = formatdate("YYYYMMDDhhmmss", timestamp())
}

source "hcloud" "base" {
  image        = "ubuntu-24.04"
  location     = "nbg1"
  server_type  = "cx23"
  ssh_username = "root"
  server_labels = {
    type       = "packer-build"
    build_time = local.build_time
  }
  snapshot_name        = format("k3s-%s", local.build_time)
  skip_create_snapshot = !var.save_snapshot
  snapshot_labels = {
    instance = "k3s"
    base     = "ubuntu-22.04"
    version  = local.build_time
  }
}
