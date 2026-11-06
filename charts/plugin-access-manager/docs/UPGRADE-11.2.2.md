# Helm Upgrade from v11.2.1 to v11.2.2

# Topics

- **[Overview](#overview)**
- **[Application Version Updates](#application-version-updates)**
  - [1. Identity Service Image Update](#1-identity-service-image-update)
  - [2. Auth Service Image Update](#2-auth-service-image-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that upgrades the application version from `3.17.0` to `3.19.0`. The chart increments both the identity and auth service image tags to align with the new application version.

**What changed:**

- Application version (appVersion) bumped from `3.17.0` to `3.19.0`
- Identity service image tag updated from `3.17.0` to `3.19.0`
- Auth service image tag updated from `3.17.0` to `3.19.0`
- No template file changes
- No configuration structure changes
- No new values or removed values

**What this means for operators:**

This release updates the container images for the identity and auth services. The upgrade will trigger a rolling restart of the identity and auth pods to deploy the new image versions. No configuration changes are required unless you have explicitly overridden the image tags in your values.

| Component | v11.2.1 | v11.2.2 |
|-----------|---------|---------|
| Chart version | 11.2.1 | 11.2.2 |
| App version | 3.17.0 | 3.19.0 |
| Identity image tag | 3.17.0 | 3.19.0 |
| Auth image tag | 3.17.0 | 3.19.0 |

**Action required:**

None, unless you have pinned image tags in your values. If you override `identity.image.tag` or `auth.image.tag` in your `values.yaml`, review whether you want to adopt the new versions or continue using your pinned tags.

# Application Version Updates

### 1. Identity Service Image Update

**What changed:**

The identity service image tag has been updated from `3.17.0` to `3.19.0`.

**Before (v11.2.1):**

```yaml
identity:
  image:
    tag: "3.17.0"
```

**After (v11.2.2):**

```yaml
identity:
  image:
    tag: "3.19.0"
```

**Why this matters:**

The identity service will be upgraded to version `3.19.0`, which may include bug fixes, security patches, or minor feature improvements between versions `3.17.0` and `3.19.0`. Consult the application's release notes for details on what changed in versions `3.18.0` and `3.19.0`.

**Operational impact:**

The identity Deployment will perform a rolling update. By default, the identity service runs with 1 replica. During the rollout, the old pod will be terminated and a new pod with the `3.19.0` image will start. If you run a single replica, expect brief unavailability during the pod replacement.

If you have scaled identity to multiple replicas, the rolling update strategy (`maxSurge: 1`, `maxUnavailable: 1`) allows one new pod to start before an old pod stops, minimizing downtime.

**What operators need to do:**

If you have **not** overridden `identity.image.tag` in your values, the upgrade will automatically apply the new tag. No action required.

If you **have** overridden `identity.image.tag` in your `values.yaml`:

```yaml
identity:
  image:
    tag: "3.17.0"  # Your custom override
```

You must decide whether to:

- Remove the override and adopt the chart's default (`3.19.0`)
- Update your override to `3.19.0` explicitly
- Keep your pinned version (not recommended unless you have a specific reason)

### 2. Auth Service Image Update

**What changed:**

The auth service image tag has been updated from `3.17.0` to `3.19.0`.

**Before (v11.2.1):**

```yaml
auth:
  image:
    tag: "3.17.0"
```

**After (v11.2.2):**

```yaml
auth:
  image:
    tag: "3.19.0"
```

**Why this matters:**

The auth service will be upgraded to version `3.19.0`, which may include bug fixes, security patches, or minor feature improvements between versions `3.17.0` and `3.19.0`. Consult the application's release notes for details on what changed in versions `3.18.0` and `3.19.0`.

**Operational impact:**

The auth Deployment will perform a rolling update. By default, the auth service runs with 3 replicas. The rolling update strategy (`maxSurge: 1`, `maxUnavailable: 1`) allows one new pod to start before an old pod stops. With 3 replicas, at least 2 pods will remain available during the rollout, ensuring no service disruption.

If you have scaled auth to a single replica, expect brief unavailability during the pod replacement.

**What operators need to do:**

If you have **not** overridden `auth.image.tag` in your values, the upgrade will automatically apply the new tag. No action required.

If you **have** overridden `auth.image.tag` in your `values.yaml`:

```yaml
auth:
  image:
    tag: "3.17.0"  # Your custom override
```

You must decide whether to:

- Remove the override and adopt the chart's default (`3.19.0`)
- Update your override to `3.19.0` explicitly
- Keep your pinned version (not recommended unless you have a specific reason)

> **Important:** If you maintain custom image tag overrides, ensure they are compatible with the chart version you are deploying. Mismatched versions between services can cause integration issues.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.2
```
