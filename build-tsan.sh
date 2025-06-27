#!/bin/sh

set -eu

DOCKER_BUILDKIT=1 docker build --progress=plain --tag cpython-tsan -f Dockerfile.cpython .
DOCKER_BUILDKIT=1 docker build --progress=plain --tag numpy-tsan -f Dockerfile.numpy .
DOCKER_BUILDKIT=1 docker build --progress=plain --tag scipy-tsan -f Dockerfile.scipy .
