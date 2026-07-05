variable "app_name" {
	type = string
}

variable "environment" {
	type = string
}

variable "do_region" {
	type = string
}

variable "postgres_version" {
	type = string
}

variable "postgres_size_slug" {
	type = string
}

variable "postgres_node_count" {
	type = number
}

variable "postgres_db_name" {
	type = string
}

variable "postgres_user_name" {
	type = string
}

resource "digitalocean_database_cluster" "this" {
	name       = "${var.app_name}-${var.environment}-pg"
	engine     = "pg"
	version    = var.postgres_version
	size       = var.postgres_size_slug
	region     = var.do_region
	node_count = var.postgres_node_count
}

resource "digitalocean_database_db" "app" {
	cluster_id = digitalocean_database_cluster.this.id
	name       = var.postgres_db_name
}

resource "digitalocean_database_user" "app" {
	cluster_id = digitalocean_database_cluster.this.id
	name       = var.postgres_user_name
}

locals {
	database_url = format(
		"postgresql://%s:%s@%s:%s/%s?sslmode=require",
		digitalocean_database_user.app.name,
		urlencode(digitalocean_database_user.app.password),
		digitalocean_database_cluster.this.host,
		digitalocean_database_cluster.this.port,
		digitalocean_database_db.app.name
	)
}

output "cluster_id" {
	value = digitalocean_database_cluster.this.id
}

output "database_url" {
	value     = local.database_url
	sensitive = true
}
