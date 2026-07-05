# DigitalOcean Terraform Notes

## Postgres behavior

- When `enable_postgres = true`, Terraform creates a managed PostgreSQL cluster, app database, and app user.
- The resulting connection URL is exposed only as a sensitive output (`database_url`).
- App Platform gets `DATABASE_URL` from managed Postgres automatically via root module wiring.

## OpenSearch behavior

- OpenSearch is optional but enabled by default (`enable_opensearch = true`).
- Default OpenSearch engine target is version `3`, which is compatible with current Searchkick releases.
- When enabled, Terraform creates a managed OpenSearch cluster and exposes its URL as a sensitive output.
- App Platform gets `OPENSEARCH_URL` from managed OpenSearch automatically when enabled.
- When disabled, the stack falls back to `opensearch_url` if one is provided explicitly.

## Security guidance

- Terraform state may contain secrets. Use remote encrypted state before production rollout.
- Never commit `.terraform/`, `terraform.tfstate*`, or `terraform.tfvars*` files.
- Keep `DIGITALOCEAN_ACCESS_TOKEN` outside repo files (shell env, direnv, or secret manager).
- Restrict access to Terraform state and rotate credentials if exposed.
