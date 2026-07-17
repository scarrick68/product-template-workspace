resource "digitalocean_project" "project" {
  name        = var.project_name
  description = var.project_description

  purpose     = "Web Application"
  environment = "Production"
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
      db_user      = digitalocean_database_user.rails.name
    }

    database {
      name         = "opensearch"
      engine       = "OPENSEARCH"
      production   = true
      cluster_name = digitalocean_database_cluster.opensearch.name
    }

    env {
      key   = "DATABASE_URL"
      value = "$${postgres.DATABASE_URL}"
      scope = "RUN_TIME"
      type  = "SECRET"
    }

    env {
      key   = "OPENSEARCH_URL"
      value = "$${opensearch.DATABASE_URL}"
      scope = "RUN_TIME"
      type  = "SECRET"
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

    service {
      name               = "web"
      instance_count     = 1
      instance_size_slug = var.web_instance_size_slug
      http_port          = var.web_http_port

      image {
        registry_type = "DOCKER_HUB"
        registry      = var.app_image_registry
        repository    = var.app_image_repository
        tag           = var.app_image_tag
      }
    }

    worker {
      name               = var.worker_name
      instance_count     = 1
      instance_size_slug = var.worker_instance_size_slug

      image {
        registry_type = "DOCKER_HUB"
        registry      = var.app_image_registry
        repository    = var.app_image_repository
        tag           = var.app_image_tag
      }

      run_command = var.worker_run_command
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
