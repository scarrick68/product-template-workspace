# Local Development

## Purpose

Provide a shared way to run and verify multi-repository development workflows locally. This includes things like spinning up dependent services, running cross-repository checks, syncing contracts like OpenAPI specs, and validating interactions between templates before pushing changes.

This project also brings all dependent repositories together in one place for easier navigation and coordination and AI awareness of the full ecosystem during development.

## Scope

This document defines workspace-level expectations for local development.
Template-specific setup details stay in each template repository.

## Recommended Workflow

1. Clone or update the workspace and required template repositories.
2. Follow each template's local setup documentation.
3. Start required services for the templates under active development.
4. Run cross-repository checks where applicable.
5. Iterate on changes and keep contracts synchronized.

## Operating Guidelines

- Keep local environment assumptions explicit and documented.
- Prefer repeatable scripts in `bin/` for shared tasks.
- Avoid embedding template-specific logic in workspace scripts.
- Use this workspace to orchestrate interactions, not replace template setup.

## Documentation Responsibility

- Workspace docs: orchestration and integration expectations.
- Template docs: service setup, runtime specifics, and implementation detail.

## Expected Outcome

A developer should be able to use this workspace to validate interactions between templates while still developing each template independently.
