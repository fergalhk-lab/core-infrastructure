# Server images

## Prerequisites

* Packer
* Ansible

## Build

1. Set the `HCLOUD_TOKEN` environment variable to the value of a read/write token in the `build` project.
1. Run `packer init <image name>`.
1. Run `packer build <image name>`.
