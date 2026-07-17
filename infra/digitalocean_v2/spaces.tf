locals {
  spaces_enabled = (
    var.enable_spaces &&
    var.spaces_provider == "digitalocean_spaces"
  )

  managed_spaces_enabled = (
    local.spaces_enabled &&
    var.manage_spaces_bucket
  )

  normalized_spaces_bucket_name = (
    trimspace(var.spaces_bucket_name) != ""
    ? trimspace(var.spaces_bucket_name)
    : "${var.project_name}-artifacts"
  )

  effective_spaces_bucket_name = (
    local.managed_spaces_enabled
    ? digitalocean_spaces_bucket.artifacts[0].name
    : local.normalized_spaces_bucket_name
  )

  effective_app_spaces_access_key_id = trimspace(
    coalesce(var.app_spaces_access_key_id, "")
  )

  effective_app_spaces_secret_access_key = trimspace(
    coalesce(var.app_spaces_secret_access_key, "")
  )

  effective_provider_spaces_access_key_id = trimspace(
    coalesce(var.spaces_provider_access_key_id, "")
  )

  effective_provider_spaces_secret_access_key = trimspace(
    coalesce(var.spaces_provider_secret_access_key, "")
  )

  spaces_general_env = local.spaces_enabled ? {
    SPACES_BUCKET   = local.effective_spaces_bucket_name
    SPACES_REGION   = var.spaces_region
    SPACES_ENDPOINT = "https://${var.spaces_region}.digitaloceanspaces.com"
  } : {}

  spaces_secret_env = local.spaces_enabled ? {
    SPACES_ACCESS_KEY_ID     = local.effective_app_spaces_access_key_id
    SPACES_SECRET_ACCESS_KEY = local.effective_app_spaces_secret_access_key
  } : {}
}

check "spaces_application_credentials" {
  assert {
    condition = (
      !local.spaces_enabled ||
      (
        local.effective_app_spaces_access_key_id != "" &&
        local.effective_app_spaces_secret_access_key != ""
      )
    )

    error_message = "Spaces access key ID and secret access key must both be set when Spaces is enabled."
  }
}

check "spaces_provider_credentials" {
  assert {
    condition = (
      !local.managed_spaces_enabled ||
      (
        local.effective_provider_spaces_access_key_id != "" &&
        local.effective_provider_spaces_secret_access_key != ""
      )
    )

    error_message = "Spaces provider access key ID and secret access key must both be set when Terraform manages a Spaces bucket."
  }
}

resource "digitalocean_spaces_bucket" "artifacts" {
  count = local.managed_spaces_enabled ? 1 : 0

  name   = local.normalized_spaces_bucket_name
  region = var.spaces_region
  acl    = "private"

  versioning {
    enabled = true
  }
}