locals {
  auth_data       = yamldecode(file(format("%s/../..config/auth.yaml", path.module)))
  ssh_public_keys = local.auth_data.ssh_public_keys
}
