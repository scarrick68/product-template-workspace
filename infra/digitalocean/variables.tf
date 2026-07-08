variable "digitalocean_access_token" {
  description = "DigitalOcean API token used by the provider."
  type        = string
  sensitive   = true
}

variable "spaces_access_key_id" {
  description = "Optional DO Spaces access key for bucket/key operations (or use SPACES_ACCESS_KEY_ID env var)."
  type        = string
  default     = null
  sensitive   = true
}

variable "spaces_secret_access_key" {
  description = "Optional DO Spaces secret key for bucket/key operations (or use SPACES_SECRET_ACCESS_KEY env var)."
  type        = string
  default     = null
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

variable "project_name" {
  description = "DigitalOcean Project name that groups resources for this app/environment."
  type        = string
}

variable "project_purpose" {
  description = "DigitalOcean Project purpose label."
  type        = string
  default     = "Web Application"
}

variable "project_environment" {
  description = "DigitalOcean Project environment label (development|staging|production)."
  type        = string
  default     = "production"
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
  default = true
}

variable "opensearch_version" {
  type    = string
  default = "3"
}

variable "opensearch_size_slug" {
  type    = string
  default = "db-s-1vcpu-2gb"
}

variable "opensearch_node_count" {
  type    = number
  default = 1
}

variable "enable_spaces" {
  type    = bool
  default = true
}

variable "spaces_provider" {
  description = "Blob storage backend mode: digitalocean_spaces (managed) or aws_s3 (external)."
  type        = string
  default     = "digitalocean_spaces"

  validation {
    condition     = contains(["digitalocean_spaces", "aws_s3"], var.spaces_provider)
    error_message = "spaces_provider must be one of: digitalocean_spaces, aws_s3."
  }
}

variable "spaces_create_bucket" {
  description = "Create a DigitalOcean Spaces bucket when spaces_provider is digitalocean_spaces."
  type        = bool
  default     = true
}

variable "spaces_create_key" {
  description = "Create a DigitalOcean Spaces access key when spaces_provider is digitalocean_spaces."
  type        = bool
  default     = true
}

variable "spaces_force_destroy" {
  description = "Allow destroying a non-empty managed Spaces bucket."
  type        = bool
  default     = false
}

variable "rails_master_key" {
  type      = string
  sensitive = true
}
