locals {
  management_k8s = {
    name          = "management-k8s"
    image_version = "20260221185753"
    size          = "cx23"
    location      = "nbg1" // Nuremberg
    endpoint = {
      zone      = "fergal.website"
      subdomain = "k8s.management"
    }
  }
}

resource "hcloud_server" "management_k8s" {
  name        = local.management_k8s.name
  image       = data.hcloud_image.management_k8s_snapshot.id
  server_type = local.management_k8s.size
  location    = local.management_k8s.location
  ssh_keys    = [for ssh_key in hcloud_ssh_key.management : ssh_key.id]
  user_data   = <<EOD
#cloud-config
write_files:
- path: /etc/k3s-hostname
  owner: root:root
  permissions: '0644'
  content: "${local.management_k8s.endpoint.subdomain}.${local.management_k8s.endpoint.zone}"
EOD

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
