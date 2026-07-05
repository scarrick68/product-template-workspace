variable "app_name" {
	type = string
}

variable "environment" {
	type = string
}

variable "do_region" {
	type = string
}

variable "opensearch_version" {
	type = string
}

variable "opensearch_size_slug" {
	type = string
}

variable "opensearch_node_count" {
	type = number
}

resource "digitalocean_database_cluster" "this" {
	name       = "${var.app_name}-${var.environment}-opensearch"
	engine     = "opensearch"
	version    = var.opensearch_version
	size       = var.opensearch_size_slug
	region     = var.do_region
	node_count = var.opensearch_node_count
}

output "cluster_id" {
	value = digitalocean_database_cluster.this.id
}

output "opensearch_url" {
	value     = digitalocean_database_cluster.this.uri
	sensitive = true
}
