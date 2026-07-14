# Scripting Design

## Decision

Use Ruby as the default language for workspace scripts.

## Why Ruby-First

- Easier to read and maintain than dense shell scripts.
- Better control flow and error handling for multi-step workflows.
- Cleaner data handling for YAML/JSON configuration.
- Familiar tooling for contributors working in the API template.

## Rules

- Implement workspace commands as Ruby executables in `bin/`.
- Keep command implementation classes under `lib/workspace/`.
- Keep non-entrypoint tooling helpers under `tools/`.
- Add tooling dependencies to the root `Gemfile`.
- Keep scripts small and composable.
- Use shared helpers from `lib/workspace.rb`.
- Use shell commands only where they are the natural integration point.
- Keep script output concise and action-oriented.
- For failures, always include assumptions and concrete remediation steps.

## Current Tooling Gems

- `pastel`
- `tty-spinner`
- `tty-table`
- `awesome_print`

## Config-Driven Behavior

Scripts should use shared configuration where possible:

- `config/repos.yml`: known repositories and optional status.
- `config/ports.yml`: expected service port map.

Default local port map:

- API template: `5001`
- Web template: `3000`

`bin/dev` and `bin/start-day --with-dev` should honor these values so API-only and API+Web launches stay consistent.

## Script Responsibility Model

Use scripts in three categories to avoid overlap and confusion. These are only high level overviews of script responsibilities. See the files themselves for the details of each script.

### Aggregate Getting-Started Scripts

- `bin/new_project`: copy-first project generation entrypoint. Creates destination workspace copy, then delegates app / project installation to `init_new_project` in the copied workspace.
- `bin/init_new_project`: guided onboarding workflow run inside a project workspace; orchestrates setup checks, bootstrap, rename, validation, and optional dev launch.
- `bin/start-day`: daily orchestration workflow for already-initialized workspaces. Pull updates, check status, launch dev services, and run any other daily coordination tasks needed to start dev work.

### Development Scripts

- `bin/dev`: run primary local development services.
- `bin/status`: summarize branch and dirty state for each repository.
- `bin/pull`: run fast-forward pulls across all repositories.
- `bin/sync-openapi`: sync API OpenAPI contract to shared destinations.

### Single-Responsibility Utility Scripts

- `bin/install_local_dev_tools`: install/configure required local tools and software such as Homebrew, Ruby, GitHub CLI as well as others.
- `bin/preinstall`: verify Ruby compatibility and GitHub CLI readiness.
- `bin/doctor`: verify local toolchain, auth, Docker daemon status, and configured ports.
- `bin/bootstrap`: validate repo presence and install dependencies.
- `bin/github_auth_doctor`: verify credentials and permissions for GitHub repo workflows.
- `bin/new_product`: perform template rename orchestration only.
- `bin/validate_product`: run post-rename validation checks and checklist.
- `bin/infra`: run infrastructure workflows (`doctor`, `configure`, `plan`, `apply`) for DigitalOcean Terraform/OpenTofu provisioning. See `../infra/digitalocean/README.md` for launch flow details.

## Notes

These scripts are coordination utilities, not replacements for template-level setup and runtime documentation.
