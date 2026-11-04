<!-- {% raw %} -->
# Helm Upgrade from v1.0.3 to v1.0.4

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.3** to **1.0.4**. This is a patch release that updates chart metadata and clarifies RBAC documentation.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.4](#changes-in-v104)**
  - [Chart Metadata Updates](#chart-metadata-updates)
  - [RBAC Documentation Improvements](#rbac-documentation-improvements)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.0.4** is a patch release that updates chart metadata and improves RBAC documentation. There are **no breaking changes**, **no new configuration options**, **no RBAC permission changes**, and **no required operator actions** beyond running `helm upgrade`.

**What changed:**

- Chart `home` URL now points to the specific chart directory
- RBAC comments clarified for StorageClass and ExternalSecret permissions
- Documentation references simplified

**What stayed the same:**

- Application version remains `1.0.2`
- Agent container image tag remains `1.0.2`
- All configuration options remain unchanged
- All RBAC permissions remain unchanged
- All template logic remains unchanged
- All default values remain unchanged

## Changes in v1.0.4

### Chart Metadata Updates

The chart metadata has been updated to improve discoverability and simplify documentation references.

| Setting | v1.0.3 | v1.0.4 |
|---------|--------|--------|
| `home` | `https://github.com/LerianStudio/helm` | `https://github.com/LerianStudio/helm/tree/main/charts/agent` |

**Before (v1.0.3):**

```yaml
home: https://github.com/LerianStudio/helm
```

**After (v1.0.4):**

```yaml
home: https://github.com/LerianStudio/helm/tree/main/charts/agent
```

**Operational impact:**

This change only affects the chart metadata visible in `helm show chart` output and Artifact Hub listings. It does not affect deployed resources or chart behavior.

Additionally, the `kubeVersion` comment has been simplified to remove references to internal deployment tooling. The constraint itself (`>=1.33.0-0`) remains unchanged.

### RBAC Documentation Improvements

The RBAC template comments have been rewritten for clarity. **No permissions were added, removed, or modified.** These changes only affect the inline documentation within the `rbac.yaml` template file.

#### StorageClass Permissions

The comment explaining the agent's StorageClass permissions has been simplified and clarified.

**Before (v1.0.3):**

```yaml
# Cluster-scoped because a StorageClass is. What a holder gets is written out
# in docs/threat-model.md; in short, it can add a class and move which one is
# default, which redirects where FUTURE volumes are provisioned and reaches no
# existing volume or its contents.
#
# This is the ONLY cluster-scoped write the repair path added. The other
# components of the initial set need ClusterRoles, aggregated APIServices and
# admission webhooks, and the threat model says per component why the agent
# did not get those and what an operator installs by hand instead.
```

**After (v1.0.4):**

```yaml
# Cluster-scoped because a StorageClass is. The grant lets the agent add a
# class and change which one is default, which sets where FUTURE volumes are
# provisioned. It does not reach any existing volume or its contents.
#
# Besides namespace creation, this is the only cluster-scoped write the
# agent holds. Components that need ClusterRoles, aggregated APIServices or
# admission webhooks are not installed by the agent; an operator installs
# them by hand.
```

**Operational impact:**

None. The permissions granted remain identical:

```yaml
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

#### ExternalSecret Permissions

The comment explaining the conditional ExternalSecret permissions has been simplified and now directly references the relevant configuration fields.

**Before (v1.0.3):**

```yaml
# Rendered ONLY for a client who configured a vault. A client who left
# agent.secretVault.provider empty never has a Secret with a residence to fill - the
# control plane composes one only for a cluster that REPORTED a vault - so the
# grant would be a standing power nobody exercises. It is not an idle one
# either, for a client who happens to run External Secrets for the rest of
# their estate: `create` on externalsecrets is the ability to write an object
# naming any store this namespace can reach and land its material in a Secret
# here, which the agent may then read. The client-side mitigation in
# docs/threat-model.md - scoping the store's identity to this platform's path
# prefix - is advice only a vault user ever reads, so the grant follows the
# same switch the feature does.
```

**After (v1.0.4):**

```yaml
# Rendered only when agent.secretVault.provider is set. Without a vault there
# is no Secret for External Secrets to fill, so the grant is omitted.
# `create` on externalsecrets lets the agent point an object at any store this
# namespace can reach, so scope the store's identity to this platform's path
# prefix (agent.secretVault.pathPrefix).
```

**Operational impact:**

None. The conditional rendering logic and permissions remain identical:

```yaml
{{- if .Values.agent.secretVault.provider }}
- apiGroups: ["external-secrets.io"]
  resources: ["externalsecrets", "pushsecrets"]
  verbs: ["get", "create", "update"]
{{- end }}
```

> **Note:** If you have configured `agent.secretVault.provider`, ensure that your `agent.secretVault.pathPrefix` is scoped appropriately to limit which secrets the agent can access through External Secrets Operator.

## Migration Steps

This upgrade requires no manual migration steps. No deployed resources will change.

**To upgrade:**

1. Review your current values file (if you have one):

```bash
helm get values agent -n agent > current-values.yaml
```

2. Run the upgrade command (see below)

3. Verify the chart metadata (optional):

```bash
helm show chart oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.4 | grep home
```

> **Note:** Because no resources change, the agent pod will not restart during this upgrade. The only change is to the chart metadata stored in the Helm release.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.4
```
<!-- {% endraw %} -->
