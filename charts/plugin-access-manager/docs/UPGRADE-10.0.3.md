<!-- {% raw %} -->
# Helm Upgrade from v10.0.2 to v10.0.3

# Topics

- **[Overview](#overview)**
- **[Before you upgrade](#before-you-upgrade)**
  - [Pinned image tags](#pinned-image-tags)
  - [Upgrade order: Access Manager before Bank Transfer](#upgrade-order-access-manager-before-bank-transfer)
- **[What the application brings](#what-the-application-brings)**
- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This release moves the application from 3.11.1 to 3.13.1, which spans two minor versions (3.12 and 3.13). The chart version goes from 10.0.2 to 10.0.3. The chart templates do not change, except for the default image tag of the init user job.

**What changed:**

- Application version (appVersion) updated from `3.11.1` to `3.13.1`
- Identity service image tag updated to `3.13.1`
- Auth service image tag updated to `3.13.1`
- Auth init user container default image tag updated to `3.13.1`

**What this means for operators:**

The upgrade triggers rolling updates of the `identity` and `auth` deployments with the new images. The `caradhras` Deployment rolls as well, although its images stay on `1.5.1`. The pod templates of the auth, identity and caradhras Deployments carry the label `helm.sh/chart: plugin-access-manager-<version>`, so any chart version bump replaces the pods of all three, even when nothing else in the pod changes. I checked this by rendering the previous and the new chart version with `helm template`. Auth and identity render `maxSurge: 1` and `maxUnavailable: 1` by default (auth runs 3 replicas, identity 1), so identity can be briefly unavailable during the rollout when it runs a single replica. The application releases between 3.11.1 and 3.13.1 add no database migration, and the Caradhras image does not change in this release. The chart needs no new values.

Two things need your attention before you upgrade: pinned image tags, and the upgrade order relative to Bank Transfer. Read [Before you upgrade](#before-you-upgrade). Also read [What the application brings](#what-the-application-brings): some API behavior changes.

| Component | v10.0.2 | v10.0.3 |
|-----------|---------|---------|
| Chart version | 10.0.2 | 10.0.3 |
| App version | 3.11.1 | 3.13.1 |
| Identity image tag | 3.11.1 | 3.13.1 |
| Auth image tag | 3.11.1 | 3.13.1 |
| Auth init user image tag (default) | 3.11.1 | 3.13.1 |

# Before you upgrade

### Pinned image tags

The chart sets `identity.image.tag` and `auth.image.tag` explicitly in `values.yaml`, and the init user job takes its default tag from the template. A tag in your own values overrides all of them. For a pinned component, the upgrade changes nothing and the component stays on the old version.

Check your values:

```bash
helm get values plugin-access-manager -n plugin-access-manager
```

Look for these keys:

```yaml
identity:
  image:
    tag: "..."
auth:
  image:
    tag: "..."
  initUser:
    image:
      tag: "..."
```

Remove the pin to follow the chart default, or set it to `3.13.1`. An Identity that stays on `3.11.x` rejects the `m2m.service_roles` field (see the next section).

### Upgrade order: Access Manager before Bank Transfer

Upgrade Access Manager to this chart version before you upgrade or restart Bank Transfer. These Bank Transfer releases declare `m2m.service_roles: [service]` in their permission declaration:

- `plugin-br-bank-transfer` v3.3.0 and later
- `plugin-br-bank-transfer-jd` v3.4.0 and later

Identity `3.11.x` validates the declaration against a schema that does not allow `m2m.service_roles`, so it rejects the declaration. Identity `3.12.0` and later accepts it.

# What the application brings

These changes come from the application releases between `3.11.1` and `3.13.1`. The list covers what operators and integrators can notice. The full list is in the plugin-access-manager changelog.

**Identity**

- **`m2m.service_roles` accepted (3.12.0).** A product can list the roles that internal Lerian service callers assume. A client M2M credential never assumes these roles. `m2m.party_roles` is accepted from 3.13.0.
- **Declared permissions are read-only for clients (3.13.0).** A Lerian product decides which roles hold its declared permissions, and which groups hold its declared roles. The API now refuses changes with `422 IDE-1066` (adding or removing a role on a declared permission) and `422 IDE-1067` (adding or removing a group on a declared role). Change who has access by adding or removing people on the role, or in a group the product already grants it to. Sending a grant that is already held, or removing one that is not held, still answers `204` and writes nothing.
- **Service credentials route (3.13.0).** Single-tenant installs get a service lane for `m2m.service_roles`, and a new route, `POST /v1/applications/service-credentials`, issues the credential that a Lerian service signs in with. Only a person can call it. An application token is refused.
- **The client M2M application gets the editor tier on Identity (3.13.0).**

**Auth**

- **Stricter token and permission checks (3.12.0).** Auth never serves a cached profile or permission past token expiry. It answers `503` when token introspection cannot reach the identity provider. It refuses a revoked client before it reads cached decisions, and an inactive partner token as `actor_invalid`.
- **Partners need a scope line (3.12.0).** Auth refuses a partner with no scope line in a product that declares dimensions, and answers `IDE-1060`.
- **M2M target product inference (3.13.0).** Auth authorizes an M2M credential under its target product when the receiving service forwards none.

# Application Version Update

### Identity Service Image

The default image tag for the identity service has been updated.

**Before (v10.0.2):**

```yaml
identity:
  image:
    tag: "3.11.1"
```

**After (v10.0.3):**

```yaml
identity:
  image:
    tag: "3.13.1"
```

**Impact:**

If you use the default image configuration, the identity deployment performs a rolling update to version 3.13.1. If you set `identity.image.tag` in your values, your override stays in place and nothing changes for identity.

### Auth Service Image

The default image tag for the auth service has been updated.

**Before (v10.0.2):**

```yaml
auth:
  image:
    tag: "3.11.1"
```

**After (v10.0.3):**

```yaml
auth:
  image:
    tag: "3.13.1"
```

**Impact:**

If you use the default image configuration, the auth deployment performs a rolling update to version 3.13.1. If you set `auth.image.tag` in your values, your override stays in place and nothing changes for auth.

### Auth Init User Container

The default image tag for the auth init user job has been updated in the template.

**Before (v10.0.2):**

```yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.11.1" }}"
```

**After (v10.0.3):**

```yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.13.1" }}"
```

**Impact:**

None on an existing release. The init user job is disabled by default (`auth.initUser.enabled: false`). When you enable it, it runs as a Helm `post-install` hook, so it runs on the first `helm install` only. It does not run on `helm upgrade`, and it does not run again when the auth configuration changes or when its completed job is deleted. The new default tag matters only for a new installation with `auth.initUser.enabled: true`. If you set `auth.initUser.image.tag`, your override takes precedence.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.3 -n plugin-access-manager
```
<!-- {% endraw %} -->
