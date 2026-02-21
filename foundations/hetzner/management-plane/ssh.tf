resource "tls_private_key" "management" {
  algorithm = "ED25519"
}

resource "aws_secretsmanager_secret" "management_ssh" {
  name = "hetzner/ssh-keys/management"
}

resource "aws_secretsmanager_secret_version" "management_ssh" {
  secret_id     = aws_secretsmanager_secret.management_ssh.id
  secret_string = tls_private_key.management.private_key_openssh
}

resource "hcloud_ssh_key" "management" {
  name       = "management"
  public_key = tls_private_key.management.public_key_openssh
}
