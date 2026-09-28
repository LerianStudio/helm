"""Offline contracts; only synthetic credentials and mocked git/Helm/kubectl."""

import base64
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / ".github/scripts/plugin-access-manager-install-preflight.sh"
INSTALL = ROOT / ".github/scripts/install-test.sh"
WORKFLOW = ROOT / ".github/workflows/helm-install-test.yml"
KEY_NAME = "PLUGIN_ACCESS_MANAGER_CI_LICENSE_KEY"
ORG_NAME = "PLUGIN_ACCESS_MANAGER_CI_ORGANIZATION_IDS"
KEY = 'CANARY-LICENSE-"quoted"\\literal\nSECOND-CANARY-LINE'
ORG = "CANARY-ORG-ONE,CANARY-ORG-TWO"
SECRETS = {KEY_NAME: KEY, ORG_NAME: ORG}


def clean_env():
    # Do not read or forward ambient credentials, kubeconfig, or Docker config.
    return {"PATH": "/usr/local/bin:/usr/bin:/bin", "HOME": "/nonexistent"}


MOCK = r'''#!/usr/bin/env python3
import base64, io, json, os, pathlib, signal, sys, tarfile, time
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["MOCK_ROOT"])
record = {"tool": name, "args": args, "credential_env": any(k.startswith("PLUGIN_ACCESS_MANAGER_CI_") for k in os.environ)}
if name == "helm":
    files = [pathlib.Path(args[i+1]) for i, arg in enumerate(args) if arg == "-f"]
    record["files"] = [{"path": str(p), "mode": p.stat().st_mode & 0o777, "data": json.loads(p.read_text())} for p in files]
with (root / "calls.jsonl").open("a") as stream:
    stream.write(json.dumps(record) + "\n")
if name == "git":
    if args[0] == "cat-file":
        sys.exit(1 if os.environ.get("MOCK_NO_BASE") else 0)
    if args[0] == "show":
        print(json.dumps({"revision": "baseline", "fixture": args[1]}))
    if args[0] == "archive":
        data = b"apiVersion: v2\nname: plugin-access-manager\nversion: 1.0.0\n"
        with tarfile.open(fileobj=sys.stdout.buffer, mode="w|") as tar:
            info = tarfile.TarInfo(args[2] + "/Chart.yaml")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
elif name == "helm":
    op = args[0]
    # Simulate accidental output of raw/encoded values by tools and workloads.
    overlays = [f["data"] for f in record["files"] if "auth" in f["data"]]
    if overlays:
        (root / "overlay-copy.json").write_text(json.dumps(overlays[-1]))
    if op in ("install", "upgrade"):
        if overlays:
            for value in overlays[-1]["auth"]["secrets"].values():
                print(value)
                print(value, file=sys.stderr)
                print(base64.b64encode(value.encode()).decode())
                print(json.dumps(value))
        stage = ("base" if args[1].endswith("-base") else "pr") + "-" + op
        if os.environ.get("MOCK_FAIL") == stage:
            print("invalid license: failed pre-install: denied")
            sys.exit(1)
        if os.environ.get("MOCK_PAUSE") == stage:
            (root / "paused").touch()
            time.sleep(0.3)
    if op == "dependency" and os.environ.get("MOCK_FAIL") == "dependency":
        sys.exit(1)
    if op == "status":
        print('{"info":{"status":"deployed"}}')
    if op == "template":
        print("apiVersion: v1\nkind: Secret\nmetadata:\n  namespace: it-plugin-access-manager")
elif name == "kubectl":
    if args[:2] == ["get", "ns"]:
        if any("jsonpath" in arg for arg in args):
            print("Active")
        else:
            sys.exit(1)
    elif args[:2] == ["get", "all"]:
        print("pod/test Running")
    elif args[:2] == ["get", "pods"]:
        print("test 0/1 CrashLoopBackOff")
    elif args[0] == "logs" and (root / "overlay-copy.json").exists():
        for value in json.loads((root / "overlay-copy.json").read_text())["auth"]["secrets"].values():
            print(value)
            print(base64.b64encode(value.encode()).decode())
'''


class CanaryAssertions(unittest.TestCase):
    def assert_no_canaries(self, output):
        for value in (KEY, ORG):
            for token in (value, base64.b64encode(value.encode()).decode(), json.dumps(value)[1:-1], *value.splitlines()):
                self.assertNotIn(token, output)


