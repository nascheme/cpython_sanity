BUILD.md

Purpose
-------
This document describes the automated build coordination for the cpython/NumPy/SciPy sanitizer images in this repository.

Overview
--------
- A weekly coordinator workflow (/.github/workflows/weekly_cpython_3_14_check.yml) checks python.org for the latest stable Python 3.14.x release.
- If a new stable 3.14.x release is found and one or more images for that exact release tag are missing from GHCR, the coordinator dispatches the corresponding build workflows to create only the missing images.
- Existing build workflows were adapted so they can accept an exact release tag (e.g. "3.14.3t") and will push both the exact tag and the major tag (e.g. "3.14t") when building an exact release.

Images and Tagging
------------------
Images built and their GHCR names:
- ghcr.io/nascheme/cpython-tsan
- ghcr.io/nascheme/cpython-asan
- ghcr.io/nascheme/numpy-tsan
- ghcr.io/nascheme/numpy-asan
- ghcr.io/nascheme/scipy-tsan

Tagging policy when building an exact release (example latest 3.14.3):
- push ghcr.io/nascheme/<image>:3.14.3t
- also push ghcr.io/nascheme/<image>:3.14t (so the major tag points to the latest patch)
- build workflows pass tags to `docker/build-push-action` as a newline-delimited list (required format when pushing multiple tags).

Coordinator behavior
--------------------
- Runs weekly (cron: Monday 06:00 UTC) and is also manually dispatchable.
- Uses python.org API to list published releases and picks the latest stable 3.14.x release via a small Python helper script (.github/get_latest_python.py).
- For each image, checks GHCR manifest endpoint for existence of the tag (ghcr.io/v2/nascheme/<image>/manifests/<tag>) using the CI_TOKEN secret.
- If an image is missing, the coordinator dispatches only the appropriate build workflow (selective dispatch).
- Dispatch order attempts to favor base images first (cpython first, then dependent images) but builds are asynchronous.

Secrets and tokens
------------------
The workflows expect the following secrets to be configured in the repository (Settings → Secrets and variables → Actions → New repository secret):

- CI_TOKEN (required)
  - Used by build workflows to login to ghcr.io and push images.
  - Must have push and read access to ghcr.io for the `nascheme` namespace.
  - Also used by the coordinator when polling GHCR for image/tag existence.

- GHCR_USERNAME (optional but recommended)
  - GitHub username that owns `CI_TOKEN`.
  - Needed when `CI_TOKEN` belongs to a different user than `github.repository_owner`.
  - If not set, coordinator defaults to `github.repository_owner`.

- DISPATCH_TOKEN (required)
  - A PAT used by the coordinator to call the GitHub REST API and dispatch workflows.
  - The coordinator now requires this secret and fails fast if it is missing.

How to create and add a PAT (GitHub UI)
---------------------------------------
Use a **fine-grained PAT** if possible. Most 403 errors happen because the token is valid but does not have enough repository permissions.

Option A (recommended): Fine-grained PAT
1. Go to https://github.com/settings/personal-access-tokens/new (or: Settings → Developer settings → Personal access tokens → Fine-grained tokens).
2. Set an expiration and token name (for example: `cpython_sanity_dispatch`).
3. Resource owner: choose the owner that contains this repository.
4. Repository access: **Only select repositories** → choose `nascheme/cpython_sanity`.
5. Repository permissions (minimum):
   - **Actions: Read and write** (required for `workflow_dispatch` API)
   - **Contents: Read** (recommended; harmless and often needed by related API calls)
   - **Metadata: Read** (usually implicit/default)
6. Create token and copy it immediately.
7. Add it to this repository as a secret:
   - Settings → Secrets and variables → Actions → New repository secret
   - Name: `DISPATCH_TOKEN`
   - Value: paste token

Option B: Classic PAT (alternative)
1. Go to https://github.com/settings/tokens and create a classic token.
2. Scopes:
   - `workflow` (required for dispatching workflows)
   - `repo` (required for private repos; recommended here)
3. Save as repository secret `DISPATCH_TOKEN`.

Important permission notes
- The token owner must have **write** access (or higher) to `nascheme/cpython_sanity`.
- If this repository is in an organization with SSO enforcement, the PAT must be **authorized for SSO**.
- `DISPATCH_TOKEN` must be valid; an invalid token will cause dispatch calls to fail with HTTP 403.
- GHCR checks should return HTTP 200 when an image exists. Repeated HTTP 401/403 during checks means GHCR auth is wrong (not cache-related). Verify `CI_TOKEN` scopes and set `GHCR_USERNAME` to the token owner's username.

Minimal permissions summary
- Fine-grained PAT: repository = `nascheme/cpython_sanity`; Actions = Read & write; Contents = Read.
- Classic PAT: `workflow` (+ `repo` for private repos).

Quick verification (optional)
- Test dispatch locally before storing the token:
  - `curl -i -X POST https://api.github.com/repos/nascheme/cpython_sanity/actions/workflows/docker_image_cpython.yml/dispatches -H "Authorization: Bearer <TOKEN>" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -d '{"ref":"main","inputs":{"python_version":"3.14.3t"}}'`
  - Expected response: **204 No Content**.
  - **403** means token permission problem.
  - **422** with "not in the list of allowed values" means the workflow on that `ref` still defines `python_version` as a fixed `choice` list (old config). Update/merge workflow files on that branch to use `type: string`, or dispatch to a branch that already has the updated workflow.

Selective dispatch implementation
---------------------------------
- The coordinator checks each image's manifest for the exact release tag (e.g., 3.14.3t).
- It builds a list of missing images and only dispatches the corresponding build workflows for those images.
- Mapping image -> workflow filename is hardcoded in the coordinator:
  - cpython-tsan -> docker_image_cpython.yml
  - cpython-asan -> docker_image_cpython_asan.yml
  - numpy-tsan -> docker_image_numpy.yml
  - numpy-asan -> docker_image_numpy_asan.yml
  - scipy-tsan -> docker_image_scipy.yml

Inter-image dependencies and timing
----------------------------------
- The coordinator dispatches in dependency order and waits for required base images to exist in GHCR before dispatching dependent workflows.
- Dependency chain enforced by the coordinator:
  - `numpy-tsan` waits for `cpython-tsan:<version>`
  - `numpy-asan` waits for `cpython-asan:<version>`
  - `scipy-tsan` waits for `numpy-tsan:<version>`
- This prevents common race failures where dependent builds start before base images are published.

Manual testing and manual runs
-----------------------------
- You can run the coordinator manually via the Actions UI (choose the "Weekly CPython 3.14 release check and dispatch" workflow and click "Run workflow").
- You can manually dispatch any of the build workflows from the Actions UI and specify the python_version input (e.g., 3.14.3t or 3.14t or 3.15t-dev).

BUILD.md vs README
------------------
- BUILD.md contains implementation and operational details for the CI/coordinator system and secrets.
- The repository README should remain focused on user-facing information (images, usage, tags). You asked for BUILD.md to hold build-specific documentation; it's included here.

Next steps I can take
---------------------
- Add an optional wait-for-base-image step in numpy/scipy workflows (with a configurable timeout) if you want to reduce race failures.
- Add a small artifact/logging step that uploads which images were missing and which were dispatched.
- Prepare a branch and PR with these changes (you asked to keep changes local, so I haven't pushed anything).

If you want anything changed (e.g., different cron cadence, different tag format, additional versions to monitor), tell me which and I'll update the workflows accordingly.
