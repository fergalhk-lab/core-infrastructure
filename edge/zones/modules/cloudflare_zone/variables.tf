variable "fqdn" {
  type        = string
  description = "The FQDN of the zone to create."
}

variable "security_level" {
  type        = string
  description = "The Cloudflare security level to configure"
  validation {
    condition     = contains(["off", "essentially_off", "low", "medium", "high", "under_attack"], var.security_level)
    error_message = format("The value of var.security_level must be one of %v", ["off", "essentially_off", "low", "medium", "high", "under_attack"])
  }
}
