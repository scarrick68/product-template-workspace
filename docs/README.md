# Workspace Documentation

This directory contains workspace-level documentation for cross-repository architecture, workflows, and shared conventions.

Use these docs when working on interactions between templates, contracts, and shared tooling.

## Key Workflow Entry Points

Use this section as the primary index when you are trying to get work done quickly.

- First-time product bootstrap and remote setup:
	- Start at `getting-started.md`
- Infrastructure provisioning and production launch prep:
	- Start at `../infra/digitalocean/README.md`
- Day-to-day local development loop:
	- Start at `local-development.md`
- Script inventory and command responsibilities:
	- Start at `scripting.md`
	- See `scripting.md#cli-directory-purposes` for command/service directory boundaries.
- OpenAPI contract synchronization across repos:
	- Start at `openapi-workflow.md`
- Cross-repository testing expectations:
	- Start at `testing-strategy.md`
- Architecture boundaries and ownership model:
	- Start at `architecture.md`
- Cross-repo conventions and change-management rules:
	- Start at `repository-conventions.md`

## Documents

- `getting-started.md`: Concise first-run workflow for project bootstrap, rename, validation, and remote setup.
- `architecture.md`: High-level architecture and repository boundaries.
- `repository-conventions.md`: Rules for ownership, versioning, and coordination.
- `local-development.md`: Local setup and orchestration guidance.
- `openapi-workflow.md`: Contract and OpenAPI synchronization workflow.
- `testing-strategy.md`: Cross-repository test strategy and scope.
- `scripting.md`: Ruby-first scripting design and command catalog.
- `adr/0001-ruby-first-workspace-scripting.md`: Decision record for scripting language choice.
- `../repos/api-template/docs/template-features.md`: API template feature list.
- `../repos/api-template/docs/data-import-pipeline.md`: API template data import pipeline feature details.

## Rule of Thumb

- Workspace docs explain interaction between repositories.
- Template docs explain implementation within a repository.
