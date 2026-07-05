# DigitalOcean Terraform Notes

## PR3 Postgres behavior

- When `enable_postgres = true`, Terraform creates a managed PostgreSQL cluster, app database, and app user.
- The resulting connection URL is exposed only as a sensitive output (`database_url`).
- App Platform gets `DATABASE_URL` from managed Postgres automatically via root module wiring.

## Security guidance

- Terraform state may contain secrets. Use remote encrypted state before production rollout.
- Never commit `.terraform/`, `terraform.tfstate*`, or `terraform.tfvars*` files.
- Keep `DIGITALOCEAN_ACCESS_TOKEN` outside repo files (shell env, direnv, or secret manager).
- Restrict access to Terraform state and rotate credentials if exposed.
