locals {
  management_k8s = {
    name          = "management-k8s"
    image_version = "20260221180944"
    size          = "cx23"
    location      = "nbg1" // Nuremberg
    endpoint = {
      zone      = "fergal.website"
      subdomain = "management.k8s"
    }
  }
}

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
  location    = local.management_k8s.location
  ssh_keys    = [for ssh_key in hcloud_ssh_key.management : ssh_key.id]

  network {
    network_id = hcloud_network.management.id
  }

  depends_on = [hcloud_network_subnet.management]
}

module "management_k8s_dns" {
  source = "../../../common/tfmodules/cloudflare_record"

  zone_name = local.management_k8s.endpoint.zone
  subdomain = local.management_k8s.endpoint.subdomain
  content   = hcloud_server.management_k8s.ipv4_address
  proxied   = false // proxying breaks mTLS
}
