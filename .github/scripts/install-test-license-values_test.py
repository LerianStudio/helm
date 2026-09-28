#!/usr/bin/env python3
"""License fixture regression tests; command doubles never contact a cluster."""
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
REPO = SCRIPTS.parent.parent
VARIABLES = {
    "IT_AUTH_LICENSE_KEY": "test-only-auth-key",
    "IT_AUTH_ORGANIZATION_IDS": "test-only-auth-org",
    "IT_IDENTITY_LICENSE_KEY": "test-only-identity-key",
    "IT_IDENTITY_ORGANIZATION_IDS": "test-only-identity-org",
}


class LicenseValuesTest(unittest.TestCase):
    def run_helper(self, root, values):
        env = {k: v for k, v in os.environ.items() if k not in VARIABLES}
        env.update(values, TMPDIR=str(root))
        return subprocess.run(
            ["python3", str(SCRIPTS / "install-test-license-values.py")],
            env=env, text=True, capture_output=True, check=False,
        )

    def test_requires_each_credential_without_leaking_values(self):
        for name in VARIABLES:
            for missing in ("", " \t\n"):
                with self.subTest(name=name, missing=repr(missing)), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    result = self.run_helper(root, {**VARIABLES, name: missing})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(name, result.stderr)
                    self.assertEqual(result.stdout, "")
                    for value in VARIABLES.values():
                        self.assertNotIn(value, result.stdout + result.stderr)
                    self.assertEqual(list(root.iterdir()), [])

    def test_rejects_empty_members_in_organization_list(self):
        for component in ("AUTH", "IDENTITY"):
            for orgs in (",", "one,", ",one", "one, ,two"):
                with self.subTest(component=component, orgs=orgs), tempfile.TemporaryDirectory() as tmp:
                    name = f"IT_{component}_ORGANIZATION_IDS"
                    result = self.run_helper(Path(tmp), {**VARIABLES, name: orgs})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(name, result.stderr)
                    self.assertEqual(result.stdout, "")

    def test_private_json_overlay_preserves_exact_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            values = {**VARIABLES, "IT_AUTH_LICENSE_KEY": 'test-only:"key"\\with\ncharacters'}
            result = self.run_helper(root, values)
            self.assertEqual(result.returncode, 0, result.stderr)
            path = Path(result.stdout.strip())
            self.assertEqual(path.parent, root)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(json.loads(path.read_text()), {
                component: {"secrets": {
                    field: values[f"IT_{component.upper()}_{field}"]
                    for field in ("LICENSE_KEY", "ORGANIZATION_IDS")
                }} for component in ("auth", "identity")
            })
            for value in values.values():
                self.assertNotIn(value, result.stdout + result.stderr)


class InstallFlowTest(unittest.TestCase):
    def run_install(self, root, *, deep=True, credentials=True, chart="plugin-access-manager", fail_install=False):
        bin_dir = root / "bin"
        bin_dir.mkdir()
        calls = root / "calls.jsonl"
        # These doubles exercise shell argument/lifecycle plumbing, not Helm or Kubernetes.
        double = '''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
overlays = []
for index, arg in enumerate(args[:-1]):
    if arg == "-f":
        path = pathlib.Path(args[index + 1])
        if path.suffix == ".json":
            overlays.append({"path": str(path), "mode": path.stat().st_mode & 0o777,
                             "values": json.loads(path.read_text())})
with open(os.environ["CALLS"], "a") as out:
    out.write(json.dumps({"tool": name, "args": args, "overlays": overlays}) + "\\n")
if name == "helm":
    if args[0] == "status": print('{"info":{"status":"deployed"}}')
    if args[0] == "install" and os.environ.get("FAIL_INSTALL") == "1":
        print("test-only admission failure")
        sys.exit(1)
elif name == "kubectl":
    if args[:2] == ["get", "ns"]:
        if any("jsonpath" in a for a in args): print("Active")
        else: sys.exit(1)
    if args[:2] == ["get", "all"]: print("pod/test-only")
elif name == "git":
    if args[0] == "cat-file":
        sys.exit(0 if args[-1].endswith("Chart.yaml") else 1)
elif name == "tar":
    sys.stdin.buffer.read()
'''
        for name in ("helm", "kubectl", "git", "tar"):
            executable = bin_dir / name
            executable.write_text(double)
            executable.chmod(0o755)
        docker = root / "docker.json"
        docker.write_text('{"auths":{}}')
        env = {k: v for k, v in os.environ.items() if k not in VARIABLES}
        env.update(PATH=str(bin_dir) + os.pathsep + env["PATH"], TMPDIR=str(root),
                   CALLS=str(calls), IT_PULL_SECRET="test-only" if deep else "",
                   IT_DOCKERCONFIG=str(docker), IT_NO_HOOKS="0",
                   FAIL_INSTALL="1" if fail_install else "0")
        if credentials:
            env.update(VARIABLES)
        result = subprocess.run(
            ["bash", str(SCRIPTS / "install-test.sh"), f"charts/{chart}"],
            cwd=REPO, env=env, text=True, capture_output=True, check=False,
        )
        records = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
        return result, records

    def test_deep_missing_license_fails_before_any_cluster_or_helm_call(self):
        with tempfile.TemporaryDirectory() as tmp:
            result, records = self.run_install(Path(tmp), credentials=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("IT_AUTH_LICENSE_KEY", result.stderr + result.stdout)
            self.assertEqual(records, [])

    def test_all_install_and_upgrade_legs_receive_private_runtime_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            result, records = self.run_install(Path(tmp))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            legs = [r for r in records if r["tool"] == "helm" and r["args"][0] in ("install", "upgrade")]
            self.assertEqual(len(legs), 4, legs)
            for leg in legs:
                self.assertEqual(len(leg["overlays"]), 1, leg)
                overlay = leg["overlays"][0]
                self.assertEqual(overlay["mode"], 0o600)
                for component in ("auth", "identity"):
                    self.assertEqual(overlay["values"][component]["secrets"]["LICENSE_KEY"],
                                     VARIABLES[f"IT_{component.upper()}_LICENSE_KEY"])
                    self.assertEqual(overlay["values"][component]["secrets"]["ORGANIZATION_IDS"],
                                     VARIABLES[f"IT_{component.upper()}_ORGANIZATION_IDS"])
                self.assertFalse(Path(overlay["path"]).exists(), "runtime credentials must be removed on exit")
                self.assertIn("--wait", leg["args"])
                self.assertNotIn("--no-hooks", leg["args"])
            for value in VARIABLES.values():
                self.assertNotIn(value, result.stdout + result.stderr)

    def test_failed_install_also_removes_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            result, records = self.run_install(Path(tmp), fail_install=True)
            self.assertNotEqual(result.returncode, 0)
            overlays = [o for r in records for o in r["overlays"]]
            self.assertTrue(overlays)
            for overlay in overlays:
                self.assertFalse(Path(overlay["path"]).exists())

    def test_shallow_and_other_charts_do_not_require_or_inject_license(self):
        for deep, chart in ((False, "plugin-access-manager"), (True, "product-console")):
            with self.subTest(deep=deep, chart=chart), tempfile.TemporaryDirectory() as tmp:
                result, records = self.run_install(Path(tmp), deep=deep, credentials=False, chart=chart)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(records)
                self.assertFalse(any(r["overlays"] for r in records))


if __name__ == "__main__":
    unittest.main()
