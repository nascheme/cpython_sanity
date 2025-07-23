#!/usr/bin/env python3
"""
Download TSAN suppression lists and print the result to stdout.
"""

import sys
import urllib.error
import urllib.request

# A list of URLs pointing to raw text files to be downloaded.
URLS = [
    'https://raw.githubusercontent.com/python/cpython/refs/heads/3.14/Tools/tsan/suppressions_free_threading.txt',
    'https://raw.githubusercontent.com/numpy/numpy/refs/heads/main/tools/ci/tsan_suppressions.txt',
]


def main():
    full_content = []
    for url in URLS:
        full_content.append(f'## {url}\n')
        try:
            with urllib.request.urlopen(url) as response:
                content = response.read()
                full_content.append(content.decode('utf-8'))
        except urllib.error.URLError as e:
            print(f"Error downloading {url}: {e}", file=sys.stderr)
            return 1
        except UnicodeDecodeError as e:
            print(f"Error decoding content from {url}: {e}", file=sys.stderr)
            return 1

    sys.stdout.write("\n".join(full_content))
    return 0


if __name__ == '__main__':
    sys.exit(main())
