locals {
  management_k8s = {
    name          = "management-k8s"
    image_version = "20260221204139"
    size          = "cx23"
    location      = "nbg1" // Nuremberg
    apiserver_endpoint = {
      zone      = "fergal.website"
      subdomain = "k8s.management"
    }
    anonymous_issuer_endpoint = {
      zone      = "fergal.website"
      subdomain = "issuer-k8s-management" // this needs to be a single level to get a cloudflare cert
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
runcmd:
  - /root/bootstrap-k3s.sh '${local.management_k8s.apiserver_endpoint.subdomain}.${local.management_k8s.apiserver_endpoint.zone}' '${local.management_k8s.anonymous_issuer_endpoint.subdomain}.${local.management_k8s.anonymous_issuer_endpoint.zone}'
EOD

  network {
    network_id = hcloud_network.management.id
  }

  depends_on = [hcloud_network_subnet.management]
}

module "management_k8s_apiserver_dns" {
  source = "../../../common/tfmodules/cloudflare_record"

  zone_name = local.management_k8s.apiserver_endpoint.zone
  subdomain = local.management_k8s.apiserver_endpoint.subdomain
  content   = hcloud_server.management_k8s.ipv4_address
  proxied   = false // proxying breaks mTLS
}
