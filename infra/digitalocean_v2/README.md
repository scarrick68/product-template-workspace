# DigitalOcean Terraform Notes

## Infra Setup and Deploy Flow

Legend:

- `[USER]` means a manual action or decision.
- `[SCRIPT: <name>]` means the step is automated by a workspace utility script.

```mermaid
flowchart TD
	A[USER: Start infra workflow] --> B[SCRIPT: Run bin/infra doctor]
	B --> C{Doctor checks pass?}
	C -- No --> D[USER: Fix missing CLI, auth, token, or repo issues]
	D --> B
	C -- Yes --> E[SCRIPT: Run bin/infra configure production]
	E --> F[USER: Review generated config/project.yml infrastructure settings]
	F --> G[USER: Review generated terraform.tfvars.json]
	G --> H[SCRIPT: Run bin/infra plan production]
	H --> I{Plan looks correct?}
	I -- No --> J[USER: Adjust config or environment variables]
	J --> E
	I -- Yes --> K[SCRIPT: Run bin/infra apply production]
	K --> L[USER: Collect outputs and verify app and dependencies]
```

## Blob Store Decision Tree

```mermaid
flowchart TD
	A[USER: Enable blob storage?] --> B{enable_spaces}
	B -- No --> C[SCRIPT: Skip Spaces and S3 env wiring]
	B -- Yes --> D{spaces_provider}
	D -- digitalocean_spaces --> E[SCRIPT: Provision managed Spaces bucket]
	E --> F[SCRIPT: Optionally create Spaces access key]
	F --> G[SCRIPT: Inject bucket, endpoint, and credentials into app env]
	D -- aws_s3 --> H[USER: Provide external AWS S3 bucket and creds]
	H --> I[SCRIPT: Check AWS CLI and auth in bin/infra doctor]
	I --> G
	G --> J[SCRIPT: App uses ActiveStorage amazon service]
```

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

## Spaces and S3 behavior

- Blob storage support is enabled by default (`enable_spaces = true`).
- `spaces_provider = "digitalocean_spaces"` provisions a Spaces bucket and Spaces access key by default.
- Provide application Spaces creds with Terraform vars `app_spaces_access_key_id` and `app_spaces_secret_access_key`.
- When Terraform manages a Spaces bucket (`manage_spaces_bucket = true`), also provide provider creds with `spaces_provider_access_key_id` and `spaces_provider_secret_access_key`.
- If you prefer environment variables instead of tfvars files, use Terraform variable env names: `TF_VAR_app_spaces_access_key_id`, `TF_VAR_app_spaces_secret_access_key`, `TF_VAR_spaces_provider_access_key_id`, and `TF_VAR_spaces_provider_secret_access_key`.
- `spaces_provider = "aws_s3"` skips provisioning and uses provided values:
	- `data_artifact_bucket`
	- `aws_access_key_id`
	- `aws_secret_access_key`
	- optional `s3_endpoint` (typically not needed for AWS S3)
- App Platform receives these env vars when present:
	- `ACTIVE_STORAGE_SERVICE` (defaults to `amazon` when spaces are enabled)
	- `DATA_ARTIFACT_BUCKET`
	- `S3_ENDPOINT`
	- `AWS_ACCESS_KEY_ID`
	- `AWS_SECRET_ACCESS_KEY`

## Infra CLI

- `bin/workspace infra doctor`
	- Checks terraform/tofu, doctl, gh, git, DO token, doctl auth, gh auth, and expected repos.
- `bin/workspace infra configure production`
	- Prompts for core app/infra values.
	- Updates `config/project.yml` environment infrastructure and writes `infra/digitalocean_v2/terraform.tfvars.json`.
- `bin/workspace infra plan production` and `bin/workspace infra apply production`
	- Run terraform init then selected action using generated tfvars.

## Launch Guide

Recommended production flow:

1. `bin/workspace infra doctor` (checks required CLIs, auth state, token presence, expected repos, and blob-store readiness prerequisites)
2. `bin/workspace infra configure production` (guides config prompts and writes project manifest infrastructure plus `terraform.tfvars.json`)
3. `bin/workspace infra plan production` (runs terraform init and previews infrastructure changes before apply)
4. `bin/workspace infra apply production` (runs terraform init/apply to provision and wire configured infrastructure resources)

Example command sequence:

```bash
bin/workspace infra doctor
bin/workspace infra configure production
bin/workspace infra plan production
bin/workspace infra apply production
```

- The current `bin/workspace infra` command set supports `doctor`, `configure`, `plan`, and `apply`.
- A dedicated `bin/workspace infra deploy production` command is not implemented yet.
- For now, treat `apply` as the launch/provision step, then use your App Platform deploy flow (auto-deploy from configured repo branch or `doctl apps update --update-sources`) as needed.

## Security guidance

- Terraform state may contain secrets. Use remote encrypted state before production rollout.
- Never commit `.terraform/`, `terraform.tfstate*`, or `terraform.tfvars*` files.
- Keep `DIGITALOCEAN_ACCESS_TOKEN` outside repo files (shell env, direnv, or secret manager).
- Restrict access to Terraform state and rotate credentials if exposed.
