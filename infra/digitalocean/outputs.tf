output "app_id" {
  description = "App Platform app id (populated in PR2)."
  value       = null
}

output "app_live_url" {
  description = "App Platform live URL (populated in PR2)."
  value       = null
}

output "database_url" {
  description = "Managed Postgres connection URL (populated in PR3)."
  value       = null
  sensitive   = true
}

output "opensearch_url" {
  description = "Managed OpenSearch URL (populated in PR4)."
  value       = null
  sensitive   = true
}

output "spaces_bucket" {
  description = "Spaces bucket name (populated in PR5)."
  value       = null
}
