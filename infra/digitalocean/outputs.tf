output "app_id" {
  description = "App Platform app id."
  value       = module.app_platform.app_id
}

output "project_id" {
  description = "DigitalOcean Project id grouping app resources."
  value       = digitalocean_project.this.id
}

output "project_name" {
  description = "DigitalOcean Project name grouping app resources."
  value       = digitalocean_project.this.name
}

output "app_live_url" {
  description = "App Platform live URL."
  value       = module.app_platform.app_live_url
}

output "database_url" {
  description = "Database connection URL used by the app."
  value       = local.effective_database_url
  sensitive   = true
}

output "opensearch_url" {
  description = "OpenSearch connection URL used by the app."
  value       = local.effective_opensearch_url
  sensitive   = true
}

output "spaces_bucket" {
  description = "Bucket name used for ActiveStorage/artifacts."
  value       = local.effective_data_artifact_bucket
}

output "s3_endpoint" {
  description = "S3-compatible endpoint used by the app runtime."
  value       = local.effective_s3_endpoint
}

output "aws_access_key_id" {
  description = "S3 access key id used by app runtime."
  value       = local.effective_aws_access_key_id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "S3 secret access key used by app runtime."
  value       = local.effective_aws_secret_access_key
  sensitive   = true
}
