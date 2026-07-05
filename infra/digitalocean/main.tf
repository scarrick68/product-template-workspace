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
}

# Component resources are intentionally added in later PRs.
