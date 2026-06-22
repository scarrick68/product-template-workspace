# OpenAPI Workflow

## Purpose

Define how API contracts are managed and synchronized across repositories.

## Source of Truth

Shared contract artifacts in this workspace define the integration interface.

Primary location:

- `contracts/openapi/`

## Workflow

1. Propose contract change.
2. Update OpenAPI artifacts in `contracts/openapi/` by copying from the api-template repository. OpenAPI route coverage should be comprehensive in the API template, so copying from there ensures the workspace contract is always in sync with the API template implementation.
4. Validate impacted consumers (web/mobile/other templates).
5. Run integration checks.
6. Document behavior or workflow changes in workspace docs.

## Guardrails

- Avoid consumer-specific assumptions in shared contracts.
- Treat backward-incompatible changes as explicit versioned events.
- Keep contract changes and implementation updates synchronized.
- Ensure docs describe expected request/response behavior.

## Ownership Model

- Workspace defines contract coordination workflow.
- API template owns implementation details.
- Consumer templates own adaptation to contract changes.

## Success Criteria

- Contract updates are traceable.
- Consumers can validate compatibility quickly.
- Integration failures are detected before release.
