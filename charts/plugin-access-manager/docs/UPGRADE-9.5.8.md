# Helm upgrade from v9.5.7 to v9.5.8

Chart `9.5.8` upgrades Auth and Identity from application `3.1.0` to `3.9.0`.
This is not just a chart patch: review the production JWKS and MFA requirements
below before upgrading. Existing image overrides still take precedence.

**Release boundary:** this guide documents application behavior shipped with
chart `9.5.8`. The new offline startup-validation checks in the current chart
source belong to the **next chart release**, not the already published `9.5.8`
artifact. See the [README validation section](../README.md#offline-startup-validation-next-chart-release)
for the existing-Secret responsibility, duplicate-key checks, and static-versus-runtime
limits. Do not expect `helm template --version 9.5.8` to enforce those new checks.

## Contents

- [Images and initialization](#images-and-initialization)
- [Production prerequisite: HTTPS JWKS upstream](#production-prerequisite-https-jwks-upstream)
- [MFA prerequisite and legacy SMS migration](#mfa-prerequisite-and-legacy-sms-migration)
- [SSO preflight and private-network access](#sso-preflight-and-private-network-access)
- [Other configuration exposed by this chart](#other-configuration-exposed-by-this-chart)
- [Upgrade checklist and commands](#upgrade-checklist-and-commands)
- [Source references](#source-references)

## Images and initialization

| Setting | Chart 9.5.7 | Chart 9.5.8 |
|---|---|---|
| `appVersion` | `3.1.0` | `3.9.0` |
| `identity.image.repository` | `ghcr.io/lerianstudio/plugin-identity` | unchanged |
| `identity.image.tag` | `3.1.0` | `3.9.0` |
| `auth.image.repository` | `ghcr.io/lerianstudio/plugin-auth` | unchanged |
| `auth.image.tag` | `3.1.0` | `3.9.0` |
| Init-user fallback image | `ghcr.io/lerianstudio/caradhras-user-init:3.3.1` | `ghcr.io/lerianstudio/caradhras-user-init:3.9.0` |

If you pin Auth or Identity images in your environment values, update both:

```yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/plugin-identity
    tag: "3.9.0"
auth:
  image:
    repository: ghcr.io/lerianstudio/plugin-auth
    tag: "3.9.0"
```

The init-user Job is conditional on `auth.initUser.enabled` and is a Helm
**`post-install` hook only**. It is not a `pre-upgrade` hook and does not run on a
normal `helm upgrade`. Changing its fallback image does not reinitialize users,
reset passwords, or recreate a deleted administrator during an upgrade.
`auth.initUser.image` overrides remain effective (either the image map or the
legacy complete image string). Do not rerun initialization as an MFA recovery
procedure. These lifecycle statements describe Helm; controllers that translate
Helm hooks must be checked separately.

## Production prerequisite: HTTPS JWKS upstream

Application `3.9.0` validates JWKS transport at startup. The gate uses the
**effective `ENV_NAME`**, not `DEPLOYMENT_MODE` or whether M2M inversion is enabled.
Only `development`, `staging`, and `local` allow plaintext JWKS in the application
configuration; production, empty, or unknown environment names fail closed.

There are two independent paths:

| Component | JWKS source | When checked |
|---|---|---|
| Auth | Resolved Casdoor/Caradhras base address plus `/.well-known/jwks` | Auth bootstrap, independently of Identity's auth/inversion flags |
| Identity | Explicit `AUTH_M2M_JWKS_URL`, otherwise `AUTHORIZER_ADDRESS` plus `/.well-known/jwks` | When `PLUGIN_AUTH_ENABLED=true` |

The chart's `identity.configmap.AUTH_ENABLED` renders as `PLUGIN_AUTH_ENABLED`
and defaults to `"true"`. Identity builds its dynamic JWKS authenticator whenever
that setting is enabled, **even with `AUTH_M2M_INVERSION_ENABLED="false"`**.
`AUTH_M2M_JWKS_URL` and `AUTH_M2M_JWKS_REFRESH_INTERVAL` are tuning parameters, not
inversion-only switches. Disabling authentication skips token verification; it
is not a production workaround for an HTTP JWKS address.

The chart's bundled `AUTHORIZER_ADDRESS` defaults are HTTP. Setting
`ENV_NAME="production"` without supplying an appropriate HTTPS upstream can
therefore prevent startup. The chart does not provision that HTTPS upstream or
its certificate trust for you. Arrange a reachable TLS endpoint for the same
Caradhras issuer before the application upgrade; validate its certificate chain
and hostname from the workloads. Do not just replace `http` with `https` on an
HTTP-only Service.

Example **configuration shape**, not a complete production values file:

```yaml
auth:
  configmap:
    ENV_NAME: "production"
    AUTHORIZER_ADDRESS: "https://caradhras.example.com"
identity:
  configmap:
    ENV_NAME: "production"
    AUTH_ENABLED: "true"
    AUTHORIZER_ADDRESS: "https://caradhras.example.com"
    # Optional override for the same issuer's keys; not a different IdP.
    AUTH_M2M_JWKS_URL: "https://caradhras.example.com/.well-known/jwks"
```

Use your real endpoint instead of `example.com`. Identity pins token issuer
validation to `AUTHORIZER_ADDRESS`; ensure it matches the issuer of the tokens
being validated. A separate HTTPS JWKS override changes key retrieval, not that
issuer check, and does not fix Auth's upstream.

With service discovery enabled, inspect the **resolved** Casdoor address as well
as the configured fallback: Auth uses the resolved address to construct its JWKS
URL. Auth also rejects HTTPS-to-HTTP redirects. Identity's underlying library has
a loopback development exception; it does not make a normal in-cluster HTTP
Service a production-safe JWKS source.

Do not change production's environment name, disable authentication, or enable
SSO's insecure-preflight flag to bypass this requirement. The SSO flag does not
control either JWKS path. A successful Helm render does not prove runtime TLS
reachability or issuer compatibility.

## MFA prerequisite and legacy SMS migration

### Supply `MFA_SECRET` before declaring MFA enabled

In application `3.9.0`, `MFA_ENABLED` is a deployment assertion used for the
startup check. MFA enrollment is still **per user** in the authorization server;
setting this variable does not enroll users or switch their factors off.

- `MFA_ENABLED=true` with an empty `MFA_SECRET` refuses Auth startup.
- Unset `MFA_ENABLED` leaves the application's default `false` in force. This
  permits non-MFA deployments to boot without the secret; it does not make MFA
  challenges work without it.
- If your deployment uses MFA, set `auth.configmap.MFA_ENABLED: "true"` and supply
  a non-empty `MFA_SECRET` through the Auth Secret before upgrading.
- For chart-managed secrets, the value is `auth.secrets.MFA_SECRET`. For an
  externally managed Secret, set `auth.useExistingSecret: true` and
  `auth.existingSecretName`; that Secret must include `MFA_SECRET` alongside the
  other Auth keys your deployment needs. Preserve the existing secret value
  through the upgrade. Never put it in a ConfigMap, `extraEnvVars`, or committed
  values file.

`MFA_SESSION_TTL_SEC`, `MFA_REMEMBER_TTL_SEC`, `MFA_MAX_ATTEMPTS`, and
`MFA_MAX_RESEND_ATTEMPTS` remain tuning parameters, not replacements for the
secret or per-user enrollment.

### Migrate SMS-only accounts before cutover

Application `3.9.0` supports public MFA enrollment and login with `app` (TOTP) and
`email`. Legacy `sms` is accepted for **clearing an existing enrollment only**;
it cannot be enrolled or selected as a login/preferred method. Auth keeps the MFA
gate enabled for legacy SMS-only users rather than silently allowing password-only
login. Those users can be locked out after the upgrade.

Before cutover, inventory affected accounts through authorized administration,
move them to `app` or `email`, and test a full login with the replacement factor.
Verify that an authorized administrator can use the recovery path before relying
on it. Do not assume password reset or init-user execution migrates MFA.

For an account already locked out by an SMS-only enrollment, the supported
administrative clearing route in `3.9.0` is:

```text
DELETE /v1/users/{id}/mfa/admin/sms
```

`{id}` is the affected user's ID, not the administrator's. This operation requires
an authenticated principal authorized for the administrative MFA resource; it is
not a public recovery endpoint. Check `GET /v1/users/{id}/mfa` using appropriate
authorization first, clear only the intended legacy channel, then re-enroll and
verify `app` or `email`. Removing the last factor leaves the account protected by
its password alone until replacement enrollment is complete. The whole-account
`DELETE /v1/users/{id}/mfa` is self-service and cannot be used with an administrator's
token to reset somebody else. Do not log or share enrollment secrets or recovery
codes during this procedure.

## SSO preflight and private-network access

These Identity flags default to `"false"` and control different checks:

| Value under `identity.configmap` | Meaning in application 3.9.0 |
|---|---|
| `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` | Allows SSO preflight probes to use plain HTTP instead of requiring HTTPS. **Does not disable TLS certificate verification.** |
| `PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS` | Allows RFC1918 destinations for outbound SSO probes/discovery and widens provider endpoint validation. Does not relax certificate verification. |

Keep the insecure-preflight flag off in production. Enabling it can send the
candidate OAuth client secret over plaintext HTTP. It is not a solution for a
self-signed or untrusted HTTPS certificate: configure appropriate certificate
trust instead.

An HTTPS IdP on a private RFC1918 network needs only the private-network opt-in:

```yaml
identity:
  configmap:
    PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE: "false"
    PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: "true"
```

Not every BYOC/on-premises IdP needs this opt-in; it depends on the destination
network. Even when enabled, loopback, link-local/cloud-metadata and IPv6
unique-local destinations remain blocked at dial time, and reserved hostnames
such as `localhost`, `*.internal` and `*.cluster.local` remain rejected by provider
configuration validation. This is not unrestricted private-cluster access.

For an isolated development IdP that genuinely serves only HTTP, the preflight
flag can be enabled explicitly; add the private-network flag only if its address
also requires it. Neither flag configures the production JWKS upstream above.

## Other configuration exposed by this chart

| Chart value | Default / application 3.9.0 behavior |
|---|---|
| `identity.configmap.ENABLE_FORGOT_PASSWORD` | `"false"`; opt-in public self-service password-recovery routes. Configure and test the application's email provider before enabling. |
| `identity.configmap.AUTH_M2M_JWKS_URL` | Omitted unless set; derives `AUTHORIZER_ADDRESS` + `/.well-known/jwks`. Applies whenever Identity authentication is enabled, not only with inversion. |
| `identity.configmap.AUTH_M2M_JWKS_REFRESH_INTERVAL` | Omitted unless set; application defaults to `5m` for unset, invalid, or non-positive durations. |
| `auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` | Omitted unless set; supplies the organization for pre-login single-tenant SSO resolution. Refused together with effective `MULTI_TENANT_ENABLED=true`. |
| `auth.configmap.AUTH_JWKS_CACHE_TTL` | Omitted unless set; application defaults to `5m` for unset, invalid, or non-positive durations. Controls Auth's read-through JWKS cache freshness, not its TLS requirement. |

Use Go duration strings such as `5m`, `10m`, or `1h` for the two cache settings.
Without a static SSO organization, Auth resolves the organization claiming the
email domain; this setting is not a switch that enables multi-tenancy. Check the
rendered `MULTI_TENANT_ENABLED` value, including any global override, rather than
assuming that omitting the component-local key disables it.

## Upgrade checklist and commands

1. Back up the application's persistent data and retain the previous chart/image
   versions and environment configuration under your normal recovery procedure.
2. Review explicit image pins, effective `ENV_NAME`, configured/resolved
   `AUTHORIZER_ADDRESS`, and Identity's authentication/JWKS settings. Prove the
   production HTTPS upstream is reachable and trusted before cutover.
3. Supply the Auth MFA secret where needed; migrate SMS-only accounts and verify
   authorized administrative recovery access.
4. Render with the **same reviewed environment values** you intend to deploy.
   Keep render/diff output private: it can include Kubernetes Secret data.
5. Upgrade only after these checks. Verify Auth/Identity readiness and configured
   images, then test the applicable password, MFA, SSO, and protected M2M flows.
   Health alone does not prove authentication or authorization works.

Replace `values-environment.yaml` with your reviewed values file and preserve any
additional values/secret-provider inputs required by your deployment. Adjust the
release name and namespace to your existing installation; do not rely on omitted
overrides or blindly reuse old values.

```bash
helm template plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.5.8 -n plugin-access-manager -f values-environment.yaml

helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.5.8 -n plugin-access-manager -f values-environment.yaml

helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.5.8 -n plugin-access-manager -f values-environment.yaml --wait
```

`helm diff` requires the [helm-diff plugin](https://github.com/databus23/helm-diff).
The commands are operator instructions, not evidence that an environment has been
upgraded. Helm rollback does not by itself reverse database changes or user MFA
changes; verify the recovery plan against those changes separately.

## Source references

Application behavior was checked at `plugin-access-manager` tag `v3.9.0`, commit
`fe633e3c1939a51c09c5d3809160c51f5809ade1`:

- `components/auth/internal/bootstrap/config.go`: `validateMFAConfig`, JWKS
  bootstrap, `buildJWKSCacheURL`, `isDevelopmentEnv`, `newJWKSCacheClient`, and
  `resolveJWKSCacheTTL`.
- `components/identity/internal/bootstrap/config.go`: `buildM2MAuthenticator`,
  `resolveM2MJWKSURL`, `resolveM2MJWKSRefreshInterval`, and `isDevelopmentEnv`.
- `components/identity/internal/services/sso_provider_preflight.go`:
  `probeEndpointAllowed`; `components/identity/pkg/config/config.go`: SSO flag
  scope and address restrictions.
- `components/auth/internal/adapters/authserver/casdoor/casdoor_mfa.go`:
  `addAvailableMFAMethods` and `normalizePreferredMethod`;
  `components/identity/internal/adapters/http/in/mfa_api.go` and
  `components/identity/internal/services/mfa_admin.go`: administrative recovery.
- `components/auth/pkg/config/config.go` and
  `components/auth/internal/services/auth/sso_tenant_resolution.go`: static SSO
  organization validation and resolution.

Chart image deltas were checked against tags `plugin-access-manager-v9.5.7` and
`plugin-access-manager-v9.5.8`. The value-to-environment and hook contracts are in
[`values.yaml`](../values.yaml),
[`auth/configmap.yaml`](../templates/auth/configmap.yaml),
[`identity/configmap.yaml`](../templates/identity/configmap.yaml),
[`auth/secrets.yaml`](../templates/auth/secrets.yaml),
[`auth/deployment.yaml`](../templates/auth/deployment.yaml), and
[`auth/init_user.yaml`](../templates/auth/init_user.yaml). Source and render checks
do not establish a particular deployment's TLS, migration, or login readiness.
