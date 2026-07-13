resource "digitalocean_database_cluster" "opensearch" {
  name       = var.opensearch_name
  engine     = "opensearch"
  version    = var.opensearch_version
  size       = var.opensearch_size
  region     = var.opensearch_region
  node_count = var.opensearch_node_count
  project_id = digitalocean_project.project.id
}
