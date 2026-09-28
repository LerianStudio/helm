# Upgrade to plugin-access-manager 9.5.8

Chart **9.5.8** selects Access Manager **3.9.0**. Treat this as an application upgrade, not just a chart change: existing values, upstream TLS, signing keys, MFA enrollments and database state must be checked first. Backward compatibility and a successful rollback are **not guaranteed**.

Application behavior below is checked against [v3.9.0](https://github.com/LerianStudio/plugin-access-manager/tree/v3.9.0), resolved to commit `fe633e3c1939a51c09c5d3809160c51f5809ade1`. Source links use that immutable commit. Chart behavior is defined by this chart's [values](../values.yaml) and templates, not by the application's development branch.

## 1. Confirm images and upgrade scope

| Component | Chart default image | Override |
| --- | --- | --- |
| Auth | `ghcr.io/lerianstudio/plugin-auth:3.9.0` | `auth.image.repository`, `auth.image.tag` |
| Identity | `ghcr.io/lerianstudio/plugin-identity:3.9.0` | `identity.image.repository`, `identity.image.tag` |
| Initial admin user | `ghcr.io/lerianstudio/caradhras-user-init:3.9.0` | `auth.initUser.image` (full image string or repository/tag map) |
| Caradhras | `ghcr.io/lerianstudio/caradhras:1.3.2` | `caradhras.image.repository`, `caradhras.image.tag` |
| Database migrations | `ghcr.io/lerianstudio/caradhras-migrations:1.3.2` | `caradhras.migrations.image.repository`, `caradhras.migrations.image.tag` |

Auth and Identity also have verified public Docker Hub mirrors, `docker.io/lerianstudio/plugin-auth:3.9.0` and `docker.io/lerianstudio/plugin-identity:3.9.0`; GHCR remains the chart default. Only GHCR was verified for the three support images. Do not infer support-image mirrors or use the incorrect `midaz-auth` / `midaz-identity` repository names. Verify registry access from the target cluster, platform compatibility and the actual pulled image digests before rollout.

- Explicit image overrides remain effective; update Auth and Identity together. `appVersion` alone does not override pinned images.
- Caradhras and its migration image have independent tags. Inspect legacy `auth.backend.*` overrides too; the [helpers](../templates/_helpers.tpl) retain fallback paths. Do not substitute the old `casdoor-migrations` image; see [9.2.4 migration notes](UPGRADE-9.2.4.md).
- The [init-user Job](../templates/auth/init_user.yaml) is **post-install only**, when `auth.initUser.enabled` is true. It does not run on `helm upgrade`, recreate a deleted admin, or repair an existing installation. Do not manually rerun it as an upgrade step.
- Database migrations run in the Caradhras Deployment's `migrate` **init container**, before the server starts; they are not the init-user Job or a Helm upgrade hook. Review migration compatibility and take a tested database backup before changing workloads.

## 2. Satisfy runtime prerequisites before rendering

These are application requirements, not a claim that released chart 9.5.8 validates every combination. In particular, rendering successfully does not prove TLS connectivity, external Secret contents, MFA readiness or single-tenant SSO correctness. Additional chart guards/CI proposed after 9.5.8 must not be assumed present in the published package.

### TLS, JWKS and environment

- Check each component's rendered `ENV_NAME`. `global.env.name` supplies the shared setting; `auth.configmap.ENV_NAME` and `identity.configmap.ENV_NAME` override it. The chart fallback is `development`; that is not an appropriate production classification.
- Auth's JWKS cache derives `/.well-known/jwks` from its resolved Caradhras upstream (configured `AUTHORIZER_ADDRESS`, or service discovery). It rejects a non-HTTPS upstream at startup when `ENV_NAME` is production, empty or unrecognized. Only the explicit `development`, `staging`, `local` allow-list permits plaintext. A production deployment retaining the chart's default `http://<caradhras-service>:<port>` upstream will fail this gate.
- Identity's dynamic M2M JWKS verification is active when `identity.configmap.AUTH_ENABLED` is true (rendered as **`PLUGIN_AUTH_ENABLED`**, default `"true"`). It is **not** enabled by `AUTH_M2M_INVERSION_ENABLED`; inversion is not a JWKS on/off switch. `identity.configmap.AUTH_M2M_JWKS_URL` overrides the default `${AUTHORIZER_ADDRESS}/.well-known/jwks`. The same environment allow-list governs non-loopback HTTP JWKS URLs; production/empty/unknown environments reject them. The library's loopback exception is not a production topology solution.
- Provide a reachable HTTPS Caradhras/JWKS endpoint with a trusted certificate and correct hostname. Configure `auth.configmap.AUTHORIZER_ADDRESS` and `identity.configmap.AUTHORIZER_ADDRESS` for the real topology, preserving the issuer expected in tokens. Validate service-discovery results too. HTTPS at the public ingress alone does not change the internal HTTP upstream.
- Independently, `DEPLOYMENT_MODE=saas` requires `REDIS_TLS=true` and an HTTPS `AUTHORIZER_ADDRESS` in both components. Changing `DEPLOYMENT_MODE` does not remove the environment-based JWKS gate.
- Do not relabel production as development, disable authentication, or enable insecure transport flags to get past startup failures. `ALLOW_INSECURE_TLS` is not a substitute for meeting the JWKS HTTPS requirement. Configure certificate trust rather than disabling verification.
- Preserve the issuer's real signing certificate/key configuration. Both components resolve `AUTHORIZER_JWT_CERTIFICATE`; an estate with its own Caradhras must use its own matching certificate, not assume an embedded certificate matches. Check credentialed token verification and key rotation, not just an HTTP 200 from JWKS.

Optional tuning (Go duration syntax; omitted, invalid or non-positive values fall back to **`5m`**):

| Values path | Purpose |
| --- | --- |
| `auth.configmap.AUTH_JWKS_CACHE_TTL` | Auth's upstream JWKS cache freshness |
| `identity.configmap.AUTH_M2M_JWKS_REFRESH_INTERVAL` | Identity's dynamic JWKS refresh interval |

Sources: [Auth bootstrap](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/auth/internal/bootstrap/config.go), [Identity bootstrap](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/identity/internal/bootstrap/config.go), [Auth SaaS TLS gate](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/auth/internal/bootstrap/tls_enforcement.go), [Identity SaaS TLS gate](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/identity/internal/bootstrap/tls_enforcement.go).

### MFA and existing users

`auth.configmap.MFA_ENABLED: "true"` is a deployment assertion that MFA is used; Auth refuses startup without a non-empty **`MFA_SECRET`**. Supply it through `auth.secrets.MFA_SECRET`, or key `MFA_SECRET` in the Secret selected by `auth.useExistingSecret` / `auth.existingSecretName`. Keep the existing secret stable across replicas and upgrades; do not rotate it casually during this change.

The application defaults this assertion to false when omitted, but MFA enrollment is per user. Omitting the flag does not prove there are no enrolled users. Inventory actual enrollment, preserve MFA policy, and supply the secret rather than suppressing the assertion to make startup pass.

**SMS MFA is retired in 3.9.0.** Supported channels are `app` (TOTP) and `email`. Identify SMS-only users and complete an approved transition to a supported factor before rollout. Legacy SMS enrollment can be cleared through the authorized per-channel recovery flow, but cannot be re-enrolled or used for a login challenge. Clearing it can leave a password-only account; it is not a substitute for completing re-enrollment under the organization's security policy.

Sources: [MFA startup validation](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/auth/internal/bootstrap/config.go), [supported and clearable MFA channels](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/identity/pkg/constant/mfa.go).

### SSO and password recovery

| Values path | Behavior and operator action |
| --- | --- |
| `identity.configmap.PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` | Default `"false"`. Allows **plain HTTP** preflight endpoints if enabled; it does **not** trust self-signed certificates or disable certificate validation. Preflight can transmit a client secret, so keep HTTPS and fix trust instead of using this as a certificate workaround. |
| `identity.configmap.PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS` | Default `"false"`. Separately permits RFC1918 destinations for the applicable SSO probes/provider configuration. It does not permit all private/local addresses: loopback, link-local/metadata and IPv6 unique-local targets remain blocked at dial time. Enable only for a reviewed private-IdP topology, not to bypass an unexplained SSRF rejection. |
| `auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` | Optional fixed, existing Caradhras organization for single-tenant BYOC SSO. Auth rejects it when effective `MULTI_TENANT_ENABLED=true`. Leave unset in multi-tenant deployments; do not disable tenancy to accommodate it. |
| `identity.configmap.ENABLE_FORGOT_PASSWORD` | Default `"false"`; enabling exposes public self-service password-recovery routes. Confirm the intended email-provider/application configuration, rate limiting and end-to-end reset flow before opting in. |

For SSO, Auth and Identity must receive the same browser-facing `PLUGIN_AUTH_SSO_CALLBACK_URL`, matching the Caradhras application's redirect allow-list. Use `common.sso.callbackUrl` for the full URL (or the chart's `common.sso.baseUrl` derivation); inspect per-component overrides, which take precedence. Do not use the internal `PLUGIN_AUTH_ADDRESS` as a browser callback. Test provider preflight, login, callback and code exchange with the actual IdP.

