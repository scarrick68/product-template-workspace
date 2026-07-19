variable "project_name" {
  type = string
}

variable "project_slug" {
  type = string
}

variable "installation_id" {
  description = "Stable identifier generated when this project workspace was created."
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{6}$", var.installation_id))
    error_message = "installation_id must be six lowercase hexadecimal characters."
  }
}

variable "project_description" {
  type    = string
  default = "Managed by Terraform"
}

variable "rails_app_name" {
  type    = string
  default = "terraform-v2-rails-app"
}

variable "app_region" {
  type    = string
  default = "nyc"
}

variable "rails_github_repo" {
  description = "GitHub repository in owner/repository format for backend components."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.rails_github_repo))
    error_message = "rails_github_repo must use owner/repository format."
  }
}

variable "rails_github_branch" {
  type    = string
  default = "main"
}

variable "rails_deploy_on_push" {
  type    = bool
  default = false
}

variable "rails_source_dir" {
  type    = string
  default = "/"
}

variable "rails_web_run_command" {
  type    = string
  default = "bundle exec puma -C config/puma.rb"
}

variable "rails_worker_run_command" {
  type    = string
  default = "bundle exec good_job start"
}

variable "rails_cors_allowed_origins" {
  description = "Comma-delimited allowed origins for Rails CORS config."
  type        = string
  default     = ""
}

variable "web_instance_size_slug" {
  type    = string
  default = "apps-s-1vcpu-1gb"
}

variable "web_http_port" {
  type    = number
  default = 3000
}

variable "worker_name" {
  type    = string
  default = "job"
}

variable "worker_instance_size_slug" {
  type    = string
  default = "apps-s-1vcpu-1gb"
}

variable "frontend_app_name" {
  type    = string
  default = "terraform-v2-web-app"
}

variable "frontend_github_repo" {
  description = "GitHub repository in owner/repository format for frontend components."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.frontend_github_repo))
    error_message = "frontend_github_repo must use owner/repository format."
  }
}

variable "frontend_github_branch" {
  type    = string
  default = "main"
}

variable "frontend_deploy_on_push" {
  type    = bool
  default = false
}

variable "frontend_source_dir" {
  type    = string
  default = "/"
}

variable "frontend_web_instance_size_slug" {
  type    = string
  default = "apps-s-1vcpu-1gb"
}

variable "frontend_http_port" {
  type    = number
  default = 8080
}

variable "frontend_build_command" {
  type    = string
  default = "npm ci && npm run build"
}

variable "frontend_output_dir" {
  type    = string
  default = "dist/client"
}

variable "frontend_run_command" {
  type    = string
  default = "npm run preview -- --host 0.0.0.0 --port 8080"
}

variable "postgres_name" {
  type = string
}

variable "postgres_database_name" {
  type    = string
  default = "app_production"
}

variable "postgres_region" {
  type    = string
  default = "nyc3"
}

variable "postgres_version" {
  type    = string
  default = "18"
}

variable "postgres_size" {
  type    = string
  default = "db-s-1vcpu-1gb"
}

variable "postgres_node_count" {
  type    = number
  default = 1
}

variable "opensearch_name" {
  type = string
}

variable "opensearch_region" {
  type    = string
  default = "nyc3"
}

variable "opensearch_version" {
  type    = string
  default = "2.19"
}

variable "opensearch_size" {
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
  type    = string
  default = "digitalocean_spaces"
}

variable "spaces_region" {
  type    = string
  default = "nyc3"
}

variable "spaces_bucket_name" {
  type    = string
  default = ""
}

variable "manage_spaces_bucket" {
  type    = bool
  default = true
}

variable "spaces_provider_access_key_id" {
  type      = string
  default   = null
  sensitive = true
}

variable "spaces_provider_secret_access_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "app_spaces_access_key_id" {
  type      = string
  default   = null
  sensitive = true
}

variable "app_spaces_secret_access_key" {
  type      = string
  default   = null
  sensitive = true
}
