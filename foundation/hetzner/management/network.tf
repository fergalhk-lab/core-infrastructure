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
