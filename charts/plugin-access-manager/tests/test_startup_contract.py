#!/usr/bin/env python3
"""Offline render checks for the v3.9 startup prerequisites. No cluster needed."""
import copy
from pathlib import Path
from typing import Any
import subprocess
import tempfile
import unittest

import yaml

CHART = Path(__file__).resolve().parents[1]
BASE = {
    'auth': {'secrets': {'AUTHORIZER_CLIENT_SECRET': 'render-only'},
             'initUser': {'enabled': False}},
    'identity': {'secrets': {'AUTHORIZER_CLIENT_SECRET': 'render-only'}},
}


class UniqueLoader(yaml.SafeLoader):
    """Reject duplicate keys rather than silently accepting ambiguous env."""


def unique_map(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f'duplicate YAML key: {key}')
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_map)


def merge(target, patch):
    for key, value in patch.items():
        if isinstance(value, dict):
            merge(target.setdefault(key, {}), value)
        else:
            target[key] = value


def render(patch):
    values = copy.deepcopy(BASE)
    merge(values, patch)
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml') as f:
        yaml.safe_dump(values, f)
        f.flush()
        return subprocess.run(['helm', 'template', 'startup-test', str(CHART),
                               '-f', f.name], text=True, capture_output=True)


def production() -> dict[str, Any]:
    return {'global': {'env': {'name': 'production'}},
            'auth': {'configmap': {'AUTHORIZER_ADDRESS': 'https://idp.example.test'}},
            'identity': {'configmap': {'AUTHORIZER_ADDRESS': 'https://idp.example.test'}}}


