provider "digitalocean" {
	spaces_access_id  = local.effective_provider_spaces_access_key_id
	spaces_secret_key = local.effective_provider_spaces_secret_access_key
}
