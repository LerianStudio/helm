"""Offline startup-contract regression tests; run after helm dependency build.

Uses real Helm, PyYAML and synthetic fixtures only. No cluster or credentials.
"""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from typing import Any

import yaml


CHART = Path(__file__).resolve().parents[1]
ROOT = CHART.parents[1]
FIXTURE = ROOT / ".github/configs/helm-render-values/plugin-access-manager.yaml"
TRUE_FLAGS = (True, "1", "t", "T", "TRUE", "true", "True")
FALSE_FLAGS = (False, "0", "f", "F", "FALSE", "false", "False")


class UniqueKeyLoader(yaml.SafeLoader):
    """Do not let duplicate YAML keys hide a second configuration source."""

    def construct_mapping(self, node, deep=False):
        keys = [self.construct_object(key, deep=deep) for key, _ in node.value]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate YAML mapping key")
        return super().construct_mapping(node, deep=deep)


class StartupValidation(unittest.TestCase):
    def render(self, values, error=None):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "values.json"
            fixture.write_text(json.dumps(values))
            result = subprocess.run(
                ["helm", "template", "startup-test", str(CHART), "-f", str(FIXTURE), "-f", str(fixture)],
                capture_output=True, text=True, check=False,
            )
        if error:
            self.assertNotEqual(result.returncode, 0)
            expected_errors = (error,) if isinstance(error, str) else error
            self.assertTrue(any(message in result.stderr for message in expected_errors), result.stderr)
        else:
            self.assertEqual(result.returncode, 0, result.stderr)
            for document in yaml.load_all(result.stdout, Loader=UniqueKeyLoader):
                if document and document.get("kind") == "ConfigMap":
                    for key, value in document.get("data", {}).items():
                        self.assertIsInstance(value, str, f"ConfigMap data.{key} must be a string")
        return result.stdout

    def assert_configmap_value(self, output, component, key, expected):
        maps = [
            document["data"]
            for document in yaml.load_all(output, Loader=UniqueKeyLoader)
            if document and document.get("kind") == "ConfigMap"
            and document["metadata"]["name"] == f"startup-test-{component}"
        ]
        self.assertEqual(len(maps), 1, f"expected one {component} ConfigMap")
        self.assertIsInstance(maps[0][key], str)
        self.assertEqual(maps[0][key], expected)

    @staticmethod
    def production() -> dict[str, Any]:
        return {
            "global": {"env": {"name": "production"}},
            "auth": {"configmap": {"AUTHORIZER_ADDRESS": "https://idp.example.test"}},
            "identity": {"configmap": {"AUTHORIZER_ADDRESS": "https://idp.example.test"}},
        }

    def test_default_and_explicit_nonproduction(self):
        self.render({})
        for env in ("development", "staging", "local", " DEVELOPMENT "):
            with self.subTest(env=env):
                self.render({"global": {"env": {"name": env}}})

    def test_production_and_unknown_environment_reject_http(self):
        for env in ("production", "prod", "prd", "unknown", "   "):
            with self.subTest(env=env):
                self.render({"global": {"env": {"name": env}}}, "requires an HTTPS JWKS upstream")

    def test_both_components_need_valid_transport(self):
        self.render(self.production())
        for component in ("auth", "identity"):
            for url in ("http://idp.example.test", "https:///missing-host", "ftp://idp.example.test"):
                with self.subTest(component=component, url=url):
                    values = self.production()
                    values[component]["configmap"]["AUTHORIZER_ADDRESS"] = url
                    self.render(values, f"{component}: ENV_NAME")

    def test_native_environment_precedence(self):
        values = self.production()
        values["global"]["env"]["name"] = "development"
        values["identity"]["configmap"] = {"ENV_NAME": "production"}
        self.render(values, "identity: ENV_NAME")
        values = self.production()
        for component in ("auth", "identity"):
            values[component]["configmap"] = {"ENV_NAME": "local"}
        self.render(values)

    def test_identity_jwks_override_independent_of_inversion(self):
        for inversion in ("false", "true"):
            values = self.production()
            values["identity"]["configmap"] = {
                "AUTH_M2M_INVERSION_ENABLED": inversion,
                "AUTH_M2M_JWKS_URL": "https://keys.example.test/jwks",
            }
            self.render(values)
            values["identity"]["configmap"]["AUTH_M2M_JWKS_URL"] = "http://keys.example.test/jwks"
            self.render(values, "identity: ENV_NAME")
        values = self.production()
        values["identity"]["extraEnvVars"] = {"AUTH_M2M_JWKS_URL": "http://keys.example.test/jwks"}
        self.render(values, "identity: ENV_NAME")

    def test_identity_auth_enabled_preserves_boolean_forms(self):
        for flag in FALSE_FLAGS:
            values = self.production()
            values["identity"]["configmap"] = {"AUTH_ENABLED": flag}
            output = self.render(values)
            expected = str(flag).lower() if isinstance(flag, bool) else flag
            self.assert_configmap_value(output, "identity", "PLUGIN_AUTH_ENABLED", expected)
        for flag in TRUE_FLAGS:
            values = self.production()
            values["identity"]["configmap"] = {"AUTH_ENABLED": flag}
            self.render(values, "identity: ENV_NAME")

    def test_production_chart_requires_https_even_for_loopback(self):
        # Deliberately stricter than lib-auth: no Helm IP/loopback classifier.
        for host in ("localhost", "127.0.0.1", "127.999.1.1", "127.00.0.1",
                     "[::1]", "[0:0:0:0:0:0:0:1]", "[::ffff:127.0.0.1]",
                     "[::ffff:7f00:1]", "[0:0:0:0:0:ffff:7f00:1]"):
            for component, key in (("auth", "AUTHORIZER_ADDRESS"),
                                   ("identity", "AUTHORIZER_ADDRESS"),
                                   ("identity", "AUTH_M2M_JWKS_URL")):
                with self.subTest(host=host, component=component, key=key):
                    values = self.production()
                    values[component]["configmap"][key] = f"http://{host}:8000/jwks"
                    self.render(values, "The chart requires HTTPS even for loopback URLs")

    def test_url_authority_boundaries(self):
        for component, key in (("auth", "AUTHORIZER_ADDRESS"),
                               ("identity", "AUTHORIZER_ADDRESS"),
                               ("identity", "AUTH_M2M_JWKS_URL")):
            for url in ("https://:443", "https://:443/jwks", "https://user@:443/jwks",
                        "https://[]:443/jwks", "https:///jwks", "https:/jwks"):
                with self.subTest(component=component, key=key, url=url):
                    values = self.production()
                    values[component]["configmap"][key] = url
                    # Newer Go URL parsers reject empty IPv6 before Helm's
                    # hostname check; older versions reach the chart guard.
                    error = ("with a non-empty hostname", "unable to parse url") if "[]" in url else "with a non-empty hostname"
                    self.render(values, error)
            for host in ("idp.example.test", "localhost", "127.0.0.1", "[::1]",
                         "[0:0:0:0:0:0:0:1]", "[::ffff:127.0.0.1]"):
                with self.subTest(component=component, key=key, host=host):
                    values = self.production()
                    values[component]["configmap"][key] = f"https://{host}:443/jwks"
                    self.render(values)

    def test_auth_discovery_defers_only_effective_enabled_static_address(self):
        # lib-service-discovery v2.0.0 anyEnvTrue is exact "true", NOT ParseBool.
        for flag in TRUE_FLAGS + FALSE_FLAGS + (None, "", "yes", " true "):
            enabled = flag is True or flag == "true"
            with self.subTest(flag=flag):
                values = self.production()
                values["auth"]["configmap"] = {"SD_ENABLED": flag}
                if enabled:
                    output = self.render(values)
                    self.assert_configmap_value(output, "auth", "SD_ENABLED", "true")
                    # Auth still gets its static HTTP fallback; this does not
                    # turn off or rewrite the application's runtime TLS gate.
                    self.assert_configmap_value(output, "auth", "AUTHORIZER_ADDRESS",
                                                "http://startup-test-caradhras:8000")
                    self.assert_configmap_value(output, "auth", "ENV_NAME", "production")
                else:
                    self.render(values, "auth: ENV_NAME")

    def test_legacy_discovery_alias_matches_application(self):
        for flag in ("true", "TRUE", "1", "false", ""):
            with self.subTest(flag=flag):
                values = self.production()
                values["auth"]["configmap"] = {"SD_ENABLED": False}
                values["auth"]["extraEnvVars"] = {"SERVICE_DISCOVERY_ENABLED": flag}
                self.render(values, None if flag == "true" else "auth: ENV_NAME")

    def test_discovery_never_skips_identity_static_validation(self):
        for component in ("auth", "identity"):
            values = self.production()
            values["identity"]["configmap"] = {}
            values[component]["configmap"]["SD_ENABLED"] = True
            self.render(values, "identity: ENV_NAME")
        values = self.production()
        values["auth"]["configmap"] = {"SD_ENABLED": True}
        values["identity"]["extraEnvVars"] = {"SERVICE_DISCOVERY_ENABLED": "true"}
        values["identity"]["configmap"]["AUTH_M2M_JWKS_URL"] = "http://keys.example.test/jwks"
        self.render(values, "identity: ENV_NAME")

    def test_mfa_named_and_legacy_gate_requires_secret(self):
        for channel in ("configmap", "extraEnvVars"):
            for flag in TRUE_FLAGS + FALSE_FLAGS:
                with self.subTest(channel=channel, flag=flag):
                    values = {"auth": {channel: {"MFA_ENABLED": flag}}}
                    if flag in TRUE_FLAGS:
                        self.render(values, "MFA_ENABLED requires")
                        values["auth"]["secrets"] = {"MFA_SECRET": "synthetic-test-only-not-a-real-secret"}
                    output = self.render(values)
                    expected = str(flag).lower() if isinstance(flag, bool) else flag
                    self.assert_configmap_value(output, "auth", "MFA_ENABLED", expected)
            for flag in ("yes", " true ", "TRUEE"):
                self.render({"auth": {channel: {"MFA_ENABLED": flag}}}, "must be a boolean")

    def test_mfa_empty_named_setting_uses_quoted_legacy_flag(self):
        for named in (None, ""):
            for flag in TRUE_FLAGS + FALSE_FLAGS:
                with self.subTest(named=named, flag=flag):
                    values = {"auth": {
                        "configmap": {"MFA_ENABLED": named},
                        "extraEnvVars": {"MFA_ENABLED": flag},
                        "secrets": {"MFA_SECRET": "synthetic-test-only-not-a-real-secret"},
                    }}
                    output = self.render(values)
                    expected = str(flag).lower() if isinstance(flag, bool) else flag
                    self.assert_configmap_value(output, "auth", "MFA_ENABLED", expected)

    def test_mfa_existing_secret_is_offline_reference_only(self):
        values = {"auth": {"configmap": {"MFA_ENABLED": True}, "useExistingSecret": True}}
        self.render(values, "MFA_ENABLED requires auth.existingSecretName")
        values["auth"]["existingSecretName"] = "operator-managed-auth"
        output = self.render(values)
        self.assertIn("name: operator-managed-auth", output)

    def test_duplicate_and_plaintext_secret_sources_rejected(self):
        for component in ("auth", "identity"):
            for key in (("ENV_NAME", "AUTHORIZER_ADDRESS", "SD_ENABLED", "PLUGIN_AUTH_ENABLED") if component == "identity" else ("ENV_NAME", "AUTHORIZER_ADDRESS", "SD_ENABLED")):
                with self.subTest(component=component, key=key):
                    self.render({component: {"extraEnvVars": {key: "value"}}}, "duplicates a chart-owned")
        self.render({"auth": {"extraEnvVars": {"MFA_SECRET": "never-log-this-value"}}}, "must not be stored")
        self.render({"auth": {"configmap": {"MFA_ENABLED": True}, "extraEnvVars": {"MFA_ENABLED": False}}}, "MFA_ENABLED is set both")
        self.render({"identity": {"configmap": {"AUTH_M2M_JWKS_URL": "https://a.test/jwks"}, "extraEnvVars": {"AUTH_M2M_JWKS_URL": "https://b.test/jwks"}}}, "AUTH_M2M_JWKS_URL is set in both")


if __name__ == "__main__":
    unittest.main()
