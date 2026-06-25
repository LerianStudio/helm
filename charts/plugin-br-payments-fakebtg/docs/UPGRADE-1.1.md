# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [Chart Deprecation](#chart-deprecation)
  - [Migration to helm-internal Repository](#migration-to-helm-internal-repository)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.1.0 marks the **deprecation** of the `plugin-br-payments-fakebtg-helm` chart in the current repository. The chart has been moved to the `helm-internal` repository and is now available at a new OCI registry location. This is a **non-breaking deprecation**: v1.1.0 remains fully functional and can be deployed, but operators should plan to migrate to the new chart location for future updates.

**What changed:**

- The chart is now marked as `deprecated: true` in `Chart.yaml`
- The chart description has been updated to indicate the new location
- A new annotation `lerian.studio/chart-type: single-service` has been added for internal tooling
- A no-op comment was added to `values.yaml` to trigger the release

**What stays the same:**

- All templates, values schema, and runtime behavior remain identical
- The `appVersion` is unchanged (`1.0.0-beta.22`)
- All configuration options from v1.0.0 continue to work

> **Important:** This upgrade does not require any immediate action. The chart will continue to function normally. However, you should plan to migrate to the new chart location before the next feature release.

## Breaking Changes

### Chart Deprecation

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `deprecated` field in `Chart.yaml` | Not set (implicitly `false`) | `true` |
| Chart description | `A Helm chart for fakebtg, the BTG provider API stand-in used by plugin-br-payments dev/staging environments` | `[DEPRECATED] Moved to helm-internal. Use oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm instead.` |

**Why it matters:**

The chart is now officially deprecated. Helm will display a deprecation warning when you install or upgrade to v1.1.0:

```
WARNING: This chart is deprecated
```

The chart remains fully functional, but no new features will be added to this repository location. Future updates (v1.2.0 and beyond) will only be published to the new `helm-internal` repository.

**Action required:**

None immediately. You can safely upgrade to v1.1.0 and continue using the chart. However, you should:

1. Plan to migrate to the new chart location before the next major version
2. Update your CI/CD pipelines and documentation to reference the new OCI registry
3. Monitor the new repository for future updates

> **Warning:** The current chart location (`oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm`) will not receive updates beyond v1.1.0. All future releases will be published exclusively to `oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm`.

### Migration to helm-internal Repository

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| Chart registry | `oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm` | `oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm` (recommended for future use) |
| Chart annotation `lerian.studio/chart-type` | Not set | `single-service` |

**Why it matters:**

The chart has been moved to a new OCI registry hosted on GitHub Container Registry (GHCR). The new location consolidates internal charts into a single repository for better maintainability and access control.

The `lerian.studio/chart-type: single-service` annotation is used by internal tooling to classify the chart. It has no operational impact on deployments.

**Action required:**

To prepare for future updates, update your Helm repository references:

**Before (v1.0.0):**

```bash
helm install plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm \
  --version 1.0.0 \
  -n plugin-br-payments-fakebtg
```

**After (v1.1.0 and beyond):**

```bash
helm install plugin-br-payments-fakebtg oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm \
  --version 1.1.0 \
  -n plugin-br-payments-fakebtg
```

> **Note:** The chart name remains `plugin-br-payments-fakebtg-helm` in both locations. Only the registry URL changes.

**Authentication for the new registry:**

If your cluster does not already have access to `ghcr.io/lerianstudio/helm-internal`, you may need to configure authentication:

```bash
# Create a GitHub personal access token with read:packages scope
# Then create an image pull secret
kubectl create secret docker-registry ghcr-lerianstudio \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-token> \
  -n plugin-br-payments-fakebtg
```

Add the secret to your values file:

```yaml
fakebtg:
  imagePullSecrets:
    - name: ghcr-lerianstudio
```

> **Important:** The new registry may have different access controls than the previous Docker Hub registry. Verify that your CI/CD pipelines and cluster nodes can authenticate to `ghcr.io` before migrating.

## Configuration Reference

### New Annotations

v1.1.0 adds a new chart-level annotation for internal tooling:

| Annotation | Value | Description |
|------------|-------|-------------|
| `lerian.studio/chart-type` | `single-service` | Classifies the chart as a single-service deployment for internal automation |

**Why it matters:**

This annotation is used by Lerian Studio's internal chart management tooling. It does not affect the chart's runtime behavior or configuration.

**Action required:**

None. This annotation is informational only and does not require any changes to your values files or deployment configuration.

### Values Schema Changes

The only change to `values.yaml` is a no-op comment at the end of the file:

**Before (v1.0.0):**

```yaml
plugin-br-payments-fakebtg:
  image:
    tag: 1.0.0-beta.20
```

**After (v1.1.0):**

```yaml
plugin-br-payments-fakebtg:
  image:
    tag: 1.0.0-beta.20

# ci: re-trigger release — cancelled in run 27577375728 after PR #1470 (no-op)
```

**Why it matters:**

This comment was added to trigger a new chart release after a CI/CD pipeline cancellation. It has no functional impact.

**Action required:**

None. Your existing values files will continue to work without modification.

## Migration Steps

### Step 1: Upgrade to v1.1.0 (Current Registry)

First, upgrade your existing deployment to v1.1.0 using the current registry:

```bash
helm upgrade plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm \
  --version 1.1.0 \
  -n plugin-br-payments-fakebtg
```

Verify the upgrade:

```bash
kubectl get pods -n plugin-br-payments-fakebtg
helm list -n plugin-br-payments-fakebtg
```

Expected output:

```
NAME                          	NAMESPACE                     	REVISION	UPDATED                                	STATUS  	CHART                                 	APP VERSION
plugin-br-payments-fakebtg    	plugin-br-payments-fakebtg    	2       	2024-01-15 10:30:00.000000000 +0000 UTC	deployed	plugin-br-payments-fakebtg-helm-1.1.0 	1.0.0-beta.22
```

> **Note:** You will see a deprecation warning during the upgrade. This is expected and does not indicate a problem.

### Step 2: Verify Authentication to New Registry

Before migrating to the new registry, verify that you can authenticate to `ghcr.io`:

```bash
helm pull oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm --version 1.1.0
```

If authentication fails, create an image pull secret (see [Migration to helm-internal Repository](#migration-to-helm-internal-repository)).

### Step 3: Plan Migration to New Registry

Once you have verified access to the new registry, plan your migration:

1. **Update CI/CD pipelines**: Replace all references to `oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm` with `oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm`

2. **Update documentation**: Update runbooks, deployment guides, and infrastructure-as-code repositories to reference the new registry

3. **Test in staging**: Deploy from the new registry to a staging environment before updating production:

```bash
helm upgrade plugin-br-payments-fakebtg oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm \
  --version 1.1.0 \
  -n plugin-br-payments-fakebtg-staging
```

4. **Schedule production migration**: Plan a maintenance window to switch production deployments to the new registry

> **Important:** The migration from the old registry to the new registry is a **Helm release metadata change only**. Kubernetes resources will not be recreated. However, Helm will update the release metadata to point to the new chart location.

### Step 4: Migrate Production to New Registry

When ready, migrate your production deployment:

```bash
helm upgrade plugin-br-payments-fakebtg oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm \
  --version 1.1.0 \
  -n plugin-br-payments-fakebtg
```

Verify the migration:

```bash
helm list -n plugin-br-payments-fakebtg
```

The `CHART` column should now show the new registry location.

### Step 5: Monitor for Future Updates

After migrating to the new registry, monitor the `helm-internal` repository for future updates:

```bash
helm search repo oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm --versions
```

> **Note:** The old registry location will not receive updates beyond v1.1.0. Subscribe to the new repository's release notifications to stay informed about new versions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm --version 1.1.0 -n plugin-br-payments-fakebtg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments-fakebtg oci://registry-1.docker.io/lerianstudio/plugin-br-payments-fakebtg-helm --version 1.1.0 -n plugin-br-payments-fakebtg
```
