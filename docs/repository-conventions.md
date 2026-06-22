# Repository Conventions

## Purpose

Define how repositories coordinate without introducing tight coupling.

## Coordination Principles

- Keep repository boundaries explicit.
- Prefer contracts over implicit behavior.
- Document cross-repository changes in workspace docs.
- Keep implementation details in the owning repository.

## Ownership Rules

Workspace owns:

- Cross-repository conventions
- Shared tooling and scripts
- Contract synchronization process
- Integration test strategy (TBD)

Template repositories own:

- Product/application code
- Internal architecture decisions
- Template-specific CI and release behavior
- Template runtime and deployment details

## Documentation Rules

- Add workspace-level process docs under `docs/`.
- Keep implementation docs in each template repo.
- Link to template docs instead of duplicating content.
- Update docs whenever cross-repository behavior changes.

## Change Management Rules

For changes that cross repository boundaries:

1. Update the contract/interface definition first.
2. Update all affected templates.
3. Run integration checks.
4. Update workspace docs to reflect the new workflow.

## Independence Requirement

Each template repository should remain usable outside this workspace context. Workspace tooling should aid development, not become a hard runtime dependency.
