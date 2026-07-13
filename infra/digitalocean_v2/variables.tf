variable "project_name" {
  type = string
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

variable "app_image_registry" {
  type    = string
  default = "library"
}

variable "app_image_repository" {
  type    = string
  default = "nginx"
}

variable "app_image_tag" {
  type    = string
  default = "latest"
}

variable "web_instance_size_slug" {
  type    = string
  default = "apps-s-1vcpu-1gb"
}

variable "worker_name" {
  type    = string
  default = "job"
}

variable "worker_instance_size_slug" {
  type    = string
  default = "apps-s-1vcpu-1gb"
}

variable "worker_run_command" {
  type    = string
  default = "bundle exec sidekiq"
}

variable "frontend_app_name" {
  type    = string
  default = "terraform-v2-web-app"
}

variable "frontend_repo" {
  type    = string
  default = "scarrick68/web-template"
}

variable "frontend_branch" {
  type    = string
  default = "main"
}

variable "frontend_web_instance_size_slug" {
  type    = string
  default = "apps-s-1vcpu-1gb"
}

variable "frontend_http_port" {
  type    = number
  default = 3000
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
  default = "npm run start"
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
