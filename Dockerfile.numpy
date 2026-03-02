ARG base_image=cpython-tsan
# Default is a known-good tag for local builds. CI overrides this.
ARG numpy_version=v2.4.2

##############################################################################
# Temporary build image
##############################################################################
FROM $base_image AS build

ARG numpy_version
ARG setup_args="-Db_sanitize=thread"

# Checkout numpy source code at specific release
RUN git clone --branch $numpy_version --single-branch --depth=1 \
    --no-tags --shallow-submodules \
    https://github.com/numpy/numpy $WORK/numpy

WORKDIR $WORK/numpy

# Checkout submodules
RUN git submodule update --init

# This warning is just noise, disable.
ARG PIP_ROOT_USER_ACTION=ignore

ARG TSAN_OPTIONS="report_bugs=0 exitcode=0"
ARG ASAN_OPTIONS="detect_leaks=0 exitcode=0"

# Install Python requirements
RUN --mount=type=cache,target=/root/.cache \
    pip install -r requirements/build_requirements.txt && \
    pip install -r requirements/ci_requirements.txt && \
    pip install -r requirements/test_requirements.txt

# Build/install numpy
RUN python -m pip install . --no-build-isolation -C"setup-args=${setup_args}"

# Save a copy of the TSAN suppression list
RUN cp tools/ci/tsan_suppressions.txt ../tsan_suppressions/numpy.txt

# clean unwanted files from image
ADD clean-image.sh /
RUN sh /clean-image.sh && rm /clean-image.sh && rm -rf $WORK/numpy

##############################################################################
# Final image
##############################################################################
FROM $base_image

COPY --from=build /work /work
