"""Regression tests for liquid-guard.py's --changed-since file selection.

The full scan runs in CI on every pull request into main, but the changed-files scope
only runs on pull requests into a maintenance line, so without these tests it would be
proven by nothing but manual runs. Each case builds a throwaway git repository and runs
the script the way the workflow does.

    python3 -m unittest discover -s .github/scripts -p 'test_*.py'
"""

import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "liquid-guard.py")
SAFE = "# Upgrade\n\nPlain text.\n"
UNSAFE = "# Upgrade\n\n    image: {{ .Values.image.tag }}\n"


class ChangedSince(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "test")
        self.git("config", "commit.gpgsign", "false")
        # The base: an inherited doc that breaks the rule, as a seeded maintenance line has.
        self.write("charts/app/docs/UPGRADE-1.0.md", UNSAFE)
        self.write("charts/app/README.md", SAFE)
        self.commit("seed")
        self.base = self.git("rev-parse", "HEAD").strip()

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True, text=True).stdout

    def write(self, path, content):
        full = os.path.join(self.repo, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(content)

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", message)

    def guard(self, *args):
        return subprocess.run([sys.executable, SCRIPT, *args], cwd=self.repo, capture_output=True, text=True)

    def test_full_scan_fails_on_inherited_doc(self):
        result = self.guard()
        self.assertEqual(result.returncode, 1)
        self.assertIn("UPGRADE-1.0.md", result.stdout)

    def test_untouched_inherited_doc_is_not_checked(self):
        self.write("charts/app/README.md", SAFE + "More.\n")
        self.commit("edit readme")
        result = self.guard("--changed-since", self.base)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("1 file(s) to check", result.stdout)

    def test_added_unsafe_doc_fails(self):
        self.write("charts/app/docs/UPGRADE-2.0.md", UNSAFE)
        self.commit("add doc")
        result = self.guard("--changed-since", self.base)
        self.assertEqual(result.returncode, 1)
        self.assertIn("UPGRADE-2.0.md", result.stdout)
        self.assertNotIn("UPGRADE-1.0.md", result.stdout)

    def test_renamed_unsafe_doc_fails_at_its_new_path(self):
        self.git("mv", "charts/app/docs/UPGRADE-1.0.md", "charts/app/docs/UPGRADE-1.1.md")
        self.commit("rename doc")
        result = self.guard("--changed-since", self.base)
        self.assertEqual(result.returncode, 1)
        self.assertIn("UPGRADE-1.1.md", result.stdout)

    def test_deleted_doc_is_not_checked(self):
        self.git("rm", "-q", "charts/app/docs/UPGRADE-1.0.md")
        self.commit("delete doc")
        result = self.guard("--changed-since", self.base)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("0 files scanned", result.stdout)

    def test_unpublished_path_is_not_checked(self):
        self.write("_drafts/notes.md", UNSAFE)
        self.commit("add draft")
        result = self.guard("--changed-since", self.base)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_unknown_ref_fails(self):
        result = self.guard("--changed-since", "no-such-ref")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
