#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the updater against disposable local Git remotes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

UPDATER = Path(__file__).resolve().parents[1] / "Tools/update-local.sh"

class LocalForkUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="vorssaint-update-test-")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.invalid",
                        GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.invalid")
        self.remote = root / "remote.git"
        self.upstream = root / "upstream"
        self.repo = root / "fork"
        self.git(root, "init", "--quiet", "--bare", str(self.remote))
        self.git(root, "init", "--quiet", "-b", "main", str(self.upstream))
        (self.upstream / "Tools").mkdir()
        shutil.copy2(UPDATER, self.upstream / "Tools/update-local.sh")
        (self.upstream / ".gitignore").write_text("/build/\n/calls.log\n/fail-test\n")
        (self.upstream / "shared.txt").write_text("base\n")
        build = self.upstream / "build.sh"
        build.write_text("#!/bin/bash\nset -eu\nprintf '%s\\n' \"$*\" >> calls.log\n"
                         "if [[ \"$*\" == --test* && -e fail-test ]]; then exit 1; fi\n"
                         "mkdir -p build\n"
                         "printf '#!/bin/bash\\nprintf \"metrics %%s\\\\n\" \"$*\" >> calls.log\\n' > build/metrics-tests\n"
                         "printf '#!/bin/bash\\nprintf \"selftest\\\\n\" >> calls.log\\n' > build/VorssaintDeveloper\n"
                         "chmod +x build/metrics-tests build/VorssaintDeveloper\n")
        build.chmod(0o755)
        self.commit(self.upstream, "Initial fixture")
        self.git(self.upstream, "remote", "add", "origin", str(self.remote))
        self.git(self.upstream, "push", "--quiet", "-u", "origin", "main")
        self.git(root, "clone", "--quiet", "-b", "main", str(self.remote), str(self.repo))
        self.git(self.repo, "switch", "--quiet", "-c", "local/omniwm")
        (self.repo / "local.txt").write_text("local integration\n")
        self.commit(self.repo, "Local integration")

    def git(self, cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, env=self.env, check=True,
                              capture_output=True, text=True, timeout=10).stdout.strip()

    def commit(self, repo, message):
        self.git(repo, "add", ".")
        self.git(repo, "commit", "--quiet", "-m", message)

    def incoming(self, conflict=False):
        name = "shared.txt" if conflict else "upstream.txt"
        (self.upstream / name).write_text("upstream change\n")
        self.commit(self.upstream, "Upstream change")
        self.git(self.upstream, "push", "--quiet")

    def run_update(self, *args):
        return subprocess.run([str(self.repo / "Tools/update-local.sh"), *args], cwd=self.repo,
                              env=self.env, capture_output=True, text=True, timeout=15)

    def test_check_does_not_merge_or_build(self):
        self.incoming()
        before = self.git(self.repo, "rev-parse", "HEAD")
        result = self.run_update("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Upstream commits to merge: 1", result.stdout)
        self.assertEqual(before, self.git(self.repo, "rev-parse", "HEAD"))
        self.assertFalse((self.repo / "calls.log").exists())

    def test_merge_preserves_local_commit_and_validates(self):
        self.incoming()
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.repo / "local.txt").exists())
        self.assertTrue((self.repo / "upstream.txt").exists())
        calls = (self.repo / "calls.log").read_text()
        self.assertIn("--test-suite=notch", calls)
        self.assertIn("--dev", calls)
        self.assertIn("selftest", calls)
        self.assertNotIn("--install", calls)
        self.assertEqual(self.git(self.repo, "status", "--porcelain"), "")

    def test_dirty_tree_is_rejected(self):
        (self.repo / "shared.txt").write_text("uncommitted\n")
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Commit or stash", result.stderr)
        self.assertFalse((self.repo / "calls.log").exists())

    def test_conflict_restores_original_head(self):
        (self.repo / "shared.txt").write_text("local change\n")
        self.commit(self.repo, "Conflicting local change")
        before = self.git(self.repo, "rev-parse", "HEAD")
        self.incoming(conflict=True)
        result = self.run_update("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, self.git(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(self.git(self.repo, "status", "--porcelain"), "")
        self.assertFalse((self.repo / ".git/MERGE_HEAD").exists())
        self.assertFalse((self.repo / "calls.log").exists())

    def test_failed_tests_prevent_build_and_install(self):
        (self.repo / "fail-test").touch()
        result = self.run_update("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.repo / "calls.log").read_text().strip(), "--test-suite=notch")

    def test_full_tests_are_opt_in(self):
        result = self.run_update("--full-tests")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "calls.log").read_text().splitlines()[0], "--test")

    def test_install_runs_only_after_validation(self):
        result = self.run_update("--install")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "calls.log").read_text().splitlines(),
                         ["--test-suite=notch", "--dev", "selftest", "--dev --install"])

    def test_wrong_branch_is_rejected(self):
        self.git(self.repo, "switch", "--quiet", "-c", "other")
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Switch to local/omniwm", result.stderr)
        self.assertFalse((self.repo / "calls.log").exists())

if __name__ == "__main__":
    unittest.main()
