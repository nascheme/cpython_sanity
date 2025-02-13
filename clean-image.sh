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
