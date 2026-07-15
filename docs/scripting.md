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

## CLI Directory Purposes

The workspace CLI now follows a layered structure so user-facing command contracts stay stable while implementation details evolve.

- `bin/`: Shell-visible entrypoints.
- `bin/workspace`: canonical executable for all user-facing commands.
- `bin/<legacy-script>`: compatibility wrappers that delegate into `bin/workspace` command groups.
- `lib/workspace/cli.rb`: top-level command router (`new-project`, `credentials`, `repository`, `infra`).
- `lib/workspace/commands/`: CLI command and subcommand dispatchers. This is the public command layer.
- `lib/workspace/commands/<group>/`: grouped subcommands (for example infra, repository, credentials actions).
- `lib/workspace/services/`: internal application services used by commands; not intended as shell contracts.
- `lib/workspace/services/<domain>/`: deeper domain implementations (for example infra/auth/local env setup installers).
- `lib/workspace/context.rb`: workspace-root context object used by commands/services to run against the correct workspace instance.
- `lib/workspace.rb`: shared runtime helpers (output, command execution, config/repository discovery).
- `test/lib/workspace/commands/`: tests for command dispatch and command-level behavior.
- `test/lib/workspace/`: tests for lower-level support modules and non-command behavior.

### Boundary Rule

- `Workspace::Commands::*`: user-discoverable CLI operations.
- `Workspace::Services::*`: internal implementation invoked by commands.

In practice, new shell features should be introduced by adding/updating command classes under `lib/workspace/commands/` and then delegating to one or more services under `lib/workspace/services/`.

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

- `bin/workspace new-project`: copy-first project generation entrypoint. Creates destination workspace copy, then runs project initialization in the copied workspace context.
- `bin/workspace repository setup`: guided onboarding workflow run inside a project workspace; orchestrates setup checks, bootstrap, rename, validation, and optional dev launch.
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
- `bin/workspace repository rename`: perform template rename orchestration only.
- `bin/workspace repository verify`: run post-rename validation checks and checklist.
- `bin/workspace infra <doctor|configure|plan|apply>`: infrastructure workflows for DigitalOcean Terraform/OpenTofu provisioning. See `../infra/digitalocean/README.md` for launch flow details.

Compatibility wrappers (`bin/infra`, `bin/new_project`, `bin/init_new_project`, `bin/rename_product`, `bin/validate_product`) remain available but should be treated as transitional shortcuts.

## Notes

These scripts are coordination utilities, not replacements for template-level setup and runtime documentation.
