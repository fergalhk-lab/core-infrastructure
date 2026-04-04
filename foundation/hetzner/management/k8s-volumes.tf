locals {
  management_k8s_volumes = {
    etcd = { size = 3,  mount_point = "/var/lib/rancher/k3s/server/db"  }
    tls  = { size = 1,  mount_point = "/var/lib/rancher/k3s/server/tls" }
    pvs  = { size = 25, mount_point = "/var/lib/rancher/k3s/storage"    }
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
