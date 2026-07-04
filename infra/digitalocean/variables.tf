variable "digitalocean_access_token" {
  description = "DigitalOcean API token used by the provider."
  type        = string
  sensitive   = true
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "api_repo" {
  type = string
}

variable "web_repo" {
  type = string
}

variable "branch" {
  type = string
}

variable "enable_postgres" {
  type    = bool
  default = true
}

variable "enable_opensearch" {
  type    = bool
  default = false
}

variable "enable_spaces" {
  type    = bool
  default = true
}

variable "rails_master_key" {
  type      = string
  sensitive = true
}
