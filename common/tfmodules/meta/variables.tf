variable "enable_cloudflare_api_token" {
  type    = bool
  default = false
}

variable "enabled_hetzner_project_api_tokens" {
  type    = set(string)
  default = []
}
