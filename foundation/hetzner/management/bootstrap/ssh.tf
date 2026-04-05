resource "hcloud_ssh_key" "management" {
  for_each   = module.meta.ssh_public_keys
  name       = format("management-%s", each.key)
  public_key = each.value
}
