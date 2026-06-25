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

## Essential Commands

- `bin/preinstall`: verify Ruby compatibility, GitHub CLI installation, and GitHub CLI auth state.
- `bin/bootstrap`: validate repo presence, install dependencies, and prepare DB where applicable.
- `bin/doctor`: verify local toolchain, auth, Docker daemon status, and configured ports.
- `bin/status`: summarize branch and dirty state for each repository.
- `bin/pull`: run fast-forward pulls across all repositories.
- `bin/sync-openapi`: sync API OpenAPI contract to shared destinations.
- `bin/dev`: run primary local services for active development.
- `bin/start-day`: execute daily coordination workflow.
- `bin/init_new_project`: run guided first-time setup (environment prechecks, bootstrap, rename, validation, optional dev launch).

## Notes

These scripts are coordination utilities, not replacements for template-level setup and runtime documentation.
