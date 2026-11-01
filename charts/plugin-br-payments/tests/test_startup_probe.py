#!/usr/bin/env python3
"""Offline render check: the boot window (connect 30s + migrations up to 300s) is covered by a startupProbe."""
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

CHART = Path(__file__).resolve().parents[1]
VALUES = """
app:
  configmap:
    BTG_API_BASE_URL: https://btg.example.test
    BTG_AUTH_URL: https://btg.example.test/token
    MIDAZ_LEDGER_URL: http://midaz:3000
    ORGANIZATION_IDS: 00000000-0000-0000-0000-000000000001
  secrets:
    PROVIDER_CLIENT_ID: x
    PROVIDER_CLIENT_SECRET: x
    PLUGIN_AUTH_CLIENT_ID: x
    PLUGIN_AUTH_CLIENT_SECRET: x
    LICENSE_KEY: x
    CONSULT_AUDIT_HMAC_KEY: 0123456789abcdef0123456789abcdef
    BTG_WEBHOOK_HMAC_SECRET: 0123456789abcdef0123456789abcdef
    INTERNAL_API_KEY: 0123456789abcdef0123456789abcdef
    CREDENTIAL_ENCRYPTION_KEY: MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=
"""
BOOT_BUDGET_SECONDS = 30 + 300


def container():
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml') as f:
        f.write(VALUES)
        f.flush()
        out = subprocess.run(['helm', 'template', 't', str(CHART), '-f', f.name],
                             text=True, capture_output=True, check=True).stdout
    dep = next(d for d in yaml.safe_load_all(out) if d and d['kind'] == 'Deployment')
    return dep['spec']['template']['spec']['containers'][0]


class StartupProbe(unittest.TestCase):
    def test_startup_probe_covers_boot_budget_on_liveness_path(self):
        c = container()
        sp = c.get('startupProbe')
        self.assertIsNotNone(sp, 'liveness would kill the pod mid-migration')
        self.assertEqual(sp['httpGet']['path'], c['livenessProbe']['httpGet']['path'])
        self.assertGreaterEqual(sp['failureThreshold'] * sp['periodSeconds'], BOOT_BUDGET_SECONDS)


if __name__ == '__main__':
    unittest.main()
