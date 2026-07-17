locals {
  managed_spaces_enabled = (
    var.enable_spaces &&
    var.spaces_provider == "digitalocean_spaces"
  )

  normalized_spaces_bucket_name = (
    trimspace(var.spaces_bucket_name) != ""
    ? trimspace(var.spaces_bucket_name)
    : "${var.project_name}-artifacts"
  )
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