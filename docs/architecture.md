# Architecture

## Overview

The workspace acts as an integration shell around independently owned template repositories. It centralizes cross-cutting concerns while preserving repository autonomy.

## Architectural Goals

- Keep templates independently operable.
- Define stable interfaces through shared contracts.
- Provide one place for cross-repository workflows.
- Prevent duplication of architecture and process docs.

## Core Components

- `contracts/`: Shared interface artifacts, including OpenAPI assets.
- `bin/`: Workspace scripts for orchestration and automation.
- `config/`: Shared workspace configuration.
- `docs/`: Cross-repository architecture and workflow documentation.
- `repos/`: Template repositories that own implementation code.

## Ownership Boundary

Workspace-owned concerns:

- Contracts and interface conventions
- Shared development workflows
- Integration validation across templates
- Cross-repository tooling and docs

Template-owned concerns:

- Domain/business logic
- Internal architecture and implementation
- Template-specific testing and CI details
- Template deployment implementation

## Interaction Model

1. Contracts are defined and versioned as the integration source of truth.
2. Template repositories implement against those contracts.
3. Cross-repository checks validate compatibility.
4. Documentation in this repo captures expected interaction patterns.

## Design Principle

Use loose coupling with explicit contracts:

- Integration through documented interfaces
- Independent evolution inside each template
- Coordinated changes only for shared boundaries
