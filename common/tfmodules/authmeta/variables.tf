variable "enable_cloudflare" {
  type    = bool
  default = false
}

variable "enabled_hetzner_projects" {
  type    = set(string)
  default = []
}
