#!/usr/bin/env python3
"""Offline render checks for the v3.9 startup prerequisites. No cluster needed."""
import base64
import copy
from pathlib import Path
from typing import Any
import subprocess
import tempfile
import unittest

import yaml

CHART = Path(__file__).resolve().parents[1]
BASE = {
    'auth': {'secrets': {'AUTHORIZER_CLIENT_SECRET': 'render-only'}},
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

    def crash_loops(self, patch, *components):
        """validateJwksTls names every failing component in one error."""
        self.fails(patch, f"plugin-access-manager: {' and '.join(components)} would crash-loop")

    def test_default_images_and_no_scale_to_zero(self):
        docs = self.succeeds({})
        images = [c['image'] for d in docs if d['kind'] == 'Deployment'
                  for c in d['spec']['template']['spec']['containers']]
        self.assertIn('ghcr.io/lerianstudio/plugin-auth:3.14.0', images)
        self.assertIn('ghcr.io/lerianstudio/plugin-identity:3.14.0', images)
        self.assertIn('ghcr.io/lerianstudio/caradhras:1.8.6', images)
        init_images = [c['image'] for d in docs if d['kind'] == 'Deployment'
                       for c in d['spec']['template']['spec'].get('initContainers', [])]
        self.assertIn('ghcr.io/lerianstudio/caradhras-migrations:1.8.6', init_images)
        for d in docs:
            if d['kind'] == 'HorizontalPodAutoscaler':
                self.assertGreaterEqual(d['spec']['minReplicas'], 1)

    def test_production_http_is_rejected(self):
        for env in ['production', 'PRODUCTION', 'qa', 'prod']:
            with self.subTest(env=env):
                self.crash_loops({'global': {'env': {'name': env}}}, 'auth', 'identity')

    def test_explicit_dev_allowlist(self):
        for env in ['development', 'staging', 'local', ' STAGING ']:
            with self.subTest(env=env):
                self.succeeds({'global': {'env': {'name': env}}})

    def test_production_https_and_native_precedence(self):
        self.succeeds(production())
        self.crash_loops({'auth': {'configmap': {'ENV_NAME': 'production'}}}, 'auth')
        values = production()
        values['auth']['configmap']['ENV_NAME'] = 'development'
        values['auth']['configmap']['AUTHORIZER_ADDRESS'] = 'http://idp.example.test'
        self.succeeds(values)

    def test_identity_checked_even_with_inversion_disabled(self):
        values = production()
        values['identity']['configmap'] = {'AUTH_M2M_INVERSION_ENABLED': 'false'}
        self.crash_loops(values, 'identity')

    def test_identity_jwks_override_in_named_or_extra(self):
        for location in ['configmap', 'extraEnvVars']:
            values = production()
            values['identity']['configmap'] = {'AUTHORIZER_ADDRESS': 'http://idp.example.test'}
            values['identity'].setdefault(location, {})['AUTH_M2M_JWKS_URL'] = 'https://idp.example.test/keys'
            self.succeeds(values)
            # An http override is caught wherever it is set: extraEnvVars renders
            # into the same ConfigMap the application reads.
            values['identity']['configmap']['AUTHORIZER_ADDRESS'] = 'https://idp.example.test'
            values['identity'][location]['AUTH_M2M_JWKS_URL'] = 'http://idp.example.test/keys'
            self.crash_loops(values, 'identity')

    def test_identity_auth_disabled_does_not_require_jwks(self):
        for disabled in ['false', False]:
            values = production()
            values['identity']['configmap'] = {'AUTH_ENABLED': disabled}
            self.succeeds(values)

    def test_default_true_flags_honor_an_explicit_false(self):
        flags = {'auth': ['ALLOW_INSECURE_TLS', 'RUNNING_IN_DOCKER', 'RATE_LIMIT_ENABLED',
                          'CIRCUIT_BREAKER_ENABLED', 'SWAGGER_ENABLED'],
                 'identity': ['ALLOW_INSECURE_TLS', 'AUTH_ENABLED', 'RATE_LIMIT_ENABLED', 'CIRCUIT_BREAKER_ENABLED']}
        for value, expected in [(False, 'false'), ('false', 'false'), (True, 'true'), (None, 'true'), ('', 'true')]:
            with self.subTest(value=value):
                values = production()
                for component, keys in flags.items():
                    values[component]['configmap'].update(dict.fromkeys(keys, value))
                values['caradhras'] = {'allowInsecureTLS': value}
                config = {d['metadata']['name']: d['data'] for d in self.succeeds(values) if d['kind'] == 'ConfigMap'}
                for component, keys in flags.items():
                    for key in keys:
                        rendered = 'PLUGIN_AUTH_ENABLED' if key == 'AUTH_ENABLED' else key
                        self.assertEqual(config[f'startup-test-{component}'][rendered], expected, key)
                self.assertEqual(config['startup-test-caradhras']['ALLOW_INSECURE_TLS'], expected)

    def test_identity_loopback_contract(self):
        for url in ['http://localhost/keys', 'http://127.0.0.1:8000/keys', 'http://[::1]:8000/keys',
                    'HTTP://localhost:8000/keys', 'http://[0:0:0:0:0:0:0:1]:8000/keys',
                    'http://[::ffff:127.0.0.1]:8000/keys', 'http://localhost?keys=1']:
            values = production()
            values['identity']['configmap']['AUTH_M2M_JWKS_URL'] = url
            self.succeeds(values)
        values = production()
        values['auth']['configmap']['AUTHORIZER_ADDRESS'] = 'http://localhost:8000'
        self.crash_loops(values, 'auth')

    def test_auth_discovery_defers_to_runtime(self):
        # auth validates the discovered address at boot; identity never uses discovery.
        values = {'global': {'env': {'name': 'production'}},
                  'auth': {'configmap': {'SD_ENABLED': 'true'}},
                  'identity': {'configmap': {'AUTHORIZER_ADDRESS': 'https://idp.example.test'}}}
        self.succeeds(values)
        values['identity']['configmap']['SD_ENABLED'] = 'true'
        values['identity']['configmap']['AUTHORIZER_ADDRESS'] = 'http://idp.example.test'
        self.crash_loops(values, 'identity')
        # The legacy lib-service-discovery switch is honored too.
        legacy = {'global': {'env': {'name': 'production'}},
                  'auth': {'extraEnvVars': {'SERVICE_DISCOVERY_ENABLED': 'true'}},
                  'identity': {'configmap': {'AUTHORIZER_ADDRESS': 'https://idp.example.test'}}}
        self.succeeds(legacy)

    def test_invalid_https(self):
        for url in ['http://idp.test', 'ftp://idp.test']:
            with self.subTest(url=url):
                for component in ['auth', 'identity']:
                    values = production()
                    values[component]['configmap']['AUTHORIZER_ADDRESS'] = url
                    self.crash_loops(values, component)
        for url in ['https://bad host', 'https://bad:port/keys']:
            with self.subTest(url=url):
                for component in ['auth', 'identity']:
                    values = production()
                    values[component]['configmap']['AUTHORIZER_ADDRESS'] = url
                    self.fails(values, 'unable to parse url')
        # Outside production the application parses nothing, so neither does the chart.
        self.succeeds({'auth': {'configmap': {'AUTHORIZER_ADDRESS': 'https://bad host'}}})

    def test_ipv6_identity(self):
        for url in ['http://[::1]:8000/keys', 'http://[::ffff:7f00:1]/keys']:
            values = production()
            values['identity']['configmap']['AUTH_M2M_JWKS_URL'] = url
            self.succeeds(values)
        # A non-loopback IPv6 http URL is rejected by lib-auth, so by the chart too.
        values = production()
        values['identity']['configmap']['AUTH_M2M_JWKS_URL'] = 'http://[2001:db8::1]/keys'
        self.crash_loops(values, 'identity')

    def test_image_before_the_gate_is_not_checked(self):
        prod = {'global': {'env': {'name': 'production'}}}
        for tag in ['3.1.0', 'v3.2.9', '3.2.9-rc.1', '3.2.0@sha256:' + '0' * 64]:
            with self.subTest(tag=tag):
                values = copy.deepcopy(prod)
                values['auth'] = {'image': {'tag': tag}}
                values['identity'] = {'image': {'tag': tag}}
                self.succeeds(values)
        for tag in ['3.3.0-beta.1', '3.9.0', 'latest']:
            with self.subTest(tag=tag):
                values = copy.deepcopy(prod)
                values['auth'] = {'image': {'tag': tag}}
                values['identity'] = {'image': {'tag': tag}}
                self.crash_loops(values, 'auth', 'identity')

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

    def identity_data(self, docs, kind):
        name = 'startup-test-identity'
        doc = next((d for d in docs if d['kind'] == kind and d['metadata']['name'] == name), None)
        return None if doc is None else doc.get('data', {})

    def test_google_directory_unset_adds_no_keys(self):
        docs = self.succeeds({})
        for kind in ['Secret', 'ConfigMap']:
            keys = [k for k in self.identity_data(docs, kind) if k.startswith('GOOGLE_DIRECTORY_')]
            self.assertEqual(keys, [], kind)

    def test_google_directory_set_splits_secret_and_config(self):
        docs = self.succeeds({'identity': {
            'configmap': {'GOOGLE_DIRECTORY_ENABLED': 'true',
                          'GOOGLE_DIRECTORY_CLIENT_ID': 'render-only.apps.googleusercontent.com',
                          'GOOGLE_DIRECTORY_REDIRECT_URL': 'https://console.example.test/cb'},
            'secrets': {'GOOGLE_DIRECTORY_CLIENT_SECRET': 'render-only',
                        'GOOGLE_DIRECTORY_ENCRYPTION_KEY': 'render-only-key-of-at-least-32-bytes'}}})
        secret = self.identity_data(docs, 'Secret')
        config = self.identity_data(docs, 'ConfigMap')
        self.assertEqual(base64.b64decode(secret['GOOGLE_DIRECTORY_CLIENT_SECRET']), b'render-only')
        self.assertIn('GOOGLE_DIRECTORY_ENCRYPTION_KEY', secret)
        self.assertEqual(config['GOOGLE_DIRECTORY_ENABLED'], 'true')
        self.assertEqual(config['GOOGLE_DIRECTORY_CLIENT_ID'], 'render-only.apps.googleusercontent.com')
        self.assertEqual(config['GOOGLE_DIRECTORY_REDIRECT_URL'], 'https://console.example.test/cb')
        for key in ['GOOGLE_DIRECTORY_CLIENT_SECRET', 'GOOGLE_DIRECTORY_ENCRYPTION_KEY']:
            self.assertNotIn(key, config)

    def test_google_directory_secret_only_without_flag(self):
        # A secret set ahead of the flag renders and changes nothing else.
        docs = self.succeeds({'identity': {'secrets': {'GOOGLE_DIRECTORY_CLIENT_SECRET': 'render-only'}}})
        self.assertIn('GOOGLE_DIRECTORY_CLIENT_SECRET', self.identity_data(docs, 'Secret'))
        self.assertNotIn('GOOGLE_DIRECTORY_ENCRYPTION_KEY', self.identity_data(docs, 'Secret'))
        self.succeeds({'identity': {'configmap': {'GOOGLE_DIRECTORY_ENABLED': 'false'}}})

    def test_google_directory_enabled_needs_all_values(self):
        for location in ['configmap', 'extraEnvVars']:
            with self.subTest(location=location):
                self.fails({'identity': {location: {'GOOGLE_DIRECTORY_ENABLED': 'true'}}},
                           'GOOGLE_DIRECTORY_ENABLED=true needs a non-empty')
        plain = {'GOOGLE_DIRECTORY_ENABLED': 'true', 'GOOGLE_DIRECTORY_CLIENT_ID': 'id',
                 'GOOGLE_DIRECTORY_REDIRECT_URL': 'https://console.example.test/cb'}
        self.fails({'identity': {'configmap': plain,
                                 'secrets': {'GOOGLE_DIRECTORY_CLIENT_SECRET': 'render-only'}}},
                   'identity.secrets.GOOGLE_DIRECTORY_ENCRYPTION_KEY')

    def test_google_directory_key_length(self):
        values = {'identity': {
            'configmap': {'GOOGLE_DIRECTORY_ENABLED': 'true', 'GOOGLE_DIRECTORY_CLIENT_ID': 'id',
                          'GOOGLE_DIRECTORY_REDIRECT_URL': 'https://console.example.test/cb'},
            'secrets': {'GOOGLE_DIRECTORY_CLIENT_SECRET': 'render-only',
                        'GOOGLE_DIRECTORY_ENCRYPTION_KEY': ' ' + 'k' * 31 + ' '}}}
        self.fails(values, 'at least 32 bytes')
        values['identity']['secrets']['GOOGLE_DIRECTORY_ENCRYPTION_KEY'] = 'k' * 32
        self.succeeds(values)

    def test_google_directory_extra_must_be_string(self):
        for value in [True, 1]:
            with self.subTest(value=value):
                self.fails({'identity': {'extraEnvVars': {'GOOGLE_DIRECTORY_ENABLED': value}}},
                           'must be a quoted string')

    def test_google_directory_existing_secret(self):
        plain = {'GOOGLE_DIRECTORY_ENABLED': 'true', 'GOOGLE_DIRECTORY_CLIENT_ID': 'id',
                 'GOOGLE_DIRECTORY_REDIRECT_URL': 'https://console.example.test/cb'}
        values = {'identity': {'useExistingSecret': True, 'existingSecretName': 'operator-identity',
                               'configmap': plain}}
        docs = self.succeeds(values)
        self.assertIsNone(self.identity_data(docs, 'Secret'))
        values['identity']['existingSecretName'] = ''
        self.fails(values, 'identity.existingSecretName')

    def test_google_directory_secrets_refused_outside_secret(self):
        for location in ['configmap', 'extraEnvVars']:
            for key in ['GOOGLE_DIRECTORY_CLIENT_SECRET', 'GOOGLE_DIRECTORY_ENCRYPTION_KEY']:
                with self.subTest(location=location, key=key):
                    self.fails({'identity': {location: {key: 'not-secret-here'}}}, 'is sensitive')

    def test_google_directory_key_in_one_place(self):
        for key in ['GOOGLE_DIRECTORY_ENABLED', 'GOOGLE_DIRECTORY_CLIENT_ID', 'GOOGLE_DIRECTORY_REDIRECT_URL']:
            with self.subTest(key=key):
                self.fails({'identity': {'configmap': {key: 'one'}, 'extraEnvVars': {key: 'two'}}}, 'both')
        # An explicit false is a value too: extraEnvVars "true" must not override it silently.
        self.fails({'identity': {'configmap': {'GOOGLE_DIRECTORY_ENABLED': False},
                                 'extraEnvVars': {'GOOGLE_DIRECTORY_ENABLED': 'true'}}}, 'both')

    def test_existing_secret_requires_a_name(self):
        for component in ('auth', 'identity'):
            with self.subTest(component=component):
                self.fails({component: {'useExistingSecret': True}},
                           f'{component}.useExistingSecret is true but {component}.existingSecretName is empty')
                docs = self.succeeds({component: {'useExistingSecret': True,
                                                  'existingSecretName': 'operator-secret'}})
                deployment = next(d for d in docs if d['kind'] == 'Deployment'
                                  and d['metadata']['name'].endswith(component))
                refs = [e['secretRef']['name'] for e in
                        deployment['spec']['template']['spec']['containers'][0]['envFrom']
                        if 'secretRef' in e]
                self.assertEqual(refs, ['operator-secret'])

    def test_auth_service_exposes_only_ports_the_container_serves(self):
        docs = self.succeeds({})
        service = next(d for d in docs if d['kind'] == 'Service' and d['metadata']['name'].endswith('-auth'))
        deployment = next(d for d in docs if d['kind'] == 'Deployment' and d['metadata']['name'].endswith('-auth'))
        container_ports = {p['name'] for p in deployment['spec']['template']['spec']['containers'][0]['ports']}
        self.assertEqual({p['targetPort'] for p in service['spec']['ports']}, container_ports)


    def migrate_env(self, patch):
        docs = self.succeeds(patch)
        deployment = next(d for d in docs if d['kind'] == 'Deployment'
                          and d['metadata']['name'].endswith('-caradhras'))
        init = next(c for c in deployment['spec']['template']['spec']['initContainers']
                    if c['name'] == 'migrate')
        return {e['name']: e.get('value') for e in init['env']}

    def test_migrate_skip_rbac_chain_only_when_true(self):
        default = self.migrate_env({})
        self.assertEqual(set(default), {'POSTGRES_HOST', 'POSTGRES_PORT', 'POSTGRES_DB',
                                        'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_SSLMODE'})
        self.assertEqual(self.migrate_env({'caradhras': {'migrations': {'skipRBACChain': False}}}), default)
        env = self.migrate_env({'caradhras': {'migrations': {'skipRBACChain': True}}})
        self.assertEqual(env['MIGRATIONS_SKIP_RBAC_CHAIN'], 'true')

    def server_env(self, patch):
        docs = self.succeeds(patch)
        deployment = next(d for d in docs if d['kind'] == 'Deployment'
                          and d['metadata']['name'].endswith('-caradhras'))
        server = deployment['spec']['template']['spec']['containers'][0]
        return {e['name']: e.get('value') for e in server['env']}

    def test_server_skip_rbac_chain_follows_migrate(self):
        # The boot schema check reads the same variable: a migrate that skips the
        # rbac chain next to a server that asserts it is a crash-loop on the first
        # image with a newer rbac head.
        self.assertNotIn('MIGRATIONS_SKIP_RBAC_CHAIN', self.server_env({}))
        self.assertNotIn('MIGRATIONS_SKIP_RBAC_CHAIN',
                         self.server_env({'caradhras': {'migrations': {'skipRBACChain': False}}}))
        env = self.server_env({'caradhras': {'migrations': {'skipRBACChain': True}}})
        self.assertEqual(env['MIGRATIONS_SKIP_RBAC_CHAIN'], 'true')

    def test_migrate_extra_env_vars(self):
        env = self.migrate_env({'caradhras': {'migrations': {'extraEnvVars': {'FOO': 'bar', 'RETRIES': 3}}}})
        self.assertEqual((env['FOO'], env['RETRIES']), ('bar', '3'))
        # YAML 1.1 boolean-like names must still render as strings (env.name is a string).
        env = self.migrate_env({'caradhras': {'migrations': {'extraEnvVars': {'TRUE': 'a', 'ON': 'b'}}}})
        self.assertEqual((env.get('TRUE'), env.get('ON')), ('a', 'b'))
        self.fails({'caradhras': {'migrations': {'extraEnvVars': {'POSTGRES_HOST': 'x'}}}},
                   'caradhras.migrations.extraEnvVars.POSTGRES_HOST duplicates a chart-owned env')

    def test_migrate_extra_env_var_names_are_schema_checked(self):
        # A name Kubernetes rejects must fail at values validation, not at apply.
        # Helm versions word (and locate) the schema error differently; the
        # pattern itself is in every one of them.
        pattern = '^[-._a-zA-Z][-._a-zA-Z0-9]*$'
        self.fails({'caradhras': {'migrations': {'extraEnvVars': {'BAD=NAME': 'x'}}}}, pattern)
        self.fails({'caradhras': {'migrations': {'extraEnvVars': {'9LIVES': 'x'}}}}, pattern)
        env = self.migrate_env({'caradhras': {'migrations': {'extraEnvVars': {'my.var-1_X': 'ok'}}}})
        self.assertEqual(env['my.var-1_X'], 'ok')

    def test_removed_init_user_job_fails_only_when_enabled(self):
        self.fails({'auth': {'initUser': {'enabled': True}}}, 'auth.initUser was removed')
        for init_user in [{'enabled': False, 'adminPassword': 'x'}, {'adminPassword': 'x'}]:
            with self.subTest(init_user=init_user):
                docs = self.succeeds({'auth': {'initUser': init_user}})
                self.assertFalse([d for d in docs if 'init-user' in d['metadata']['name']])
        self.succeeds({})


if __name__ == '__main__':
    unittest.main()
