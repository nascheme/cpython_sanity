BUILD.md
========

Developer documentation for the CI build system.  For image usage, see
README.md.

Image hierarchy
---------------

Images are built in a dependency chain:

    cpython-tsan -> numpy-tsan -> scipy-tsan
    cpython-asan -> numpy-asan

Each image is tagged by Python version with a minor-version alias.
Free-threaded builds use "t" suffixed tags (e.g. `3.14.3t` / `3.14t`).
GIL-enabled cpython builds use plain version tags (e.g. `3.14.3` / `3.14`).
Tag computation is handled by `.github/scripts/compute_tags.sh`.

Dockerfiles
-----------

- `Dockerfile.numpy` -- Accepts `base_image` and `numpy_version` build args.
  `numpy_version` defaults to a known-good release tag (e.g. `v2.2.3`) and
  is used as the `--branch` for `git clone`.

- `Dockerfile.scipy` -- Same pattern with `scipy_version` (e.g. `v1.15.2`).

The CPython Dockerfiles (`Dockerfile.cpython`, `Dockerfile.cpython_asan`) do
not have a library version arg -- they build from a pyenv-installed Python.

Workflows
---------

### Build workflows

Each image has a dedicated build workflow under `.github/workflows/`:

| Workflow | Image | Inputs |
|----------|-------|--------|
| `docker_image_cpython.yml` | cpython-tsan | `python_version` |
| `docker_image_cpython_asan.yml` | cpython-asan | `python_version` |
| `docker_image_numpy.yml` | numpy-tsan | `python_version`, `numpy_version` |
| `docker_image_numpy_asan.yml` | numpy-asan | `python_version`, `numpy_version` |
| `docker_image_scipy.yml` | scipy-tsan | `python_version`, `scipy_version` |

When `numpy_version` or `scipy_version` is left empty (or omitted), the
workflow resolves the latest stable release from GitHub automatically using
`.github/scripts/get_latest_github_release.py`.

The `3.15t-dev` images are built on a cron schedule (twice weekly) and always
pull the latest development code from main branches.

### Coordinator workflow

`python_version_check.yml` runs weekly (Monday 06:00 UTC) and can also be
triggered manually.  It:

1. Queries python.org for the latest stable release of each tracked Python
   minor version (3.13, 3.14, 3.15).
2. Resolves the latest numpy and scipy release tags from GitHub.
3. Checks GHCR for existing free-threaded images (e.g. `3.14.3t`) and
   GIL-enabled cpython images (e.g. `3.14.3`).
4. Dispatches build workflows for any missing images, passing the resolved
   library versions (`numpy_version`, `scipy_version`) in the dispatch inputs.
5. Respects the dependency chain -- waits for base images to appear in GHCR
   before dispatching dependent builds.
6. Dispatches GIL-enabled cpython-tsan and cpython-asan builds using the
   plain version (without "t" suffix) when those images are missing.

Helper scripts
--------------

- `.github/scripts/get_latest_python.py` -- Queries python.org for the latest
  release matching a given minor version prefix.  Supports `--pre-release`.
- `.github/scripts/get_latest_github_release.py` -- Queries the GitHub releases
  API for the latest release tag of any `owner/repo`.  Uses `GITHUB_TOKEN` env
  var for authentication when available.
- `.github/scripts/compute_tags.sh` -- Computes Docker image tags.  For an
  exact version like `3.14.3t`, outputs both `3.14.3t` and `3.14t` tags.
  Similarly, `3.14.3` produces `3.14.3` and `3.14` tags.

Secrets
-------

The workflows authenticate to ghcr.io and dispatch other workflows using the
job-scoped `GITHUB_TOKEN` wherever possible.  `GITHUB_TOKEN` is minted per job
and requires no manual configuration.

One long-lived secret is still required (Settings > Secrets and variables >
Actions):

- **CI_TOKEN** -- A PAT used only by `clean_images.yml` to delete old package
  versions.  `GITHUB_TOKEN` cannot delete user-owned package versions, so a
  PAT is required for this single workflow.  Minimum scopes (classic PAT):
  `read:packages` and `delete:packages`.  No `repo`, `workflow`, or
  `write:packages` scope is needed.

For the build workflows to push images using `GITHUB_TOKEN`, each ghcr.io
package (`cpython-tsan`, `cpython-asan`, `numpy-tsan`, `numpy-asan`,
`scipy-tsan`) must list this repository under *Package settings > Manage
Actions access* with the **Write** role.

Local builds
------------

Build a numpy image locally with a specific release:

    docker build -f Dockerfile.numpy \
      --build-arg numpy_version=v2.2.3 \
      --build-arg base_image=cpython-tsan .

Build scipy:

    docker build -f Dockerfile.scipy \
      --build-arg scipy_version=v1.15.2 \
      --build-arg base_image=numpy-tsan .

Manual workflow dispatch
------------------------

Any build workflow can be triggered from the Actions UI.  Specify
`python_version` (e.g. `3.14.3t`) and optionally `numpy_version` or
`scipy_version`.  Leave the library version empty to auto-resolve the latest
stable release.

The coordinator can also be run manually to re-check all versions and dispatch
any missing builds.
