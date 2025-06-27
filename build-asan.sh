#!/bin/sh

set -eu

py_ver="3.15t-dev"

DOCKER_BUILDKIT=1 docker build \
    --progress=plain \
    --build-arg 'config_opts=--with-address-sanitizer' \
    --build-arg "python_version=$py_ver" \
    --tag "cpython-asan:$py_ver" \
    -f Dockerfile.cpython .

DOCKER_BUILDKIT=1 docker build \
    --progress=plain \
    --build-arg "base_image=cpython-asan:$py_ver" \
    --build-arg 'setup_args=-Db_sanitize=address' \
    --tag "numpy-asan:$py_ver" \
    -f Dockerfile.numpy .
