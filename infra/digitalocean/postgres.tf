module "postgres" {
	count  = var.enable_postgres ? 1 : 0
	source = "./modules/postgres"

	app_name           = var.app_name
	environment        = var.environment
	do_region          = var.do_region
	postgres_version   = var.postgres_version
	postgres_size_slug = var.postgres_size_slug
	postgres_node_count = var.postgres_node_count
	postgres_db_name   = var.postgres_db_name
	postgres_user_name = var.postgres_user_name
}
