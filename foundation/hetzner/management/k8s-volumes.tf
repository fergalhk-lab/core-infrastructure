locals {
  management_k8s_volumes = {
    etcd = { size = 3  } # generous for single-node embedded etcd
    tls  = { size = 1  } # cluster CA and TLS certs are small
    pvs  = { size = 25 } # local-path-provisioner PV storage
  }
}

resource "hcloud_volume" "management_k8s" {
  for_each  = local.management_k8s_volumes
  name      = "management-k3s-${each.key}"
  size      = each.value.size
  location  = local.management_k8s.location
  format    = "ext4"
  automount = false
}

resource "hcloud_volume_attachment" "management_k8s" {
  for_each  = local.management_k8s_volumes
  volume_id = hcloud_volume.management_k8s[each.key].id
  server_id = hcloud_server.management_k8s.id
  automount = false
}
