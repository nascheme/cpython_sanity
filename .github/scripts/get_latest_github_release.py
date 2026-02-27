#!/usr/bin/env python3
"""Print the latest GitHub release tag for a given repository.

Usage: get_latest_github_release.py owner/repo
Example: get_latest_github_release.py numpy/numpy  ->  v2.2.3
"""
import sys, json, os, urllib.request

if len(sys.argv) < 2:
    print("Usage: get_latest_github_release.py owner/repo", file=sys.stderr)
    sys.exit(1)

repo = sys.argv[1]
url = f"https://api.github.com/repos/{repo}/releases/latest"

headers = {"Accept": "application/vnd.github+json"}
token = os.environ.get("GITHUB_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"

try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
except Exception:
    # On any error, exit quietly with no output (same convention as get_latest_python.py)
    sys.exit(0)

tag = data.get("tag_name", "")
if tag:
    print(tag)