class LicensePreflightTests(CanaryAssertions, unittest.TestCase):
    def run_preflight(self, *args, env=None):
        return subprocess.run(["bash", "-x", str(SCRIPT), *args], capture_output=True,
                              text=True, env={**clean_env(), **(env or {})})

    def test_missing_secret_names_not_values(self):
        for env, missing in (({}, (KEY_NAME, ORG_NAME)), ({KEY_NAME: KEY}, (ORG_NAME,)),
                             ({ORG_NAME: ORG}, (KEY_NAME,)),
                             ({KEY_NAME: " \n", ORG_NAME: ORG}, (KEY_NAME,))):
            with self.subTest(missing=missing):
                result = self.run_preflight("deep", "midaz", "plugin-access-manager", env=env)
                self.assertEqual(result.returncode, 1)
                for name in missing:
                    self.assertIn(name, result.stderr)
                self.assert_no_canaries(result.stdout + result.stderr)

    def test_configured_deep_passes_presence_gate_without_validation_claim(self):
        result = self.run_preflight("deep", "plugin-access-manager", env=SECRETS)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assert_no_canaries(result.stderr)

    def test_other_scopes_shallow_and_invalid_modes(self):
        for mode in ("deep", "shallow"):
            self.assertEqual(self.run_preflight(mode, "midaz").returncode, 0)
            self.assertEqual(self.run_preflight(mode).returncode, 0)
        result = self.run_preflight("shallow", "plugin-access-manager", env=SECRETS)
        self.assertEqual(result.returncode, 0)
        self.assertIn("readiness are not tested", result.stdout)
        self.assert_no_canaries(result.stdout + result.stderr)
        for args in ((), ("test", "plugin-access-manager")):
            self.assertEqual(self.run_preflight(*args).returncode, 1)

    def test_runtime_flags_cannot_bypass_prerequisites(self):
        result = self.run_preflight("deep", "plugin-access-manager", env={
            "TEST": "true", "ENV": "test", "ENV_NAME": "development",
            "IS_DEVELOPMENT": "true", "LICENSE_KEY": KEY, "ORGANIZATION_IDS": ORG,
            "IT_NO_HOOKS": "1"})
        self.assertEqual(result.returncode, 1)
        self.assert_no_canaries(result.stdout + result.stderr)

    def test_workflow_trust_boundary_and_early_gate(self):
        workflow = WORKFLOW.read_text()
        self.assertNotIn("pull_request_target", workflow)
        self.assertIn("persist-credentials: false", workflow)
        guard = workflow.index("      - name: Check licensed install prerequisites")
        for step in ("Log in to Docker Hub", "Log in to GitHub Container Registry", "Create kind cluster", "Install + upgrade each chart"):
            self.assertLess(guard, workflow.index("      - name: " + step))
        for name in (KEY_NAME, ORG_NAME):
            lines = [line.strip() for line in workflow.splitlines() if line.strip().startswith(name + ":")]
            self.assertEqual(len(lines), 2)
            for line in lines:
                self.assertEqual(line, name + ": ${{ github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository && !github.event.pull_request.head.repo.fork && secrets." + name + " || '' }}")
        block = workflow[guard:].split("\n      - name: ", 1)[0]
        self.assertNotIn("continue-on-error", block)
        self.assertIn("github.event.pull_request.head.repo.full_name != github.repository", block)
        run = block.split("        run: |\n", 1)[1]
        script = "\n".join(line[10:] for line in run.splitlines() if line.strip())
        for mode, env, expected in (("deep", {}, 1), ("deep", SECRETS, 0), ("shallow", {}, 0)):
            result = subprocess.run(["bash", "-c", script], cwd=ROOT, capture_output=True, text=True,
                                    env={**clean_env(), **env, "CHARTS": "midaz plugin-access-manager", "MODE": mode})
            self.assertEqual(result.returncode, expected, result.stderr)
        allowlist = (ROOT / ".github/configs/helm-install-test-allow-failure.txt").read_text()
        self.assertFalse(any(line.split() and line.split()[0] == "plugin-access-manager" for line in allowlist.splitlines()))


