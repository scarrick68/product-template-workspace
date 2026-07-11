resource "digitalocean_project" "project" {
  name        = var.project_name
  description = var.project_description

  purpose     = "Web Application"
  environment = "Production"
}
