locals {
  component_flags = {
    postgres   = var.enable_postgres
    opensearch = var.enable_opensearch
    spaces     = var.enable_spaces
  }
}

# Component resources are intentionally added in later PRs.
