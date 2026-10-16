#!/usr/bin/env python3
# setcfg.py <src config.yml> <dst config.yml> key=value ...: sets top-level keys of Vita3K's global config
import sys

src, dst, edits = sys.argv[1], sys.argv[2], sys.argv[3:]
lines = open(src).read().splitlines()
for e in edits:
    key, val = e.split("=", 1)
    hits = [i for i, l in enumerate(lines) if l.startswith(f"{key}:")]
    if not hits:
        sys.exit(f"unknown key {key} in {src}")
    lines[hits[0]] = f"{key}: {val}"
open(dst, "w").write("\n".join(lines) + "\n")
