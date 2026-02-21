resource "hcloud_network" "management" {
  name     = "management"
  ip_range = "10.0.0.0/20"
}

resource "hcloud_network_subnet" "management" {
  network_id   = hcloud_network.management.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

resource "hcloud_server" "management_k8s" {
  name        = local.management_k8s.name
  image       = data.hcloud_image.management_k8s_snapshot.id
  server_type = local.management_k8s.size
  ssh_keys    = [for ssh_key in hcloud_ssh_key.management : ssh_key.id]

  network {
    network_id = hcloud_network.management.id
  }

  depends_on = [hcloud_network_subnet.management]
}
