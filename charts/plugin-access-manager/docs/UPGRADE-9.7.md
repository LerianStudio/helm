# Upgrade to plugin-access-manager 9.7.0

Chart **9.7.0** moves Access Manager from **3.9.0** to **3.11.0** and Caradhras from **1.4.0** to **1.5.1**. Caradhras **1.5.0 is the minimum** for Access Manager 3.11.0; use 1.5.1.

Application behavior below was checked against Access Manager commit [`c41e7747`](https://github.com/LerianStudio/plugin-access-manager/tree/c41e7747d77b59fc6ca509b75066fb26a9a42a9d) (the release candidate that becomes 3.11.0) and Caradhras [`v1.5.1`](https://github.com/LerianStudio/caradhras/tree/v1.5.1).

## 1. Images

| Component | Chart default image | Override |
| --- | --- | --- |
| Auth | `ghcr.io/lerianstudio/plugin-auth:3.11.0` | `auth.image.tag` |
| Identity | `ghcr.io/lerianstudio/plugin-identity:3.11.0` | `identity.image.tag` |
| Initial admin user | `ghcr.io/lerianstudio/caradhras-user-init:3.11.0` | `auth.initUser.image` |
| Caradhras | `ghcr.io/lerianstudio/caradhras:1.5.1` | `caradhras.image.tag` |
| Database migrations | `ghcr.io/lerianstudio/caradhras-migrations:1.5.1` | `caradhras.migrations.image.tag` |
| Caradhras UI (off by default) | `ghcr.io/lerianstudio/caradhras-ui:1.4.0` (unchanged) | `caradhras.ui.image.tag` |

- Explicit tag overrides still win. Update auth and identity together, and raise a pinned `caradhras.image.tag` to `1.5.1`.
- **Why Caradhras 1.5.0 is the floor.** Disabling MFA with the authenticator app (and a full MFA reset whose preferred method is the app) now proves the factor by calling Caradhras `POST /api/mfa/verify`. Caradhras serves that route from 1.5.0 on; on 1.4.0 the call fails and Access Manager refuses the disable.
- **Why 1.5.1.** It fixes Caradhras issue #254: the MFA management routes could act on a different user than the one the authorization check approved.
- Caradhras 1.4.0 → 1.5.1 adds no database migration.

Sources: [MFA step-up call](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/identity/internal/adapters/authserver/casdoor/casdoor.mfa_step_up.go#L39), [route in Caradhras 1.5.0](https://github.com/LerianStudio/caradhras/blob/v1.5.0/internal/http/mfa_huma.go#L120).

## 2. Configuration

No new environment variable is required.

- **`VERSION` and `OTEL_RESOURCE_SERVICE_VERSION` are gone** from the auth and identity ConfigMaps. 3.11.0 no longer reads them: `/version`, `/readyz` and the OpenTelemetry `service.version` report the version, revision and build time compiled into the image. If you set either through `extraEnvVars`, remove it; it is ignored.
- **`identity.configmap.TRUSTED_PROXIES`** now also feeds the forgot-password rate limit (10 requests per 15 minutes per client IP, on both forgot-password routes, only when `ENABLE_FORGOT_PASSWORD` and rate limiting are on). Left empty, every request behind an ingress counts against the ingress's own address, so all users share one budget. Set it to your ingress or load balancer CIDRs, plus the console's pod CIDR when the console calls identity in-cluster.
- **`MFA_ENABLED` without `MFA_SECRET`** no longer stops auth from booting: it logs an error and the MFA routes answer `503 AUT-0028`. The chart keeps refusing to render that combination, so nothing changes for chart installs.

Sources: [build identity on `/version`](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/auth/internal/adapters/http/in/routes.go#L120), [forgot-password tier](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/identity/internal/adapters/http/in/rate_limit.go#L19-L31), [trusted proxies](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/identity/internal/adapters/http/in/routes.go#L580-L600).

## 3. Organization email domain (`domain`, `domainHome`)

Tenant discovery now reads the organization's `domain` and `domainHome` fields in Caradhras (tenant-manager writes them). The old `domain:<domain>` organization tag is **no longer read**.

- **Multi-tenant user creation needs `domain`.** Creating a user, or changing a user's email, is refused with `IDE-0034` when the email's domain is not the organization's `domain`, or when the organization has no `domain`.
- **SSO for a person with no account goes to the `domainHome` organization** of the email's domain. Without one, that person gets no SSO tenant. In single-tenant mode this applies too unless `auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` is set.
- **Password login, SSO and (multi-tenant) forgot-password pick the person's default tenant.** For a person with no default and accounts in several tenants, the `domainHome` organization wins, otherwise the oldest tenant. A person with one tenant is unaffected.

Check before upgrading: every organization that used a `domain:` tag has `domain` set, and one organization per domain has `domainHome` set.

Sources: [tenant discovery](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/pkg/tenantdiscovery/discover.go#L72-L160), [email-domain rule](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/identity/internal/services/user.go#L413-L458).

## 4. API changes your clients see

- **Application reads no longer return `clientSecret`.** `GET /v1/applications` and `GET /v1/applications/{id}` omit it; only the create response carries it. Store the secret when the application is created.
- **Identity provider outage answers `503 IDE-0066`** (it was `500 IDE-0006`). The same 503 shape covers `IDE-0064` (another create of the same application is in progress) and `IDE-0065` (the lock store did not answer). Retry these.
- **Auth partner and application credentials:** a deleted application or partner answers `401 AUT-1011` / `401 AUT-1012`, and an unreachable Caradhras during that decision answers `503 AUT-0033`. Both used to be `500 AUT-0005`.
- **Self-service MFA disable needs proof:** the current authenticator passcode, or the code e-mailed by the new `POST /v1/users/{id}/mfa/disable/challenge`. Refusals are `IDE-0060` to `IDE-0063`. The console version you run must send it.
- **Deleting a group that still has members or subgroups** answers `409 IDE-1058` / `409 IDE-1059` (it was `500 IDE-0006`).
- **`GET /v1/users/{id}/permissions`** lists only permissions granted directly to the user, no longer the ones inherited through roles and groups.
- **New routes:** `GET /v1/users/{id}/tenants` and `PUT /v1/users/{id}/tenants/default` (a member lists their tenants and picks the default), `GET /v1/partners/ceiling`.
- **Token introspection is cached for at most 60 seconds**, so a revocation made outside Access Manager takes effect within a minute.

Sources: [application read mapper](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/identity/pkg/model/application.go#L297-L307), [IDE-0066](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/identity/pkg/errors_unavailable.go#L38-L55), [auth error codes](https://github.com/LerianStudio/plugin-access-manager/blob/c41e7747d77b59fc6ca509b75066fb26a9a42a9d/components/auth/pkg/constant/errors.go#L110-L185).

## 5. Upgrade

```bash
helm template plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.7.0 -f <your-values.yaml> > /tmp/pam-9.7.0.yaml

helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.7.0 -n <namespace> -f <your-values.yaml>
```
