# ADR 0001: Ruby-First Workspace Scripting

- Status: accepted
- Date: 2026-06-22

## Context

The workspace needs shared automation for cross-repository coordination tasks such as bootstrap, diagnostics, status checks, contract sync, and development orchestration.

Historically, these workflows are often implemented as shell scripts. Shell can become difficult to read and maintain as workflows grow in branching, error handling, and data parsing needs.

## Decision

Adopt Ruby as the default implementation language for workspace automation scripts in `bin/`.

## Consequences

Positive:

- More readable workflow logic.
- Better structure for multi-step orchestration.
- Simpler integration with YAML/JSON configuration.
- Easier testability and reuse through shared helpers.

Trade-offs:

- Ruby runtime is required for script execution.
- Contributors unfamiliar with Ruby may need a short ramp-up.

## Implementation Notes

- Shared helpers live in `bin/lib/workspace.rb`.
- Script behavior is configured through `config/repos.yml` and `config/ports.yml`.
- Shell commands remain acceptable only as subprocesses for tooling integration.
