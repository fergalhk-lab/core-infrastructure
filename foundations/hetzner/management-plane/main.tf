resource "tls_private_key" "management_k8s" {
  algorithm = "ED25519"
}

resource "aws_secretsmanager_secret" "management_k8s_ssh" {
  name = "hetzner/ssh-keys/management"
}

resource "aws_secretsmanager_secret_version" "management_k8s_ssh" {
  secret_id     = aws_secretsmanager_secret.management_k8s_ssh.id
  secret_string = tls_private_key.management_k8s.private_key_openssh
}

resource "hcloud_ssh_key" "management_k8s" {
  name       = "management-k8s"
  public_key = tls_private_key.management_k8s.public_key_openssh
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
  image       = local.management_k8s.image
  server_type = local.management_k8s.size
  ssh_keys    = [hcloud_ssh_key.management_k8s.id]

  network {
    network_id = hcloud_network.management.id
  }

  depends_on = [hcloud_network_subnet.management]
}
