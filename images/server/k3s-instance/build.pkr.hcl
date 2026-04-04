locals {
  k3s_version                     = "v1.33.3"
  ecr_credential_provider_version = "v1.35.1"
}

build {
  sources = ["source.hcloud.base"]
  provisioner "ansible" {
    playbook_file = "ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars",
      "k3s_version=${local.k3s_version} ecr_credential_provider_version=${local.ecr_credential_provider_version}"
    ]
  }
}
