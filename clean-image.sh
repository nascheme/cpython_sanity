#!/bin/sh
#
# Remove unwanted/unneeded files from image.

set -eu

clean_dir () {
    find $1 -type f -exec rm {} \;
}

clean_dir /run
clean_dir /tmp
clean_dir /var/cache
clean_dir /var/lib/apt/lists
clean_dir /var/log

# Static libraries are large (~590 MB) and not needed for dynamic
# linking/compilation.  Set to false to keep them if needed.
REMOVE_STATIC_LIBS=false

if [ "$REMOVE_STATIC_LIBS" = true ]; then
    find /usr/lib -name '*.a' -delete
    find /work/.pyenv -name '*.a' -delete 2>/dev/null || true
fi
