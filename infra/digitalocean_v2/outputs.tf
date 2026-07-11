output "project_id" {
  value = digitalocean_project.project.id
}

output "project_name" {
  value = digitalocean_project.project.name
}

output "rails_app_id" {
  value = digitalocean_app.rails.id
}

output "rails_app_urn" {
  value = digitalocean_app.rails.urn
}

output "frontend_app_id" {
  value = digitalocean_app.frontend.id
}

output "frontend_app_urn" {
  value = digitalocean_app.frontend.urn
}

output "frontend_live_url" {
  value = digitalocean_app.frontend.live_url
}

output "postgres_cluster_id" {
  value = digitalocean_database_cluster.postgres.id
}

output "postgres_cluster_name" {
  value = digitalocean_database_cluster.postgres.name
}

output "postgres_host" {
  value = digitalocean_database_cluster.postgres.host
}

output "postgres_port" {
  value = digitalocean_database_cluster.postgres.port
}

output "postgres_database_name" {
  value = digitalocean_database_db.rails.name
}