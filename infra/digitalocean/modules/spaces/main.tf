variable "app_name" {
	type = string
}

variable "environment" {
	type = string
}

variable "do_region" {
	type = string
}

variable "spaces_provider" {
	type = string
}

variable "spaces_create_bucket" {
	type = bool
}

variable "spaces_create_key" {
	type = bool
}

variable "spaces_force_destroy" {
	type = bool
}

variable "data_artifact_bucket" {
	type = string
}

variable "s3_endpoint" {
	type = string
}

variable "aws_access_key_id" {
	type      = string
	sensitive = true
}

variable "aws_secret_access_key" {
	type      = string
	sensitive = true
}

locals {
	managed_spaces = var.spaces_provider == "digitalocean_spaces"

	default_bucket_name = substr(
		replace(lower("${var.app_name}-${var.environment}-artifacts"), "_", "-"),
		0,
		63
	)

	bucket_name = coalesce(var.data_artifact_bucket, local.default_bucket_name)

	create_bucket = local.managed_spaces && var.spaces_create_bucket
	create_key    = local.managed_spaces && var.spaces_create_key
}

resource "digitalocean_spaces_bucket" "this" {
	count = local.create_bucket ? 1 : 0

	name          = local.bucket_name
	region        = var.do_region
	acl           = "private"
	force_destroy = var.spaces_force_destroy
}

resource "digitalocean_spaces_key" "app" {
	count = local.create_key ? 1 : 0

	name = "${local.bucket_name}-${var.environment}-app"

	grant {
		bucket     = local.bucket_name
		permission = "readwrite"
	}
}

output "bucket_name" {
	value = local.bucket_name
}

output "s3_endpoint" {
	value = local.managed_spaces ? "https://${var.do_region}.digitaloceanspaces.com" : var.s3_endpoint
}

output "access_key_id" {
	value     = local.create_key ? digitalocean_spaces_key.app[0].access_key : var.aws_access_key_id
	sensitive = true
}

output "secret_access_key" {
	value     = local.create_key ? digitalocean_spaces_key.app[0].secret_key : var.aws_secret_access_key
	sensitive = true
}
