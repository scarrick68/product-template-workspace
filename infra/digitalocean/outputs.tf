output "app_id" {
  description = "App Platform app id."
  value       = module.app_platform.app_id
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
  description = "Spaces bucket name (populated in PR5)."
  value       = null
}
