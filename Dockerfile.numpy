ARG base_image=cpython-tsan

##############################################################################
# Temporary build image
##############################################################################
FROM $base_image AS build

# Checkout numpy source code
RUN git clone --single-branch --depth=1 --no-tags --shallow-submodules \
    https://github.com/numpy/numpy $WORK/numpy

WORKDIR $WORK/numpy

# Checkout submodules
RUN git submodule update --init

# This warning is just noise, disable.
ENV PIP_ROOT_USER_ACTION=ignore

ENV TSAN_OPTIONS="report_bugs=0 exitcode=0"

# Install Python requirements
RUN --mount=type=cache,target=/root/.cache \
    pip install -r requirements/build_requirements.txt && \
    pip install -r requirements/ci_requirements.txt && \
    pip install -r requirements/test_requirements.txt

# Build/install numpy
RUN python -m pip install . --no-build-isolation -C'setup-args=-Db_sanitize=thread'

# clean unwanted files from image
ADD clean-image.sh /
RUN sh /clean-image.sh && rm /clean-image.sh

##############################################################################
# Final image
##############################################################################
FROM ubuntu:25.04

ENV WORK=/work

COPY --from=build / /

ENV CC=clang-20
ENV CXX=clang++-20

ENV PYENV_ROOT="$WORK/.pyenv"
ENV PYENV_BIN="$PYENV_ROOT/bin"
ENV PYENV_SHIMS="$PYENV_ROOT/shims"
ENV PATH="$PATH:$WORK/.pyenv/bin:$WORK/.pyenv/shims"

WORKDIR $WORK
