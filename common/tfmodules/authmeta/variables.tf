variable "enable_cloudflare" {
  type    = bool
  default = false
}

variable "enabled_hetzner_projects" {
  type    = list(string)
  default = []
}
