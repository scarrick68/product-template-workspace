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
├── bin/                # Shared scripts and workspace utilities
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
- `docs/architecture.md`
- `docs/repository-conventions.md`
- `docs/local-development.md`
- `docs/openapi-workflow.md`
- `docs/testing-strategy.md`

## Guiding Principle

Coordinate repositories, do not tightly couple them.

Whenever possible:

- Shared concerns belong in this workspace.
- Implementation concerns belong in the owning repository.
- Contracts define interfaces between repositories.
- Integration tests validate those contracts.
