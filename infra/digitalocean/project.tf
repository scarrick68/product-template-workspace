locals {
	project_environment_value = lower(var.project_environment)
	project_environment = (
		local.project_environment_value == "development"
		? "Development"
		: local.project_environment_value == "staging"
		? "Staging"
		: "Production"
	)

	project_resource_urns = compact([
		module.app_platform.app_urn,
		try(module.postgres[0].cluster_urn, null),
		try(module.opensearch[0].cluster_urn, null),
		try(module.spaces[0].bucket_urn, null)
	])
}

resource "digitalocean_project" "this" {
	name        = var.project_name
	description = "Resources for ${var.project_name}"
	purpose     = var.project_purpose
	environment = local.project_environment
}

resource "digitalocean_project_resources" "this" {
	project   = digitalocean_project.this.id
	resources = local.project_resource_urns
}