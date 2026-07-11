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

    service {
      name               = "web"
      instance_count     = 1
      instance_size_slug = var.web_instance_size_slug
      http_port          = 80

      image {
        registry_type = "DOCKER_HUB"
        registry      = var.app_image_registry
        repository    = var.app_image_repository
        tag           = var.app_image_tag
      }
    }

    worker {
      name               = "job"
      instance_count     = 1
      instance_size_slug = var.worker_instance_size_slug

      image {
        registry_type = "DOCKER_HUB"
        registry      = "library"
        repository    = "alpine"
        tag           = "3.20"
      }

      run_command = "sh -c 'while true; do sleep 3600; done'"
    }
  }
}

resource "digitalocean_project_resources" "project_assignment" {
  project = digitalocean_project.project.id
  resources = [
    digitalocean_app.rails.urn,
    digitalocean_app.frontend.urn
  ]
}
