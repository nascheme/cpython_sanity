BUILD.md
========

Developer documentation for the CI build system.  For image usage, see
README.md.

Image hierarchy
---------------

Images are built in a dependency chain:

    cpython-tsan -> numpy-tsan -> scipy-tsan
    cpython-asan -> numpy-asan

Each image is tagged by Python version (e.g. `3.14.3t`) with a minor-version
alias (e.g. `3.14t`).  Tag computation is handled by
`.github/scripts/compute_tags.sh`.

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
3. Checks GHCR for existing images at the discovered Python version tag.
4. Dispatches build workflows for any missing images, passing the resolved
   library versions (`numpy_version`, `scipy_version`) in the dispatch inputs.
5. Respects the dependency chain -- waits for base images to appear in GHCR
   before dispatching dependent builds.

Helper scripts
--------------

- `.github/scripts/get_latest_python.py` -- Queries python.org for the latest
  release matching a given minor version prefix.  Supports `--pre-release`.
- `.github/scripts/get_latest_github_release.py` -- Queries the GitHub releases
  API for the latest release tag of any `owner/repo`.  Uses `GITHUB_TOKEN` env
  var for authentication when available.
- `.github/scripts/compute_tags.sh` -- Computes Docker image tags.  For an
  exact version like `3.14.3t`, outputs both `3.14.3t` and `3.14t` tags.

Secrets
-------

The following secrets must be configured (Settings > Secrets and variables >
Actions):

- **CI_TOKEN** -- Used to login to ghcr.io and push images.  Must have push
  and read access to the `nascheme` GHCR namespace.  Also used by the
  coordinator to check for existing image tags.

- **DISPATCH_TOKEN** -- A PAT used by the coordinator to dispatch build
  workflows via the GitHub REST API.  Minimum permissions: Actions read/write
  on this repository.

- **GHCR_USERNAME** (optional) -- GitHub username that owns `CI_TOKEN`.  Only
  needed if `CI_TOKEN` belongs to a different user than `github.repository_owner`.

### Creating a fine-grained PAT for DISPATCH_TOKEN

1. Go to Settings > Developer settings > Personal access tokens > Fine-grained
   tokens.
2. Repository access: select only this repository.
3. Repository permissions: Actions = Read and write, Contents = Read.
4. Save the token as the `DISPATCH_TOKEN` repository secret.

A classic PAT with the `workflow` scope also works.

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
