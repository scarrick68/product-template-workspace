resource "digitalocean_project" "project" {
  name        = var.project_name
  description = var.project_description

  purpose     = "Web Application"
  environment = "Production"
}

locals {
  rails_database_url = format(
    "postgresql://%s:%s@%s:%d/%s?sslmode=require",
    digitalocean_database_cluster.postgres.user,
    urlencode(digitalocean_database_cluster.postgres.password),
    digitalocean_database_cluster.postgres.host,
    digitalocean_database_cluster.postgres.port,
    digitalocean_database_db.rails.name
  )
}

resource "digitalocean_app" "rails" {
  spec {
    name   = var.rails_app_name
    region = var.app_region

    database {
      name         = "postgres"
      engine       = "PG"
      production   = true
      cluster_name = digitalocean_database_cluster.postgres.name
      db_name      = digitalocean_database_db.rails.name
    }

    database {
      name         = "opensearch"
      engine       = "OPENSEARCH"
      production   = true
      cluster_name = digitalocean_database_cluster.opensearch.name
    }

    env {
      key   = "DATABASE_URL"
      value = local.rails_database_url
      scope = "RUN_TIME"
      type  = "SECRET"
    }

    env {
      key   = "BLAZER_DATABASE_URL"
      value = local.rails_database_url
      scope = "RUN_TIME"
      type  = "SECRET"
    }

    env {
      key   = "OPENSEARCH_URL"
      value = "$${opensearch.DATABASE_URL}"
      scope = "RUN_TIME"
      type  = "SECRET"
    }

    env {
      key   = "CORS_ALLOWED_ORIGINS"
      value = var.rails_cors_allowed_origins
      scope = "RUN_AND_BUILD_TIME"
      type  = "GENERAL"
    }

    dynamic "env" {
      for_each = local.spaces_general_env
      content {
        key   = env.key
        value = env.value
        scope = "RUN_TIME"
        type  = "GENERAL"
      }
    }

    dynamic "env" {
      for_each = local.spaces_secret_env
      content {
        key   = env.key
        value = env.value
        scope = "RUN_TIME"
        type  = "SECRET"
      }
    }

    job {
      name               = "migrate"
      kind               = "PRE_DEPLOY"
      instance_count     = 1
      instance_size_slug = var.worker_instance_size_slug
      source_dir         = var.rails_source_dir
      environment_slug   = "ruby-on-rails"
      run_command        = "bin/rails db:prepare"

      github {
        repo           = var.rails_github_repo
        branch         = var.rails_github_branch
        deploy_on_push = false
      }
    }

    service {
      name               = "api"
      instance_count     = 1
      instance_size_slug = var.web_instance_size_slug
      source_dir         = var.rails_source_dir
      environment_slug   = "ruby-on-rails"
      http_port          = var.web_http_port
      run_command        = var.rails_web_run_command

      github {
        repo           = var.rails_github_repo
        branch         = var.rails_github_branch
        deploy_on_push = var.rails_deploy_on_push
      }

      health_check {
        http_path             = "/up"
        initial_delay_seconds = 10
        period_seconds        = 10
        timeout_seconds       = 5
        success_threshold     = 1
        failure_threshold     = 3
      }
    }

    worker {
      name               = var.worker_name
      instance_count     = 1
      instance_size_slug = var.worker_instance_size_slug
      source_dir         = var.rails_source_dir
      environment_slug   = "ruby-on-rails"

      github {
        repo           = var.rails_github_repo
        branch         = var.rails_github_branch
        deploy_on_push = var.rails_deploy_on_push
      }

      run_command = var.rails_worker_run_command
    }
  }
}

resource "digitalocean_project_resources" "project_assignment" {
  project = digitalocean_project.project.id
  resources = compact([
    digitalocean_app.rails.urn,
    digitalocean_app.frontend.urn,
    digitalocean_database_cluster.postgres.urn,
    digitalocean_database_cluster.opensearch.urn,
    try(digitalocean_spaces_bucket.artifacts[0].urn, null)
  ])
}
