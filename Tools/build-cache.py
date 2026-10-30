#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
"""Cache Developer build artifacts by input, toolchain, and output content."""

import argparse
import hashlib
import json
from pathlib import Path
import tempfile


def fingerprint(paths):
    digest = hashlib.sha256()
    for entry in sorted(paths):
        root = Path(entry)
        if not root.exists():
            raise FileNotFoundError(entry)
        files = sorted(p for p in root.rglob("*") if p.is_file()) if root.is_dir() else [root]
        digest.update(str(root).encode() + b"\0")
        for path in files:
            digest.update(str(path).encode() + b"\0")
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def write_atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as temp:
        json.dump(value, temp)
        temporary = Path(temp.name)
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("check", "prepare", "record"))
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--context", required=True)
    parser.add_argument("--inputs", nargs="+", required=True)
    parser.add_argument("--outputs", nargs="+", required=True)
    args = parser.parse_args()
    pending = args.manifest.with_suffix(".pending.json")
    try:
        inputs = {"version": 1, "context": args.context, "inputs": fingerprint(args.inputs)}
        if args.operation == "prepare":
            write_atomic(pending, inputs)
        current = dict(inputs, outputs=fingerprint(args.outputs))
        if args.operation in ("check", "prepare"):
            hit = json.loads(args.manifest.read_text()) == current
            if hit and args.operation == "prepare":
                pending.unlink(missing_ok=True)
            return 0 if hit else 1
        if pending.exists():
            expected = json.loads(pending.read_text())
            pending.unlink()
            if expected != inputs:
                print("  inputs changed during compilation; artifact cache skipped")
                return 0
        write_atomic(args.manifest, current)
        return 0
    except (OSError, ValueError):
        if args.operation in ("check", "prepare"):
            return 1
        raise


if __name__ == "__main__":
    raise SystemExit(main())
