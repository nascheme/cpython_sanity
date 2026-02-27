#!/usr/bin/env python3
import sys, json, urllib.request, re
import argparse

URL = "https://www.python.org/api/v2/downloads/release/?is_published=true"

parser = argparse.ArgumentParser(
    description="Find latest Python version for a given major.minor prefix (e.g. 3.14)"
)
parser.add_argument(
    "prefix",
    nargs="?",
    default="3.14",
    help="Version prefix to search for (e.g. 3.14)",
)
parser.add_argument(
    "--pre-release",
    action="store_true",
    help="Include alpha/beta/rc versions (e.g. 3.15.0a1, 3.15.0b2, 3.15.0rc1)",
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
if args.pre_release:
    # Match stable (3.14.1) and pre-release (3.14.0a1, 3.14.0b2, 3.14.0rc1)
    pat = re.compile(
        r"^Python " + re.escape(prefix) + r"\.[0-9]+(?:(?:a|b|rc)[0-9]+)?$"
    )
else:
    # Match only stable releases (3.14.1)
    pat = re.compile(r"^Python " + re.escape(prefix) + r"\.[0-9]+$")

for n in names:
    if pat.match(n):
        cand.append(n.replace("Python ", ""))

if not cand:
    sys.exit(0)

# Pre-release ordering: alpha < beta < rc < stable
_PRE_ORDER = {"a": 0, "b": 1, "rc": 2}
_PRE_RE = re.compile(r"^(\d+\.\d+\.\d+)(?:(a|b|rc)(\d+))?$")


def keyfn(s):
    m = _PRE_RE.match(s)
    if not m:
        return (0,)
    base = tuple(int(x) for x in m.group(1).split("."))
    if m.group(2) is None:
        # Stable release sorts after all pre-releases
        return base + (3, 0)
    return base + (_PRE_ORDER[m.group(2)], int(m.group(3)))


latest = sorted(cand, key=keyfn)[-1]
print(latest)
