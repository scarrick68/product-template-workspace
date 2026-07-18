resource "digitalocean_app" "frontend" {
  spec {
    name   = var.frontend_app_name
    region = var.app_region

    static_site {
      name             = "web"
      source_dir       = var.frontend_source_dir
      build_command    = var.frontend_build_command
      output_dir       = var.frontend_output_dir
      environment_slug = "node-js"

      env {
        key   = "VITE_API_BASE_URL"
        value = digitalocean_app.rails.live_url
        scope = "BUILD_TIME"
        type  = "GENERAL"
      }

      github {
        repo           = var.frontend_github_repo
        branch         = var.frontend_github_branch
        deploy_on_push = var.frontend_deploy_on_push
      }
    }
  }
}