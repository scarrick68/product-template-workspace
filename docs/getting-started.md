# Getting Started

This guide covers the fastest path to bootstrap a new product from templates and the manual rename tools when needed.

## Before You Start

Validation:

1. Run `bin/install_local_dev_tools`, then `bin/preinstall_checks` and `bin/doctor`.
2. If it reports failures, fix the provided errors and run it again.
3. Continue only after `bin/doctor` succeeds.

Repeatability:

1. Safe to run repeatedly.
2. If environment changes (Ruby, Docker, auth), re-run before continuing.

## Recommended Path: One-Command Bootstrap

## Canonical Entrypoints

Use `bin/workspace` as the public CLI contract for project setup flows:

- `bin/workspace new-project <product-slug> [--destination PATH]`
- `bin/workspace repository setup <product-slug> [init options]`
- `bin/workspace repository rename <product-slug>`
- `bin/workspace repository verify <product-slug>`

Infrastructure starts separately after project setup via:

- `bin/workspace infra <doctor|configure|plan|apply> [environment]`

## New App Setup Flow

Legend:

- `[USER]` means a manual decision or action by the operator.
- `[SCRIPT: <name>]` means the step is handled by automation in that utility script.

```mermaid
flowchart TD
	A[[USER: Start new product setup]] --> B[[USER: Run bin/workspace new-project --destination ~/Code/my-super-app my-super-app -- --no-dev]]
	B --> C[[SCRIPT: workspace new-project copies workspace to destination and delegates to workspace repository setup in copied workspace]]
	C --> D[[SCRIPT: repository setup runs install_local_dev_tools, preinstall_checks, and doctor]]
	D --> E{Checks pass?}
	E -- No --> F[[USER: Read FAIL output and fix environment issues]]
	F --> D
	E -- Yes --> G[[SCRIPT: repository setup runs bootstrap and pull]]
	G --> H{Use --create-remotes?}
	H -- No --> I[[USER: Confirm backend and frontend remotes exist]]
	I --> J{Repos ready?}
	J -- No --> K[[USER: Create repos manually and rerun]]
	K --> I
	J -- Yes --> L[[SCRIPT: repository setup runs repository rename]]
	H -- Yes --> M[[SCRIPT: repository setup verifies GitHub auth/permissions]]
	M --> N{Auth checks pass?}
	N -- No --> O[[USER: Fix gh auth and owner permissions]]
	O --> M
	N -- Yes --> L
	L --> P[[SCRIPT: repository setup runs repository verify]]
	P --> Q{Validation passes?}
	Q -- No --> R[[USER: Fix reported issues and rerun validation]]
	R --> P
	Q -- Yes --> S{Create remotes mode?}
	S -- No --> T[[SCRIPT: repository setup unsets inherited template origins]]
	S -- Yes --> U[[SCRIPT: repository setup creates missing remotes on GitHub]]
	U --> V[[SCRIPT: repository setup configures local git origins]]
	V --> W{Push enabled?}
	W -- Yes --> X[[SCRIPT: repository setup pushes current branch where available]]
	W -- No --> Y[[USER: Skip push for manual follow-up]]
	X --> Z[[SCRIPT: repository setup runs optional dev step]]
	Y --> Z
	T --> Z
	Z --> AA[[USER: Ready for feature development]]
```

```mermaid
flowchart TD
	A[[USER: Need manual path?]] --> B{Use one-command init?}
	B -- Yes --> C[[USER: Use bin/workspace repository setup]]
	B -- No --> D[[USER: Run manual rename and validation steps]]
	D --> E[[USER: Follow template-specific rename docs]]
	E --> F[[USER + SCRIPT: run workspace/template checks]]
	C --> F
	F --> G[[USER: Continue with local development workflow]]
```

Command:

```bash
bin/workspace new-project --destination ~/Code/my-super-app my-super-app -- --no-dev
```

What this does:

1. Copies template workspace into a new destination workspace (sibling by default when `--destination` is omitted).
2. Preserves copied git histories for the workspace and template repos; nothing is removed automatically.
3. Delegates to `bin/workspace repository setup` inside the copied workspace.
4. Runs guided machine setup (`install_local_dev_tools`) for missing tool install/auth prompts.
5. Runs prechecks (`preinstall_checks`, `doctor`).
6. Clones/bootstraps dependencies and updates repos (`bootstrap`, `pull`).
7. Uses one of two remote workflows:
	- manual mode (default): prompts to confirm backend/frontend remotes already exist.
	- automated mode (`--create-remotes`): verifies GitHub permissions, creates remotes with selected visibility, sets local origins, and optionally pushes.
8. Runs template rename orchestration (`bin/workspace repository rename`).
9. Runs post-rename validation (`bin/workspace repository verify`).
10. Configures git remotes:
	- manual mode: unsets template `origin` remotes and prints add-remote hints.
	- automated mode: points local repos to newly created product remotes.
11. Pushes to remotes when automated mode is enabled (unless `--no-push` is used).
12. Optionally launches local dev services.

Messages to watch for:

0. Give the messages a scan on first run. Some are informational about options or next steps. Some are warnings or failures that require your attention.
1. Anything starting with `[FAIL]`, you should read those messages and fix the underlying issue before continuing. They attempt to be actionable.
2. Check for `[WARN]`, these will inform you of attempted actions or decisions that require your attention. They may not be fatal such as if Postgres is already running, that port may be occupied. Or Postgres may not be visible to the scripts if you run it in Docker in your projects and the containers are not running.


Validation after command:

1. Before first production deploy (not required for local dev), set API CORS origins (`CORS_ALLOWED_ORIGINS`) in your platform env config (PaaS) or in the app `.env` used by your deploy/runtime, and follow `repos/api-template/docs/deploy/production-cors-setup.md`.
2. Run `bin/ci` in the API repo and `npm run lint && npm run test && npm run build` in the web repo.
3. Run `bin/start-day` to launch local dev services and verify the app is running. Works best when respository workspaces are clean and up to date. If you have uncommitted changes, stash or commit them first.
4. If that all works, you are ready to start development.

## Alternative: Manual Rename + Validate Steps

1. Rename tools may be used independently if you want to run them manually. See instructions in respective repos for intended usage.

## Remote Setup After Bootstrap

After `bin/workspace repository setup`, origin remotes are unset in manual mode to avoid accidental pushes to template repositories.

Use printed commands from the init output, then verify:

```bash
git -C . remote -v
git -C repos/my-super-app-api remote -v
git -C repos/my-super-app-web remote -v
```

Expected result:

1. Each repository points to your own project location.
