data "hcloud_image" "management_k8s_snapshot" {
  name              = local.management_k8s.image_name
  with_architecture = "x86"
}
