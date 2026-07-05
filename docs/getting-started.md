# Getting Started

This guide covers the fastest path to bootstrap a new product from templates and the manual rename tools when needed.

## Before You Start

Validation:

1. Run `bin/preinstall` and `bin/doctor`.
2. If it reports failures, fix the provided errors and run it again.
3. Continue only after `bin/doctor` succeeds.

Repeatability:

1. Safe to run repeatedly.
2. If environment changes (Ruby, Docker, auth), re-run before continuing.

## Recommended Path: One-Command Bootstrap

## New App Setup Flow

Legend:

- `[USER]` means a manual decision or action by the operator.
- `[SCRIPT: <name>]` means the step is handled by automation in that utility script.

```mermaid
flowchart TD
	A[[USER: Start new product setup]] --> B[[USER: Run bin/init_new_project my-super-app]]
	B --> C[[SCRIPT: init_new_project runs preinstall and doctor]]
	C --> D{Checks pass?}
	D -- No --> E[[USER: Read FAIL output and fix environment issues]]
	E --> C
	D -- Yes --> F[[SCRIPT: init_new_project runs bootstrap and pull]]
	F --> G{Use --create-remotes?}
	G -- No --> H[[USER: Confirm backend and frontend remotes exist]]
	H --> I{Repos ready?}
	I -- No --> J[[USER: Create repos manually and rerun]]
	J --> H
	I -- Yes --> K[[SCRIPT: init_new_project runs new_product]]
	G -- Yes --> L[[SCRIPT: init_new_project with github_auth_doctor]]
	L --> M{Auth checks pass?}
	M -- No --> N[[USER: Fix gh auth and owner permissions]]
	N --> L
	M -- Yes --> K
	K --> O[[SCRIPT: init_new_project runs validate_product]]
	O --> P{Validation passes?}
	P -- No --> Q[[USER: Fix reported issues and rerun validation]]
	Q --> O
	P -- Yes --> R{Create remotes mode?}
	R -- No --> S[[SCRIPT: init_new_project runs unset_origin_remotes]]
	R -- Yes --> T[[SCRIPT: init_new_project runs gh repo create]]
	T --> U[[SCRIPT: init_new_project runs git remote add origin]]
	U --> V{Push enabled?}
	V -- Yes --> W[[SCRIPT: init_new_project runs git push]]
	V -- No --> X[[USER: Skip push for manual follow-up]]
	W --> Y[[SCRIPT: init_new_project runs optional dev step]]
	X --> Y
	S --> Y
	Y --> Z[[USER: Ready for feature development]]
```

```mermaid
flowchart TD
	A[[USER: Need manual path?]] --> B{Use one-command init?}
	B -- Yes --> C[[USER: Use bin/init_new_project]]
	B -- No --> D[[USER: Run manual rename and validation steps]]
	D --> E[[USER: Follow template-specific rename docs]]
	E --> F[[USER + SCRIPT: run workspace/template checks]]
	C --> F
	F --> G[[USER: Continue with local development workflow]]
```

Command:

```bash
bin/init_new_project my-super-app
```

What this does:

1. Runs prechecks (`preinstall`, `doctor`).
2. Clones/bootstraps dependencies and updates repos (`bootstrap`, `pull`).
3. Uses one of two remote workflows:
	- manual mode (default): prompts to confirm backend/frontend remotes already exist.
	- automated mode (`--create-remotes`): verifies GitHub permissions, creates remotes with selected visibility, sets local origins, and optionally pushes.
4. Runs template rename orchestration (`new_product`).
5. Runs post-rename validation (`validate_product`).
6. Configures git remotes:
	- manual mode: unsets template `origin` remotes and prints add-remote hints.
	- automated mode: points local repos to newly created product remotes.
7. Pushes to remotes when automated mode is enabled (unless `--no-push` is used).
8. Optionally launches local dev services.

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

After `init_new_project`, origin remotes are unset to avoid accidental pushes to template repositories.

Use printed commands from the init output, then verify:

```bash
git -C . remote -v
git -C repos/my-super-app-api remote -v
git -C repos/my-super-app-web remote -v
```

Expected result:

1. Each repository points to your own project location.
