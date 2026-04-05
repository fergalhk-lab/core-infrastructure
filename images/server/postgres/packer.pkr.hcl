packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1.7.0"
    }
    ansible = {
      version = "~> 1.1.4"
      source  = "github.com/hashicorp/ansible"
    }
  }
}
