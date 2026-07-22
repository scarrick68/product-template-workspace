# Content Authoring

CMS support is add-only in this workspace. Installer-generated CMS changes are committed with the [SYSTEM][INSTALLER] prefix so rollback remains a simple git revert.

Command and path references below assume you are already in the frontend repository root. If you are reading this from the template workspace repository, prefix commands and file paths with `repos/web-template/`.

## Workflow

1. Run `bin/content` from the frontend app repo.
2. Open the local editor at `http://127.0.0.1:4322/keystatic`.
3. Preview public article routes at `http://localhost:3000/articles`.
4. Run `bin/content-check` from the frontend app repo.
5. Commit content changes and open a pull request. The local CMS writes to the frontend repo file system. A status flag, a pull request and a FE deployment are the publishing gate mechanisms for content changes to be deployed to production.

`bin/content` starts both servers for convenience:

- Keystatic admin: `http://127.0.0.1:4322/keystatic`

For full-stack authoring sessions, run `npm run dev:content`.

Keystatic is hosted by a nested local Astro app workspace under `packages/keystatic-admin`. This keeps CMS admin routing out of Vike route configuration while still writing content directly into the frontend repository.

## Local CMS Subsystem Structure

Frontend root keeps the public site and content validator:

- `keystatic.config.ts`
- `src/content/validate-content.ts`
- `content/articles/*/index.yaml`
- `content/articles/*/body.mdoc`

Nested admin workspace hosts only the local CMS UI and routes:

- `packages/keystatic-admin/package.json`
- `packages/keystatic-admin/astro.config.mjs`
- `packages/keystatic-admin/keystatic.config.ts`
- `packages/keystatic-admin/src/pages/index.astro`

Root `package.json` scripts are the operational interface:

- `npm run dev` -> Vike only
- `npm run content` -> Keystatic admin only
- `npm run dev:content` -> Vike + Keystatic in one command
- `npm run content:check` -> content validation only

## Local CMS Operations

Recommended daily operation:

1. Start Vike app: `npm run dev`
2. Start Keystatic admin in a second terminal: `npm run content`
3. Edit content in Keystatic and validate with `npm run content:check`

Optional one-terminal workflow:

1. Run `npm run dev:content`
2. Open Vike at `http://localhost:3000`
3. Open Keystatic at `http://127.0.0.1:4322/keystatic`

`bin/workspace repository verify <product-slug>` runs a workspace-level reachability check when CMS is enabled, which confirms both dev URLs are reachable.

Keystatic stores each article in a directory, with structured fields in `index.yaml` and body content in `body.mdoc`:

- `content/articles/<slug>/index.yaml`
- `content/articles/<slug>/body.mdoc`

## SEO Field Mapping

Article SEO fields are intentionally aligned to the frontend SEO helpers in `src/seo/seo.config.ts`.

- `seoTitle` -> `buildSeoHeadData(...).title`
- `seoDescription` -> `buildSeoHeadData(...).description`
- `seoImage` -> `buildSeoHeadData(...).openGraph.image`
- `seoImageAlt` -> `buildSeoHeadData(...).openGraph.imageAlt`

Open Graph title and description should follow frontend fallbacks:

- Open Graph title: `seoTitle` then `title`
- Open Graph description: `seoDescription` then `summary`

## Local CMS Removal

Local CMS removal is not supported as an in-place command in this workspace.

Use Git history to roll back installer-generated changes:

1. Find the installer commit with prefix `[SYSTEM][INSTALLER]`.
2. Revert that commit with `git revert <commit_sha>`.
3. Decide content handling before running tests:
	- migrate `content` into the new CMS source of truth, or
	- remove local content files if they are no longer needed.
4. Remove or update CMS touchpoints that are no longer valid for your target setup:
	- any references to `/keystatic`
	- `bin/content` and `bin/content-check` usage
	- content validation scripts and wiring
5. Run smoke checks after revert and cleanup:
	- `npm run test`
	- `npm run build`
	- local route checks for public pages and content pages.
6. Use failing tests/build output to identify any remaining CMS integration references and remove or migrate them.

If content commits were created after installer setup, revert or port those commits intentionally based on product needs.

## Hosted CMS Migration

Hosted CMS migration is a manual follow-up workflow and is intentionally separate from this installer path.

Recommended sequence:

1. Keep local CMS install in its own commit lineage for safe rollback.
2. Define the hosted provider data model to match the current article schema and SEO field contract.
3. Add an adapter layer in the frontend so SEO helpers still receive the same effective values (`title`, `description`, and Open Graph overrides).
4. Import existing local content into the hosted provider.
5. Verify parity with smoke checks:
	- `npm run test`
	- `npm run build`
	- route-level metadata checks (title, description, canonical, Open Graph, Twitter)
	- content route rendering checks.

Treat hosted migration as a new implementation phase instead of extending the local installer in place.

