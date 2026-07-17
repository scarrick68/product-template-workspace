resource "digitalocean_app" "frontend" {
  spec {
    name   = var.frontend_app_name
    region = var.app_region

    service {
      name               = "web"
      instance_count     = 1
      instance_size_slug = var.frontend_web_instance_size_slug
      http_port          = 80

      env {
        key   = "API_BASE_URL"
        value = digitalocean_app.rails.live_url
        scope = "BUILD_TIME"
        type  = "GENERAL"
      }

      image {
        registry_type = "DOCKER_HUB"
        registry      = "library"
        repository    = "nginx"
        tag           = "alpine"
      }
    }
  }
}