resource "hcloud_volume" "management_k8s" {
  name      = "management-k3s-data"
  size      = 25
  location  = local.management_k8s.location
  format    = "ext4"
  automount = false
}

resource "hcloud_volume_attachment" "management_k8s" {
  volume_id = hcloud_volume.management_k8s.id
  server_id = hcloud_server.management_k8s.id
  automount = false
}
