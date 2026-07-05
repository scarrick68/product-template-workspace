module "app_platform" {
	source = "./modules/app_platform"

	app_name     = var.app_name
	environment  = var.environment
	region       = var.region
	github_owner = var.github_owner
	api_repo     = var.api_repo
	web_repo     = var.web_repo
	branch       = var.branch

	enable_api    = var.enable_api
	enable_worker = var.enable_worker
	enable_web    = var.enable_web

	api_instance_size_slug    = var.api_instance_size_slug
	worker_instance_size_slug = var.worker_instance_size_slug
	web_instance_size_slug    = var.web_instance_size_slug

	api_run_command       = var.api_run_command
	worker_run_command    = var.worker_run_command
	migrate_run_command   = var.migrate_run_command
	web_build_command     = var.web_build_command
	web_output_dir        = var.web_output_dir
	rails_master_key      = var.rails_master_key
	cors_allowed_origins  = var.cors_allowed_origins
	vite_api_base_url     = var.vite_api_base_url
	database_url          = local.effective_database_url
	opensearch_url        = var.opensearch_url
	active_storage_service = var.active_storage_service
	data_artifact_bucket  = var.data_artifact_bucket
	s3_endpoint           = var.s3_endpoint
	aws_access_key_id     = var.aws_access_key_id
	aws_secret_access_key = var.aws_secret_access_key
}
