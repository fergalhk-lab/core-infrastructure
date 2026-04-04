resource "hcloud_volume" "management_k8s" {
  name      = "management-k3s-data"
  size      = local.management_k8s.data_volume.size
  location  = local.management_k8s.location
  format    = local.management_k8s.data_volume.format
  automount = false
}

resource "hcloud_volume_attachment" "management_k8s" {
  volume_id = hcloud_volume.management_k8s.id
  server_id = hcloud_server.management_k8s.id
  automount = false
}
