resource "digitalocean_database_cluster" "postgres" {
  name       = var.postgres_name
  engine     = "pg"
  version    = var.postgres_version
  size       = var.postgres_size
  region     = var.postgres_region
  node_count = var.postgres_node_count
  project_id = digitalocean_project.project.id
}

resource "digitalocean_database_db" "rails" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = var.postgres_database_name
}

resource "digitalocean_database_user" "rails" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = var.postgres_user_name
}
