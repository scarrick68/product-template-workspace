module "spaces" {
	count  = var.enable_spaces ? 1 : 0
	source = "./modules/spaces"

	app_name              = var.app_name
	environment           = var.environment
	do_region             = var.do_region
	spaces_provider       = var.spaces_provider
	spaces_create_bucket  = var.spaces_create_bucket
	spaces_create_key     = var.spaces_create_key
	spaces_force_destroy  = var.spaces_force_destroy
	data_artifact_bucket  = var.data_artifact_bucket
	s3_endpoint           = var.s3_endpoint
	aws_access_key_id     = var.aws_access_key_id
	aws_secret_access_key = var.aws_secret_access_key
}
