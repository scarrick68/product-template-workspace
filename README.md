# Product Template Workspace

The Product Template Workspace is the coordination layer for the product template ecosystem. It provides shared tooling, contracts, cross-repository workflows, and architecture documentation across independent template repositories.

This repository does not own product application code. Application logic remains in each template repository under `repos/`.

## Purpose

The workspace exists to solve concerns that cross repository boundaries:

- API contract management
- OpenAPI synchronization
- Cross-repository integration testing
- Local development orchestration
- Shared architecture and workflow documentation
- Bootstrap and developer tooling
- Environment and configuration conventions

## What This Repository Owns

- Shared developer tooling
- Local development and helper scripts
- Contract synchronization workflows
- Cross-repository smoke/integration checks
- Architecture and workflow documentation
- Repository coordination conventions

## What This Repository Does Not Own

- Product business logic
- Template-specific database design
- Frontend implementation details
- Mobile implementation details
- Deployment internals for each template

## Workspace Structure

```text
product-template-workspace/
├── Gemfile            # Workspace Ruby tooling dependencies
├── bin/                # Shared scripts and workspace utilities
├── lib/                # Internal Ruby code for workspace tooling
├── tools/              # Supporting tool scripts and utilities
├── test/               # Workspace tooling tests
├── config/             # Shared workspace configuration
├── contracts/          # Shared contracts and OpenAPI artifacts
├── docs/               # Workspace-level architecture and workflow docs
└── repos/              # Independently versioned template repositories
    ├── api-template/
    ├── web-template/
    └── template-work-tracking/
```

## Repository Relationship Model

The workspace is aware of child repositories.
Child repositories should be usable independently and should not depend on workspace internals for normal development.

This keeps each template free to:

- Be cloned and run independently
- Maintain isolated CI pipelines
- Evolve and release independently
- Be reused outside this workspace

## Documentation Strategy

Workspace docs explain how repositories interact.
Repository docs explain how repositories work.

Start here:

- `docs/README.md`
- `docs/getting-started.md`
- `docs/architecture.md`
- `docs/repository-conventions.md`
- `docs/local-development.md`
- `docs/openapi-workflow.md`
- `docs/testing-strategy.md`
- `docs/scripting.md`

## Scripting Approach

Workspace automation is Ruby-first by design.

- Prefer Ruby scripts in `bin/` for cross-repository workflows.
- Keep reusable Ruby implementation code in `lib/`.
- Keep script entrypoints in `bin/` thin and command-oriented.
- Use shell snippets only for small command invocation inside Ruby scripts.
- Optimize for readability and maintainability over clever shell composition.

## Workspace Tooling Gems

The workspace now includes a root `Gemfile` for shared tooling dependencies:

- `pastel`
- `tty-spinner`
- `tty-table`
- `awesome_print`

## Essential Commands

The first priority scripts for developer ergonomics:

- `bin/preinstall`: verify Ruby compatibility and GitHub CLI authentication before install workflows.
- `bin/bootstrap`: verify repos and install dependencies.
- `bin/doctor`: check local workstation prerequisites and ports.
- `bin/status`: show git branch and dirty state across repos.
- `bin/pull`: update all repositories with `git pull --ff-only`.
- `bin/sync-openapi`: copy OpenAPI from API template into shared targets.
- `bin/dev`: start core local services.
- `bin/start-day`: run daily coordination workflow.
- `bin/init_new_project <product-slug>`: guided first-time setup flow (environment checks, bootstrap, rename, validation, optional dev launch).
- `bin/new_product <product-slug>`: orchestrate template-to-product rename across repos.
- `bin/validate_product <product-slug>`: run post-rename validation checks and checklist.

## Local Port Conventions

Workspace development tooling uses fixed local ports for consistency:

- API template: `5001`
- Web template: `3000`

The source of truth for orchestration defaults is `config/ports.yml`.

## Guiding Principle

Coordinate repositories, do not tightly couple them.

Whenever possible:

- Shared concerns belong in this workspace.
- Implementation concerns belong in the owning repository.
- Contracts define interfaces between repositories.
- Integration tests validate those contracts.
