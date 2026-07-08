terraform {
	required_providers {
		digitalocean = {
			source  = "digitalocean/digitalocean"
			version = "~> 2.0"
		}
	}
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

variable "enable_api" {
	type = bool
}

variable "enable_worker" {
	type = bool
}

variable "enable_web" {
	type = bool
}

variable "api_instance_size_slug" {
	type = string
}

variable "worker_instance_size_slug" {
	type = string
}

variable "web_instance_size_slug" {
	type = string
}

variable "api_run_command" {
	type = string
}

variable "worker_run_command" {
	type = string
}

variable "migrate_run_command" {
	type = string
}

variable "web_build_command" {
	type = string
}

variable "web_output_dir" {
	type = string
}

variable "rails_master_key" {
	type      = string
	sensitive = true
}

variable "cors_allowed_origins" {
	type = string
}

variable "vite_api_base_url" {
	type = string
}

variable "database_url" {
	type = string
}

variable "opensearch_url" {
	type = string
}

variable "active_storage_service" {
	type = string
}

variable "data_artifact_bucket" {
	type = string
}

variable "s3_endpoint" {
	type = string
}

variable "aws_access_key_id" {
	type      = string
	sensitive = true
}

variable "aws_secret_access_key" {
	type      = string
	sensitive = true
}

locals {
	app_spec_name = "${var.app_name}-${var.environment}"

	secret_env_keys = toset([
		"DATABASE_URL",
		"OPENSEARCH_URL",
		"AWS_ACCESS_KEY_ID",
		"AWS_SECRET_ACCESS_KEY"
	])

	optional_api_env = {
		CORS_ALLOWED_ORIGINS   = var.cors_allowed_origins
		DATABASE_URL           = var.database_url
		OPENSEARCH_URL         = var.opensearch_url
		ACTIVE_STORAGE_SERVICE = var.active_storage_service
		DATA_ARTIFACT_BUCKET   = var.data_artifact_bucket
		S3_ENDPOINT            = var.s3_endpoint
		AWS_ACCESS_KEY_ID      = var.aws_access_key_id
		AWS_SECRET_ACCESS_KEY  = var.aws_secret_access_key
	}

	filtered_optional_api_env = {
		for key, value in local.optional_api_env : key => value
		if value != null && value != ""
	}

	web_api_base_url = (
		var.vite_api_base_url != null && var.vite_api_base_url != ""
		? var.vite_api_base_url
		: null
	)
}

resource "digitalocean_app" "this" {
	spec {
		name   = local.app_spec_name
		region = var.region

		dynamic "service" {
			for_each = var.enable_api ? [1] : []

			content {
				name               = "api"
				instance_size_slug = var.api_instance_size_slug
				instance_count     = 1
				http_port          = 3000
				source_dir         = "/"
				run_command        = var.api_run_command

				github {
					repo           = "${var.github_owner}/${var.api_repo}"
					branch         = var.branch
					deploy_on_push = true
				}

				env {
					key   = "RAILS_ENV"
					value = "production"
					scope = "RUN_TIME"
				}

				env {
					key   = "RAILS_MASTER_KEY"
					value = var.rails_master_key
					scope = "RUN_TIME"
					type  = "SECRET"
				}

				dynamic "env" {
					for_each = local.filtered_optional_api_env

					content {
						key   = env.key
						value = env.value
						scope = "RUN_TIME"
								type  = contains(local.secret_env_keys, env.key) ? "SECRET" : "GENERAL"
					}
				}
			}
		}

		dynamic "service" {
			for_each = var.enable_worker ? [1] : []

			content {
				name               = "worker"
				instance_size_slug = var.worker_instance_size_slug
				instance_count     = 1
				source_dir         = "/"
				run_command        = var.worker_run_command

				github {
					repo           = "${var.github_owner}/${var.api_repo}"
					branch         = var.branch
					deploy_on_push = true
				}

				env {
					key   = "RAILS_ENV"
					value = "production"
					scope = "RUN_TIME"
				}

				env {
					key   = "RAILS_MASTER_KEY"
					value = var.rails_master_key
					scope = "RUN_TIME"
					type  = "SECRET"
				}

				env {
					key   = "GOOD_JOB_EXECUTION_MODE"
					value = "async_server"
					scope = "RUN_TIME"
				}

				dynamic "env" {
					for_each = local.filtered_optional_api_env

					content {
						key   = env.key
						value = env.value
						scope = "RUN_TIME"
							type  = contains(local.secret_env_keys, env.key) ? "SECRET" : "GENERAL"
					}
				}
			}
		}

		dynamic "job" {
			for_each = var.enable_api ? [1] : []

			content {
				name               = "migrate"
				kind               = "PRE_DEPLOY"
				instance_size_slug = var.api_instance_size_slug
				instance_count     = 1
				source_dir         = "/"
				run_command        = var.migrate_run_command

				github {
					repo           = "${var.github_owner}/${var.api_repo}"
					branch         = var.branch
					deploy_on_push = true
				}

				env {
					key   = "RAILS_ENV"
					value = "production"
					scope = "RUN_TIME"
				}

				env {
					key   = "RAILS_MASTER_KEY"
					value = var.rails_master_key
					scope = "RUN_TIME"
					type  = "SECRET"
				}

				dynamic "env" {
					for_each = local.filtered_optional_api_env

					content {
						key   = env.key
						value = env.value
						scope = "RUN_TIME"
							type  = contains(local.secret_env_keys, env.key) ? "SECRET" : "GENERAL"
					}
				}
			}
		}

		dynamic "static_site" {
			for_each = var.enable_web ? [1] : []

			content {
				name               = "web"
				source_dir         = "/"
				build_command      = var.web_build_command
				output_dir         = var.web_output_dir

				github {
					repo           = "${var.github_owner}/${var.web_repo}"
					branch         = var.branch
					deploy_on_push = true
				}

				dynamic "env" {
					for_each = local.web_api_base_url == null ? {} : { VITE_API_BASE_URL = local.web_api_base_url }

					content {
						key   = env.key
						value = env.value
						scope = "BUILD_TIME"
					}
				}
			}
		}
	}
}

output "app_id" {
	value = digitalocean_app.this.id
}

output "app_live_url" {
	value = digitalocean_app.this.live_url
}

output "app_urn" {
	value = digitalocean_app.this.urn
}
