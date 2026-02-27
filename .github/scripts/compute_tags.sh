#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <image> <python_version>" >&2
  exit 2
fi
image="$1"
pv="$2"
if [[ "$pv" =~ ^3\.[0-9]+\.[0-9]+t$ ]]; then
  major=$(echo "$pv" | sed -E 's/^([0-9]+\.[0-9]+)\.[0-9]+t$/\1t/')
  printf 'TAGS<<EOF\n%s:%s\n%s:%s\nEOF\n' "$image" "$pv" "$image" "$major"
else
  printf 'TAGS<<EOF\n%s:%s\nEOF\n' "$image" "$pv"
fi
