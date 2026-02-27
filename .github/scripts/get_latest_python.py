#!/usr/bin/env python3
import sys, json, urllib.request, re
import argparse

URL = "https://www.python.org/api/v2/downloads/release/?is_published=true"

parser = argparse.ArgumentParser(
    description="Find latest stable Python version for a given major.minor prefix (e.g. 3.14)"
)
parser.add_argument(
    "prefix",
    nargs="?",
    default="3.14",
    help="Version prefix to search for (e.g. 3.14)",
)
args = parser.parse_args()
prefix = args.prefix

try:
    with urllib.request.urlopen(URL, timeout=30) as r:
        data = json.load(r)
except Exception:
    # On any network/parsing error, exit quietly with no output
    sys.exit(0)

names = []


def walk(o):
    if isinstance(o, dict):
        if "name" in o and isinstance(o["name"], str):
            names.append(o["name"])
        for v in o.values():
            walk(v)
    elif isinstance(o, list):
        for item in o:
            walk(item)


walk(data)

cand = []
pat = re.compile(r"^Python " + re.escape(prefix) + r"\.[0-9]+$")
for n in names:
    if pat.match(n):
        cand.append(n.replace("Python ", ""))

if not cand:
    sys.exit(0)


def keyfn(s):
    return tuple(int(x) for x in s.split("."))


latest = sorted(cand, key=keyfn)[-1]
print(latest)