class InstallProvisioningTests(CanaryAssertions, unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="am-licensed-ci-", dir=os.environ.get("TMPDIR"))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        mock = self.bin / "mock.py"
        mock.write_text(MOCK)
        mock.chmod(0o755)
        for name in ("git", "helm", "kubectl"):
            (self.bin / name).symlink_to(mock)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        (self.root / "docker.json").write_text('{}')
        for chart in ("plugin-access-manager", "unrelated"):
            directory = self.root / "charts" / chart
            directory.mkdir(parents=True)
            (directory / "Chart.yaml").write_text("apiVersion: v2\nname: " + chart + "\nversion: 1.0.0\n")
            for fixture in ("helm-render-values", "helm-install-values"):
                directory = self.root / ".github/configs" / fixture
                directory.mkdir(parents=True, exist_ok=True)
                (directory / (chart + ".yaml")).write_text(json.dumps({"revision": "pr", "fixture": fixture}))
        self.env = {**clean_env(), **SECRETS, "PATH": str(self.bin) + ":" + clean_env()["PATH"],
                    "RUNNER_TEMP": str(self.runtime), "TMPDIR": str(self.runtime), "MOCK_ROOT": str(self.root),
                    "IT_PULL_SECRET": "synthetic-registry", "IT_DOCKERCONFIG": str(self.root / "docker.json")}

    def run_install(self, chart="plugin-access-manager", extra=None, explicit=False, terminate=False):
        env = {**self.env, **(extra or {})}
        args = ["bash", "-x", str(INSTALL), "charts/" + chart]
        if explicit:
            path = self.root / "explicit.json"
            path.write_text('{"revision":"explicit"}')
            args.append(str(path))
        process = subprocess.Popen(args, cwd=self.root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if terminate:
            for _ in range(200):
                if (self.root / "paused").exists() or process.poll() is not None:
                    break
                time.sleep(0.02)
            self.assertTrue((self.root / "paused").exists())
            process.send_signal(signal.SIGTERM)
        stdout, stderr = process.communicate(timeout=30)
        self.assert_no_canaries(stdout + stderr)
        self.assertEqual(list(self.runtime.glob("access-manager-license-*")), [])
        calls = self.root / "calls.jsonl"
        records = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
        return process.returncode, records, stdout + stderr

    def test_overlay_on_all_install_upgrade_and_template_arms(self):
        rc, records, logs = self.run_install()
        self.assertEqual(rc, 0, logs)
        operations = [r for r in records if r["tool"] == "helm" and r["args"][0] in ("install", "upgrade")]
        self.assertEqual([r["args"][:2] for r in operations], [
            ["install", "plugin-access-manager"], ["upgrade", "plugin-access-manager"],
            ["install", "plugin-access-manager-base"], ["upgrade", "plugin-access-manager-base"]])
        overlays = set()
        for record in records:
            if record["tool"] in ("helm", "kubectl"):
                self.assertFalse(record["credential_env"])
            if record["tool"] != "helm" or record["args"][0] not in ("install", "upgrade", "template"):
                continue
            self.assertEqual(len(record["files"]), 3)
            overlay = record["files"][-1]
            self.assertEqual(overlay["mode"], 0o600)
            self.assertEqual(Path(overlay["path"]).parent, self.runtime)
            self.assertEqual(overlay["data"], {part: {"secrets": {"LICENSE_KEY": KEY, "ORGANIZATION_IDS": ORG}} for part in ("auth", "identity")})
            overlays.add(overlay["path"])
            baseline = record["args"][0] == "install" and record["args"][1].endswith("-base")
            if record["args"][0] != "template":
                for fixture in record["files"][:-1]:
                    self.assertEqual(fixture["data"]["revision"], "baseline" if baseline else "pr")
                self.assertIn("--wait", record["args"])
                self.assertNotIn("--no-hooks", record["args"])
        self.assertEqual(len(overlays), 1)

    def test_explicit_values_do_not_replace_baseline_fixtures(self):
        rc, records, logs = self.run_install(explicit=True)
        self.assertEqual(rc, 0, logs)
        for record in records:
            if record["tool"] != "helm" or record["args"][0] not in ("install", "upgrade"):
                continue
            baseline = record["args"][:2] == ["install", "plugin-access-manager-base"]
            self.assertEqual(len(record["files"]), 3 if baseline else 2)
            self.assertEqual(record["files"][0]["data"]["revision"], "baseline" if baseline else "explicit")

    def test_failures_stay_failures_and_cleanup_redacts_diagnostics(self):
        for stage in ("dependency", "pr-install", "pr-upgrade", "base-install", "base-upgrade"):
            with self.subTest(stage=stage):
                rc, _, logs = self.run_install(extra={"MOCK_FAIL": stage})
                self.assertEqual(rc, 1, logs)
                self.assertIn("::error::", logs)

    def test_term_cleanup(self):
        rc, _, _ = self.run_install(extra={"MOCK_PAUSE": "pr-install"}, terminate=True)
        self.assertEqual(rc, 143)

    def test_missing_secret_fails_before_any_external_command(self):
        rc, records, logs = self.run_install(extra={KEY_NAME: ""})
        self.assertEqual(rc, 1)
        self.assertEqual(records, [])
        self.assertIn(KEY_NAME, logs)

    def test_invalid_temp_fails_closed(self):
        rc, records, _ = self.run_install(extra={"RUNNER_TEMP": str(self.root / "absent")})
        self.assertEqual(rc, 1)
        self.assertEqual(records, [])

    def test_shallow_ignores_credentials_and_does_not_write_overlay(self):
        rc, records, logs = self.run_install(extra={"IT_PULL_SECRET": ""})
        self.assertEqual(rc, 0, logs)
        self.assertIn("readiness are not tested", logs)
        for record in records:
            self.assertFalse(record["credential_env"])
            self.assertFalse(any("auth" in f["data"] for f in record.get("files", [])))
            if record["tool"] == "helm" and record["args"][0] in ("install", "upgrade"):
                self.assertIn("--no-hooks", record["args"])
                self.assertNotIn("--wait", record["args"])

    def test_unrelated_chart_never_receives_license_overlay(self):
        rc, records, logs = self.run_install(chart="unrelated")
        self.assertEqual(rc, 0, logs)
        for record in records:
            self.assertFalse(record["credential_env"])
            self.assertFalse(any("auth" in f["data"] for f in record.get("files", [])))

    def test_new_chart_still_cleans_up(self):
        rc, records, logs = self.run_install(extra={"MOCK_NO_BASE": "1"})
        self.assertEqual(rc, 0, logs)
        self.assertIn("new chart", logs)
        self.assertEqual(sum(r["tool"] == "helm" and r["args"][0] == "install" for r in records), 1)


if __name__ == "__main__":
    unittest.main()
