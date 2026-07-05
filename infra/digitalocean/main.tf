locals {
  component_flags = {
    postgres   = var.enable_postgres
    opensearch = var.enable_opensearch
    spaces     = var.enable_spaces
  }

  managed_database_url = try(module.postgres[0].database_url, null)
  effective_database_url = (
    local.component_flags.postgres
    ? local.managed_database_url
    : var.database_url
  )

  managed_opensearch_url = try(module.opensearch[0].opensearch_url, null)
  effective_opensearch_url = (
    local.component_flags.opensearch
    ? local.managed_opensearch_url
    : var.opensearch_url
  )
}

# Component resources are intentionally added in later PRs.
