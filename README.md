Build container images for CPython, numpy, etc with sanitizer options enabled.

Available container images
--------------------------

Builds with
[ThreadSanitizer](https://github.com/google/sanitizers/wiki/ThreadSanitizerCppManual)
enabled. This is useful to detect data races in C and C++ code.

Free-threaded Python builds with TSAN enabled:

    ghcr.io/nascheme/cpython-tsan:3.13t
    ghcr.io/nascheme/cpython-tsan:3.14t
    ghcr.io/nascheme/cpython-tsan:3.14t-dev

Above builds with "numpy" compiled with TSAN as well:

    ghcr.io/nascheme/numpy-tsan:3.13t
    ghcr.io/nascheme/numpy-tsan:3.14t
    ghcr.io/nascheme/numpy-tsan:3.14t-dev

Above builds with "scipy" compiled with TSAN as well:

    ghcr.io/nascheme/scipy-tsan:3.13t
    ghcr.io/nascheme/scipy-tsan:3.14t
    ghcr.io/nascheme/scipy-tsan:3.14t-dev


The `3.14t-dev` images are rebuild twice a week by a cron job. The `3.13t` and
`3.14t` images are rebuilt manually when Python releases happen.

Builds with
[AddressSanitizer](https://github.com/google/sanitizers/wiki/addresssanitizer)
enabled.  This is useful to find memory leaks in C and C++ code.

Free-threaded Python builds with ASAN enabled:

    ghcr.io/nascheme/cpython-asan:3.14t

Above build with "numpy" compiled with ASAN as well:

    ghcr.io/nascheme/numpy-asan:3.14t


Hints
-----

To open a command prompt inside the container, you can use the following
command:

    docker run -it --rm <image url> bash

If you want to open additional command prompts, you can use "exec", e.g.

    docker exec -it <container ID> bash

The container ID is shown in the prompt as `root@<container ID>`.  If you want
changes you make inside the container to persist, you should remove the `--rm`
command line argument.  Note that you will need to remember to manually remove
the container after you are finished with it.

Python is installed under `/work/.pyenv/versions`.  The `python` command
will already be in the path.

Depending on the version of Linux running on the container host, you may need
to adjust some settings.  To avoid ASLR interferring with the TSAN checking,
the following config change may be required:

    sudo sysctl vm.mmap_rnd_bits=28

Since this change reduces security, you likely want to revert to the default
number of bits after running tests.

If ASLR is not disabled, you might see an error similar to the following:

    root@b60155750c89:/work# python
    ThreadSanitizer: CHECK failed: tsan_platform_linux.cpp:290 "((personality(old_personality | ADDR_NO_RANDOMIZE))) != ((-1))" (0xffffffffffffffff, 0xffffffffffffffff) (tid=13)
    Segmentation fault (core dumped)


If you need to install packages using "apt", the list of packages needs
to be updated first, e.g.

    apt-get update && apt-get install <pkg name>


Running cpython tests
---------------------

Example of running unit tests under ASAN:

    export ASAN_OPTIONS=allocator_may_return_null=1:halt_on_error=1
    python -m test 2>&1 | tee /work/out.txt


Running numpy tests
-------------------

Example of running unit tests under ASAN:

    export ASAN_OPTIONS=allocator_may_return_null=1:halt_on_error=1
    cd /work/.pyenv/versions/*/lib/*/site-packages/numpy
    pytest 2>&1 | tee /work/out.txt


Running scipy tests
-------------------

Example of running a single test with pytest:

    export TSAN_OPTIONS=allocator_may_return_null=1:halt_on_error=1
    cd /work/.pyenv/versions/*/lib/*/site-packages/scipy
    PYTHON_GIL=0 pytest -v -s optimize/tests/test_minpack.py::TestFSolve::test_concurrent_no_gradient
