"""Historical full-scan guard regressions for main-target release documentation.

This scanner predates --changed-since. These tests certify its full-scan and
repair contracts, not maintenance-branch selection or retarget behavior.
"""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("liquid-guard.py").resolve()
SPEC = importlib.util.spec_from_file_location("liquid_guard", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


class LiquidSyntax(unittest.TestCase):
    def test_plain_and_wrapped_text_are_safe(self):
        for text in ("", "plain\ntext", "{% raw %}{{ .Values.x }}{% endraw %}",
                     "{%- raw -%}{% invalid %}{%- endraw -%}",
                     "{% raw %}{{{% endraw %}\n{% raw %}{%{% endraw %}"):
            with self.subTest(text=text):
                self.assertIsNone(GUARD.offence(text))

    def test_first_unsafe_token_reports_exact_line_and_reason(self):
        for text, line in (("\n{{ .Values.x }}", 2), ("{% invalid %}", 1),
                           ("{% raw %}{{{% endraw %}\n\n{{", 3),
                           ("first\n{% raw %}{{{% endraw %}\n{% bad %}", 3)):
            with self.subTest(text=text):
                self.assertEqual(GUARD.offence(text),
                                 (line, "Liquid syntax outside a raw block"))

    def test_unclosed_raw_reports_its_opening_line(self):
        self.assertEqual(GUARD.offence("\n{% raw %}"),
                         (2, "raw block is never closed"))
        self.assertEqual(GUARD.offence("{% raw %}{{"),
                         (1, "raw block is never closed"))
        self.assertEqual(GUARD.offence("safe\n\n{% raw %}{{"),
                         (3, "raw block is never closed"))

    def test_raw_blocks_do_not_nest(self):
        self.assertEqual(GUARD.offence("{% raw %}{% raw %}{% endraw %}\n{{"),
                         (2, "Liquid syntax outside a raw block"))

    def test_published_path_segments(self):
        for path in ("README.md", "charts/app/docs/UPGRADE.md", "charts/app/a_b.md"):
            self.assertTrue(GUARD.published(path), path)
        for path in (".hidden.md", "_drafts/a.md", "charts/.private/a.md",
                     "charts/app/_notes.md"):
            self.assertFalse(GUARD.published(path), path)


class FullScan(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.env = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull,
                    "GIT_CONFIG_NOSYSTEM": "1"}
        self.git("init", "-q")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, env=self.env,
                              check=True, capture_output=True, text=True).stdout

    def write(self, path, text):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return target

    def scan(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), *args],
                              cwd=self.repo, env=self.env,
                              capture_output=True, text=True)

    def test_cli_selects_only_published_tracked_markdown(self):
        self.write("charts/app/README.md", "# Safe\n")
        self.write("_drafts/bad.md", "{{")
        self.write("charts/.private/bad.md", "{{")
        self.write("notes.txt", "{{")
        self.git("add", ".")
        self.write("untracked.md", "{{")
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "Markdown Liquid Guard: full mode (every published .md tracked by git), 1 file(s) to check\n"
                                        "All 1 checked markdown file(s) are Liquid-safe\n")

    def test_cli_annotates_each_bad_file_and_fails(self):
        self.write("charts/app/a.md", "safe\n{{")
        self.write("charts/app/b.md", "{% raw %}")
        self.git("add", ".")
        result = self.scan()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("::error file=charts/app/a.md,line=2::Liquid syntax outside a raw block.", result.stdout)
        self.assertIn("::error file=charts/app/b.md,line=1::raw block is never closed.", result.stdout)
        self.assertIn("2 markdown file(s) would break or blank out", result.stdout)

    def test_main_returns_failure_and_safe_status(self):
        target = self.write("README.md", "\n{{")
        with patch.object(GUARD, "published", return_value=True), patch.object(GUARD.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, str(target))) as run:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(GUARD.main([]), 1)
            run.assert_called_once_with(["git", "ls-files", "-z", "--", "*.md"], check=True,
                                        capture_output=True, text=True)
            self.assertIn("line=2::Liquid syntax outside a raw block", output.getvalue())
            self.assertIn("1 markdown file(s)", output.getvalue())
            target.write_text("safe", encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(GUARD.main([]), 0)
            self.assertEqual(output.getvalue(), "Markdown Liquid Guard: full mode (every published .md tracked by git), 1 file(s) to check\n"
                                                "All 1 checked markdown file(s) are Liquid-safe\n")

    def test_fix_wraps_unicode_and_is_idempotent(self):
        target = self.write("README.md", "# Atualização\n{{ .Values.x }}\n\n")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(GUARD.main(["--fix", str(target)]), 0)
        expected = "<!-- {% raw %} -->\n# Atualização\n{{ .Values.x }}\n<!-- {% endraw %} -->\n"
        self.assertEqual(target.read_text(encoding="utf-8"), expected)
        self.assertEqual(output.getvalue(), f"wrapped {target}\n")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            GUARD.fix(str(target))
        self.assertEqual(target.read_text(encoding="utf-8"), expected)
        self.assertEqual(output.getvalue(), "")
        self.assertIsNone(GUARD.offence(expected))

    def test_fix_removes_old_markers_and_leaves_plain_text_unwrapped(self):
        target = self.write("README.md", "<!-- {% raw %} -->\nplain\n<!-- {% endraw %} -->\n")
        with contextlib.redirect_stdout(io.StringIO()):
            GUARD.fix(str(target))
        self.assertEqual(target.read_text(encoding="utf-8"), "plain\n")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            GUARD.fix(str(target))
        self.assertEqual(output.getvalue(), "")

    def test_fix_handles_inline_markers_and_multiple_files(self):
        first = self.write("a.md", "before {% raw %}{{ x }}{% endraw %} after")
        second = self.write("b.md", "plain")
        result = self.scan("--fix", str(first), str(second))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(first.read_text(encoding="utf-8"),
                         "<!-- {% raw %} -->\nbefore {{ x }} after\n<!-- {% endraw %} -->\n")
        self.assertEqual(second.read_text(encoding="utf-8"), "plain")
        self.assertEqual(result.stdout, f"wrapped {first}\n")


if __name__ == "__main__":
    unittest.main()
