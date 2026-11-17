"""Tests for chart-bump-checks.sh, the CI read that stands in front of an --admin merge.

A regression that turns an unreadable or failing read into "green" would merge over CI, so
each verdict is pinned here. A stub `gh` on PATH replays canned `gh pr checks` answers.

    python3 -m unittest discover -s .github/scripts -p 'test_*.py'
"""

import json
import os
import subprocess
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chart-bump-checks.sh")
REQUIRED = "Install + upgrade (kind)\nChart Image Refs"
GREEN = [
    {"name": "Install + upgrade (kind)", "bucket": "pass"},
    {"name": "Chart Image Refs", "bucket": "pass"},
    {"name": "Socket Security: Pull Request Alerts", "bucket": "pass"},
]


class ChecksVerdict(unittest.TestCase):
    def verdict(self, *answers):
        """Each answer is a checks list, or None for a failed `gh` call; the last one repeats."""
        with tempfile.TemporaryDirectory() as tmp:
            for i, answer in enumerate(answers):
                with open(os.path.join(tmp, f"answer{i}"), "w") as f:
                    f.write("FAIL" if answer is None else json.dumps(answer))
            stub = os.path.join(tmp, "gh")
            with open(stub, "w") as f:
                f.write(
                    "#!/usr/bin/env bash\n"
                    f'dir="{tmp}"; n=$(cat "$dir/count" 2>/dev/null || echo 0)\n'
                    f'[ "$n" -ge {len(answers)} ] && n={len(answers) - 1}\n'
                    'echo $((n + 1)) > "$dir/count"\n'
                    'a=$(cat "$dir/answer$n"); [ "$a" = FAIL ] && exit 1; echo "$a"\n'
                )
            os.chmod(stub, 0o755)
            env = {
                **os.environ,
                "PATH": f"{tmp}:{os.environ['PATH']}",
                "REPO": "o/r", "PR_NUMBER": "1",
                "REQUIRED_CHECKS": REQUIRED,
                "IGNORED_CHECKS": '["Merge routine bump"]',
                "NON_BLOCKING_PENDING": '["Validate PR title"]',
            }
            # The retry sleeps are cut short so the suite stays fast.
            out = subprocess.run(
                ["bash", "-c", f'sleep() {{ :; }}; export -f sleep; bash "{SCRIPT}"'],
                env=env, capture_output=True, text=True, check=True,
            ).stdout
            return out.strip().splitlines()[-1]

    def test_all_green(self):
        self.assertEqual(self.verdict(GREEN), "green")

    def test_failed_read_then_recovered(self):
        self.assertEqual(self.verdict(None, GREEN), "green")

    def test_exhausted_reads_are_pending_not_green(self):
        self.assertEqual(self.verdict(None, None, None), "pending")

    def test_failed_check(self):
        self.assertEqual(self.verdict(GREEN + [{"name": "triage", "bucket": "fail"}]), "failed")

    def test_cancelled_check(self):
        self.assertEqual(self.verdict(GREEN + [{"name": "x", "bucket": "cancel"}]), "failed")

    def test_missing_required_check(self):
        self.assertEqual(self.verdict(GREEN[1:]), "pending")

    def test_skipped_required_check(self):
        self.assertEqual(self.verdict([{"name": "Install + upgrade (kind)", "bucket": "skipping"}] + GREEN[1:]), "pending")

    def test_other_check_pending(self):
        self.assertEqual(self.verdict(GREEN + [{"name": "Socket", "bucket": "pending"}]), "pending")

    def test_non_blocking_pending(self):
        self.assertEqual(self.verdict(GREEN + [{"name": "Validate PR title", "bucket": "pending"}]), "green")

    def test_non_blocking_failure_blocks(self):
        self.assertEqual(self.verdict(GREEN + [{"name": "Validate PR title", "bucket": "fail"}]), "failed")

    def test_ignored_check_is_left_out(self):
        self.assertEqual(self.verdict(GREEN + [{"name": "Merge routine bump", "bucket": "pending"}]), "green")


if __name__ == "__main__":
    unittest.main()
