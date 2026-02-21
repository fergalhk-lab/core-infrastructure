data "hcloud_image" "management_k8s_snapshot" {
  with_selector     = format("instance=k3s,version=%s", local.management_k8s.image_version)
  with_architecture = "x86"
}
