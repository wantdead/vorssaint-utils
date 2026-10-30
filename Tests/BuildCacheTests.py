#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "Tools/build-cache.py"


class BuildCacheTests(unittest.TestCase):
    def test_cache_invalidates_changed_inputs_outputs_and_toolchain(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "inputs"
            source.mkdir()
            nested = source / "source.swift"
            nested.write_text("original")
            output = root / "binary"
            output.write_text("compiled")
            manifest = root / "cache.json"
            def call(operation, context="swift version 1"):
                return subprocess.run(["python3", str(SCRIPT), operation, "--manifest", str(manifest),
                    "--context", context, "--inputs", str(source), "--outputs", str(output)],
                    capture_output=True, check=False).returncode
            self.assertEqual(call("check"), 1)
            self.assertEqual(call("record"), 0)
            self.assertEqual(call("check"), 0)
            timestamp = nested.stat().st_mtime_ns
            nested.write_text("modified")
            os.utime(nested, ns=(timestamp, timestamp))
            self.assertEqual(call("check"), 1)
            self.assertEqual(call("record"), 0)
            self.assertEqual(call("check", "swift version 2"), 1)
            addition = source / "new.swift"
            addition.write_text("new input")
            self.assertEqual(call("check"), 1)
            addition.unlink()
            self.assertEqual(call("check"), 0)
            output.write_text("different artifact")
            self.assertEqual(call("check"), 1)
            self.assertEqual(call("record"), 0)
            output.unlink()
            self.assertEqual(call("check"), 1)
            output.write_text("different artifact")
            manifest.write_text("corrupt manifest")
            self.assertEqual(call("check"), 1)
            manifest.unlink()
            output.unlink()
            self.assertEqual(call("prepare"), 1)
            nested.write_text("edited while compiler runs")
            output.write_text("built from older input")
            self.assertEqual(call("record"), 0)
            self.assertFalse(manifest.exists())
            self.assertEqual(call("check"), 1)


if __name__ == "__main__":
    unittest.main()