Sources: [Identity SSO settings](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/identity/pkg/config/config.go), [preflight transport policy](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/identity/internal/services/sso_provider_preflight.go), [Auth single-tenant SSO validation](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/auth/pkg/config/config.go), [password recovery](https://github.com/LerianStudio/plugin-access-manager/blob/fe633e3c1939a51c09c5d3809160c51f5809ade1/components/identity/internal/services/forgot_password.go).

## 3. Verify Secret references without exposing values

Existing Secrets must already exist in the release namespace and contain the keys required by the enabled features. A Secret name alone is not evidence of valid credentials. Never put real credentials in examples, shell history or review output.

| Consumer | Exact values paths / Secret keys |
| --- | --- |
| Auth | `auth.useExistingSecret: true` + `auth.existingSecretName`; keys include `AUTHORIZER_CLIENT_SECRET`, `LICENSE_KEY`, `ORGANIZATION_IDS`, and `REDIS_PASSWORD`, `MFA_SECRET`, `SD_TOKEN` as required by the configured features. Otherwise use `auth.secrets.<KEY>`. |
| Identity | `identity.useExistingSecret: true` + `identity.existingSecretName`; keys include `AUTHORIZER_CLIENT_SECRET`, `LICENSE_KEY`, `ORGANIZATION_IDS`, and `REDIS_PASSWORD`, `SD_TOKEN` as required. Otherwise use `identity.secrets.<KEY>`. |
| Database password | `auth-database.auth.existingSecret` selects an operator Secret with key **`password`** for chart workloads. With the bundled database and no operator override, the chart-managed database Secret is used. For an external/disabled database without that override, use `auth.secrets.DB_PASSWORD`, or key **`DB_PASSWORD`** in the existing Auth Secret. |
| Initial admin (first install only) | `auth.initUser.useExistingSecret: true`, `auth.initUser.adminPasswordSecretName`, `auth.initUser.adminPasswordSecretKey` (default **`ADMIN_PASSWORD`**). Otherwise `auth.initUser.adminPassword`. These are not the Auth service's existing-Secret paths. |

Preserve the current license, organization scope and authorizer credentials. Do not invent replacement values or remove enforcement to pass a render/test. Check database and Redis credentials against the actual datastores; an application Secret override does not automatically change their passwords.

Chart sources: [Auth Secret](../templates/auth/secrets.yaml), [Identity Secret](../templates/identity/secrets.yaml), [database password selection](../templates/_helpers.tpl), [init-user Secret and hook](../templates/auth/init_user.yaml).

## 4. Preview, rehearse and upgrade

1. Record the current Helm revision, chart version, effective image digests and user-supplied values. Protect any exports: Helm values and manifests can contain credentials. Back up the database and required Secret/key material, and verify restore in an isolated environment. Review intervening migration notes if starting before 9.5.7.
2. Prepare a complete, reviewed target values file from the current installation. Retain topology, external Secrets, issuer/callback settings, license scope and security policy. Reconcile old image pins and legacy aliases explicitly; do not blindly use `--reuse-values` or discard overrides.
3. Render the exact target chart and inspect ConfigMaps, Secret references, images, probes, migrations and hooks. Rendering/diffing does not exercise application startup or inspect existing Secret contents. Rehearse with representative data and the intended TLS/IdP topology before production approval.

The commands below assume a reviewed **9.5.8** chart checkout at `./charts/plugin-access-manager` (repository root as working directory), with its locked dependencies available. Set `RELEASE`, `NAMESPACE` and `VALUES` to the actual existing release, namespace and reviewed values-file path. `helm diff` requires the separately installed helm-diff plugin; handle its output as sensitive.

```bash
: "${RELEASE:?Set the existing release name}"
: "${NAMESPACE:?Set its namespace}"
: "${VALUES:?Set the reviewed values-file path}"
CHART=./charts/plugin-access-manager

helm show chart "$CHART"
helm history "$RELEASE" -n "$NAMESPACE"
helm lint "$CHART" -f "$VALUES"
helm diff upgrade "$RELEASE" "$CHART" -n "$NAMESPACE" \
  --reset-values -f "$VALUES"
```

After backup, rehearsal and rollout approval, choose a timeout suitable for the tested migration duration and execute through the environment's approved release workflow. The equivalent direct Helm command is below; it deliberately does not use `--install` or create a namespace, so a misspelled release cannot silently become a new installation.

```bash
: "${ROLLOUT_TIMEOUT:?Set the approved Helm timeout duration}"
helm upgrade "$RELEASE" "$CHART" -n "$NAMESPACE" \
  --reset-values -f "$VALUES" --wait --timeout "$ROLLOUT_TIMEOUT"
```

## 5. Acceptance and recovery

Before accepting the release, verify:

- Caradhras's `migrate` init container completed; Auth, Identity and Caradhras are Ready without restart loops. Check actual images/digests and sanitized logs, not just Helm's status.
- HTTPS/JWKS retrieval and certificate trust work from the workload network; token issuance, validation, M2M authorization and signing-key refresh work with the expected issuer. Confirm unauthenticated/unauthorized requests remain denied.
- Existing users can sign in and complete required MFA; migrated SMS users have a supported factor. SSO works end to end where used. Exercise password recovery only if enabled.
- License and organization/tenant enforcement, datastore access and normal client integration flows remain correct. The absence of a new init-user Job during upgrade is expected.

If a gate fails, stop the rollout and diagnose the actual error without relaxing authentication, MFA, TLS or tenant isolation. Do not treat an unrelated or pre-existing test failure as evidence that this image bump caused a regression.

`helm rollback` restores a previous Helm release revision; it does **not** undo database migrations, restore external Secrets or reverse user/IdP changes. A restored Caradhras pod can run its own migration init container against the database. Before rollback, confirm old binaries are compatible with the resulting schema/state, or use the tested coordinated restore plan. Do not uninstall the release, delete PVCs, reset credentials or rely on automatic Helm rollback as database recovery.

After approval of the compatible rollback/restore path:

```bash
: "${PREVIOUS_REVISION:?Set the verified previous Helm revision}"
helm rollback "$RELEASE" "$PREVIOUS_REVISION" -n "$NAMESPACE" \
  --wait --timeout "$ROLLOUT_TIMEOUT"
```

Repeat the same functional/security acceptance checks after recovery.
