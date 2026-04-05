locals {
  pg_version = "18"
}

build {
  sources = ["source.hcloud.base"]
  provisioner "ansible" {
    playbook_file = "ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars",
      "pg_version=${local.pg_version}"
    ]
    ansible_env_vars = ["ANSIBLE_ROLES_PATH=${path.root}/../_common/ansible/roles"]
  }
}
