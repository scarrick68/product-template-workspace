# Testing Strategy

## Purpose

Describe how this workspace validates behavior across repository boundaries.

## Scope

Workspace testing focuses on integration confidence, not template-internal correctness.

In scope:

- Contract compatibility checks
- Cross-repository smoke tests
- End-to-end interaction sanity checks for shared workflows

Out of scope:

- Unit tests for template internals
- Template-specific CI implementation
- Template-specific performance testing

## Testing Layers

1. Contract validation: verify interface shape and expected semantics.
2. Integration checks: verify producer and consumer compatibility.
3. Smoke tests: verify critical cross-repository flows remain functional.

## Execution Guidance

- Keep integration checks deterministic and environment-aware.
- Prefer fast smoke checks for local iteration.
- Run broader integration checks for cross-boundary changes.
- Track and document known integration assumptions.

## Failure Handling

When cross-repository checks fail:

1. Identify whether failure is contract, producer, or consumer mismatch.
2. Update the appropriate repository and/or shared contract.
3. Re-run affected integration checks.
4. Update workspace docs if process or expected behavior changed.

## Success Criteria

- Contract regressions are detected early.
- Cross-repository breakage is visible before release.
- Developers can diagnose ownership of failures quickly.
