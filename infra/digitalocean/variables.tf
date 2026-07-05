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

variable "do_region" {
  type    = string
  default = "nyc3"
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

variable "enable_api" {
  type    = bool
  default = true
}

variable "enable_worker" {
  type    = bool
  default = true
}

variable "enable_web" {
  type    = bool
  default = true
}

variable "api_instance_size_slug" {
  type    = string
  default = "basic-xxs"
}

variable "worker_instance_size_slug" {
  type    = string
  default = "basic-xxs"
}

variable "web_instance_size_slug" {
  type    = string
  default = "basic-xxs"
}

variable "api_run_command" {
  type    = string
  default = "bundle exec puma -C config/puma.rb"
}

variable "worker_run_command" {
  type    = string
  default = "bundle exec good_job start"
}

variable "migrate_run_command" {
  type    = string
  default = "bundle exec rails db:migrate"
}

variable "web_build_command" {
  type    = string
  default = "npm ci && npm run build"
}

variable "web_output_dir" {
  type    = string
  default = "dist"
}

variable "cors_allowed_origins" {
  type    = string
  default = null
}

variable "vite_api_base_url" {
  type    = string
  default = null
}

variable "database_url" {
  type    = string
  default = null
}

variable "opensearch_url" {
  type    = string
  default = null
}

variable "active_storage_service" {
  type    = string
  default = null
}

variable "data_artifact_bucket" {
  type    = string
  default = null
}

variable "s3_endpoint" {
  type    = string
  default = null
}

variable "aws_access_key_id" {
  type      = string
  default   = null
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "enable_postgres" {
  type    = bool
  default = true
}

variable "postgres_version" {
  type    = string
  default = "18"
}

variable "postgres_size_slug" {
  type    = string
  default = "db-s-1vcpu-1gb"
}

variable "postgres_node_count" {
  type    = number
  default = 1
}

variable "postgres_db_name" {
  type    = string
  default = "app"
}

variable "postgres_user_name" {
  type    = string
  default = "app"
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
