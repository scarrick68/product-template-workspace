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

  managed_spaces_bucket = try(module.spaces[0].bucket_name, null)
  managed_s3_endpoint = try(module.spaces[0].s3_endpoint, null)
  managed_aws_access_key_id = try(module.spaces[0].access_key_id, null)
  managed_aws_secret_access_key = try(module.spaces[0].secret_access_key, null)

  effective_active_storage_service = (
    local.component_flags.spaces
    ? coalesce(var.active_storage_service, "amazon")
    : var.active_storage_service
  )
  effective_data_artifact_bucket = (
    local.component_flags.spaces
    ? coalesce(local.managed_spaces_bucket, var.data_artifact_bucket)
    : var.data_artifact_bucket
  )
  effective_s3_endpoint = (
    local.component_flags.spaces
    ? coalesce(local.managed_s3_endpoint, var.s3_endpoint)
    : var.s3_endpoint
  )
  effective_aws_access_key_id = (
    local.component_flags.spaces
    ? coalesce(local.managed_aws_access_key_id, var.aws_access_key_id)
    : var.aws_access_key_id
  )
  effective_aws_secret_access_key = (
    local.component_flags.spaces
    ? coalesce(local.managed_aws_secret_access_key, var.aws_secret_access_key)
    : var.aws_secret_access_key
  )
}