class StartupContract(unittest.TestCase):
    def succeeds(self, patch):
        result = render(patch)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [d for d in yaml.load_all(result.stdout, Loader=UniqueLoader) if d]

    def fails(self, patch, message):
        result = render(patch)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)

    def test_default_images_and_no_scale_to_zero(self):
        docs = self.succeeds({})
        images = [c['image'] for d in docs if d['kind'] == 'Deployment'
                  for c in d['spec']['template']['spec']['containers']]
        self.assertIn('ghcr.io/lerianstudio/plugin-auth:3.9.0', images)
        self.assertIn('ghcr.io/lerianstudio/plugin-identity:3.9.0', images)
        for d in docs:
            if d['kind'] == 'HorizontalPodAutoscaler':
                self.assertGreaterEqual(d['spec']['minReplicas'], 1)

    def test_production_http_is_rejected(self):
        for env in ['production', 'PRODUCTION', 'qa', 'prod']:
            with self.subTest(env=env):
                self.fails({'global': {'env': {'name': env}}}, 'requires an HTTPS JWKS')

    def test_explicit_dev_allowlist(self):
        for env in ['development', 'staging', 'local', ' STAGING ']:
            with self.subTest(env=env):
                self.succeeds({'global': {'env': {'name': env}}})

    def test_production_https_and_native_precedence(self):
        self.succeeds(production())
        self.fails({'auth': {'configmap': {'ENV_NAME': 'production'}}}, 'auth requires')
        values = production()
        values['auth']['configmap']['ENV_NAME'] = 'development'
        values['auth']['configmap']['AUTHORIZER_ADDRESS'] = 'http://idp.example.test'
        self.succeeds(values)

    def test_identity_checked_even_with_inversion_disabled(self):
        values = production()
        values['identity']['configmap'] = {'AUTH_M2M_INVERSION_ENABLED': 'false'}
        self.fails(values, 'identity requires')

    def test_identity_jwks_override_in_named_or_extra(self):
        for location in ['configmap', 'extraEnvVars']:
            values = production()
            values['identity']['configmap'] = {'AUTHORIZER_ADDRESS': 'http://idp.example.test'}
            values['identity'].setdefault(location, {})['AUTH_M2M_JWKS_URL'] = 'https://idp.example.test/keys'
            self.succeeds(values)

    def test_identity_auth_disabled_does_not_require_jwks(self):
        values = production()
        values['identity']['configmap'] = {'AUTH_ENABLED': 'false'}
        self.succeeds(values)

    def test_boolean_false_matches_actual_template_default(self):
        values = production()
        values['identity']['configmap'] = {'AUTH_ENABLED': False}
        self.fails(values, 'identity requires')

    def test_identity_loopback_contract(self):
        for url in ['http://localhost/keys', 'http://127.0.0.1:8000/keys', 'http://[::1]:8000/keys',
                    'HTTP://localhost:8000/keys', 'http://[0:0:0:0:0:0:0:1]:8000/keys',
                    'http://[::ffff:127.0.0.1]:8000/keys', 'http://localhost?keys=1']:
            values = production()
            values['identity']['configmap']['AUTH_M2M_JWKS_URL'] = url
            self.succeeds(values)
        values = production()
        values['auth']['configmap']['AUTHORIZER_ADDRESS'] = 'http://localhost:8000'
        self.fails(values, 'auth requires')

    def test_discovery_does_not_hide_insecure_fallback(self):
        self.fails({'global': {'env': {'name': 'production'}},
                    'auth': {'configmap': {'SD_ENABLED': 'true'}}}, 'auth requires')

    def test_invalid_https(self):
        for url in ['https://', 'http://idp.test', 'https://bad host', 'https://bad:port/keys']:
            with self.subTest(url=url):
                for component in ['auth', 'identity']:
                    values = production()
                    values[component]['configmap']['AUTHORIZER_ADDRESS'] = url
                    self.assertNotEqual(render(values).returncode, 0)

    def test_ipv6_identity_is_deferred_to_runtime(self):
        values = production()
        values['identity']['configmap']['AUTH_M2M_JWKS_URL'] = 'http://[2001:db8::1]/keys'
        # lib-auth still rejects non-loopback HTTP; rendering is not runtime proof.
        self.succeeds(values)

    def test_extra_mfa_boolean_refused(self):
        self.fails({'auth': {'extraEnvVars': {'MFA_ENABLED': True},
                             'secrets': {'MFA_SECRET': 'test-only'}}}, 'must be a quoted string')

    def test_duplicate_env_refused(self):
        for component in ['auth', 'identity']:
            for key in ['ENV_NAME', 'AUTHORIZER_ADDRESS']:
                self.fails({component: {'extraEnvVars': {key: 'test'}}}, 'duplicates')
        self.fails({'identity': {'extraEnvVars': {'PLUGIN_AUTH_ENABLED': 'false'}}}, 'duplicates')
        self.fails({'identity': {'configmap': {'AUTH_M2M_JWKS_URL': 'https://one.test'},
                                'extraEnvVars': {'AUTH_M2M_JWKS_URL': 'https://two.test'}}}, 'both')

    def test_mfa_without_secret_fails(self):
        for location in ['configmap', 'extraEnvVars']:
            for enabled in [True, 'true', 'TRUE', '1']:
                with self.subTest(location=location, enabled=enabled):
                    message = 'must be a quoted string' if location == 'extraEnvVars' and enabled is True else 'requires a non-empty'
                    self.fails({'auth': {location: {'MFA_ENABLED': enabled}}}, message)

    def test_mfa_secret_is_only_in_secret(self):
        docs = self.succeeds({'auth': {'configmap': {'MFA_ENABLED': 'true'},
                                       'secrets': {'MFA_SECRET': 'render-only-mfa'}}})
        for doc in docs:
            if doc['kind'] == 'ConfigMap':
                self.assertNotIn('MFA_SECRET', doc.get('data', {}))
        self.fails({'auth': {'extraEnvVars': {'MFA_SECRET': 'not-secret-here'}}}, 'is sensitive')

    def test_mfa_external_secret_offline(self):
        values = {'auth': {'useExistingSecret': True, 'existingSecretName': 'operator-auth',
                           'configmap': {'MFA_ENABLED': 'true'}}}
        self.succeeds(values)
        values['auth']['existingSecretName'] = ''
        self.fails(values, 'requires auth.existingSecretName')

    def test_mfa_disabled_or_unset(self):
        self.succeeds({})
        self.succeeds({'auth': {'configmap': {'MFA_ENABLED': 'false'}}})
        self.succeeds({'auth': {'configmap': {'MFA_ENABLED': False}}})

    def test_init_user_post_install_only(self):
        docs = self.succeeds({'auth': {'initUser': {'enabled': True, 'adminPassword': 'render-only'}}})
        jobs = [d for d in docs if d['kind'] == 'Job']
        job = next(d for d in jobs if d['metadata']['name'].endswith('init-user'))
        self.assertEqual(job['metadata']['annotations']['helm.sh/hook'], 'post-install')
        self.assertEqual(job['spec']['template']['spec']['containers'][0]['image'],
                         'ghcr.io/lerianstudio/caradhras-user-init:3.9.0')


if __name__ == '__main__':
    unittest.main()
