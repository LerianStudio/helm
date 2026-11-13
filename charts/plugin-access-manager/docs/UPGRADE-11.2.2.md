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

This release updates auth and identity images and also rolls Caradhras because its auth-ConfigMap checksum changes, even though the Caradhras server and migrations images stay at `2.1.0`. Replacement Caradhras pods run the `migrate` init container; inspect its result rather than assuming no database work. Review the authorization impact and recovery preparation below before upgrading.

| Component | v11.2.1 | v11.2.2 |
|-----------|---------|---------|
| Chart version | 11.2.1 | 11.2.2 |
| App version | 3.17.0 | 3.19.0 |
| Identity image tag | 3.17.0 | 3.19.0 |
| Auth image tag | 3.17.0 | 3.19.0 |

**Action required:**

Review partner permissions and image pins, preserve release configuration and credentials, and validate the upgrade in staging.

## Authorization behavior to review

Application 3.19.0 changes the reach of affected partner permission pairs: when a pair granted to the partner also matches its reserved partner role, that matching grant can be tenant-wide even when an editor role also holds the pair. This does not automatically grant every permission to every partner: the pair must still be present in the partner's permissions and the request attributes must be resolved. Review affected reserved-role overlaps and test representative allowed and denied requests before production rollout. The application range also includes manifest scope-reach forwarding changes; do not treat the image bump as behavior-neutral.

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

Identity defaults to an enabled HPA with 2–3 replicas, not a fixed single replica. The locked common-library strategy renders `maxSurge: "25%"` and `maxUnavailable: 0`. Ensure surge capacity and working readiness probes; this Kubernetes strategy is not a guarantee of uninterrupted application service.

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

Auth defaults to an enabled HPA with 3–9 replicas. Its strategy is `maxSurge: "25%"`, `maxUnavailable: 0`; with HPA enabled the Deployment does not fix `spec.replicas`. Validate readiness, capacity and dependencies instead of assuming either inevitable single-replica downtime or guaranteed uninterrupted service.

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

# Prepare and preserve configuration

1. Record the installed revision and back up release values/manifest privately. Outputs may contain secrets; never commit or paste them.

   ```bash
   umask 077
   mkdir -p private-upgrade-backup
   helm history plugin-access-manager -n midaz-plugins > private-upgrade-backup/history.txt
   helm get values plugin-access-manager -n midaz-plugins -o yaml > private-upgrade-backup/values.yaml
   helm get manifest plugin-access-manager -n midaz-plugins > private-upgrade-backup/manifest.yaml
   ```

2. Construct `values-11.2.2.yaml` as the **complete intended configuration**, preserving unrelated settings, image decisions, datastore endpoints, storage, license and existing Secret references. Preserve the application-client secret: do not generate replacement credentials. Remove or update retired image pins intentionally; the partial snippets above are not a complete configuration.
3. Take a consistent PostgreSQL backup and verify the restore procedure before upgrading. Caradhras replacement pods execute the unchanged migrator, which may migrate or no-op depending on the deployed schema. Check actual results; a render does not prove migration safety.
4. Validate allowed/denied permission cases and the full rollout in staging before production. No live install, migration, upgrade or restore was exercised by the source/render validation behind this guide.

Both commands use `--reset-values` and the same complete file so removed overrides do not silently return. A partial file would discard unrelated settings. Review the entire diff, including Secrets and storage, before applying.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.2 --reset-values -f values-11.2.2.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.2 --reset-values -f values-11.2.2.yaml --wait --timeout 10m
```

# Verify and recover

Discover actual auth, identity and Caradhras Deployment names from the rendered manifest. Check each rollout/readiness result, inspect the `migrate` init-container outcome privately, and smoke-test authentication, token issuance and representative allowed/denied permissions. Redact logs before sharing them.

If rollback is necessary, replace `PREVIOUS_REVISION` with the recorded Helm revision:

```bash
helm rollback plugin-access-manager PREVIOUS_REVISION -n midaz-plugins --wait --timeout 10m
```

Helm rollback does not restore PostgreSQL contents or reverse schema changes. Check old-image/schema compatibility first; if database recovery is needed, stop the rollout and follow the reviewed restore/cutover procedure. Do not assume an application rollback undoes migrator writes.
