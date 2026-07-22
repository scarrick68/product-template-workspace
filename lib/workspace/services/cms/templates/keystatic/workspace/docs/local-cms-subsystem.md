# Local CMS Subsystem

This project uses a local-only CMS subsystem for content authoring.

## Purpose

- Keep the public app runtime (Vike) isolated from editor routing concerns.
- Host Keystatic in a separate local Astro workspace.
- Write content directly into repository files for normal PR workflows.

## Layout

Frontend root:

- `keystatic.config.ts`
- `content/articles/*/index.yaml`
- `content/articles/*/body.mdoc`
- `src/content/validate-content.ts`

Nested local CMS workspace:

- `packages/keystatic-admin/package.json`
- `packages/keystatic-admin/astro.config.mjs`
- `packages/keystatic-admin/keystatic.config.ts`
- `packages/keystatic-admin/src/pages/index.astro`

## Runtime Model

- `npm run dev` starts Vike only.
- `npm run content` starts Keystatic admin only.
- `npm run dev:content` starts both.

Keystatic edits content files under `content/articles/`. Vike renders those files in public routes.

## Operations

- Validate content schema and cross-field rules with `npm run content:check`.
- Validate local CMS dev wiring with `bin/workspace repository verify <product-slug>` (runs a workspace-level reachability check that starts Vike + Keystatic, checks URLs, then stops both).
- Use normal Git commits and pull requests for content publication.
- Keep CMS installer commit boundaries for reliable rollback with `git revert`.

## Scope and Deployment

The local CMS workspace is for local authoring and is not required for production Vike deploys.
