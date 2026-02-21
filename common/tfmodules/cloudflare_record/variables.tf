variable "zone_name" {
  type = string
}

variable "subdomain" {
  type = string
}

variable "content" {
  type = string
}

variable "proxied" {
  type    = bool
  default = true
}
