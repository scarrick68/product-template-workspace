module "opensearch" {
	count  = var.enable_opensearch ? 1 : 0
	source = "./modules/opensearch"

	app_name             = var.app_name
	environment          = var.environment
	do_region            = var.do_region
	opensearch_version   = var.opensearch_version
	opensearch_size_slug = var.opensearch_size_slug
	opensearch_node_count = var.opensearch_node_count
}
