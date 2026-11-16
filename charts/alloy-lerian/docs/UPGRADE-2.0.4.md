# Helm Upgrade from v2.0.3 to v2.0.4

This guide covers the upgrade from `alloy-lerian` chart version **2.0.3** to **2.0.4**. This patch release upgrades the Grafana Alloy binary from v1.18.1 to v1.21.3 and updates the upstream Alloy chart dependency from v1.11.1 to v1.15.0.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Alloy Binary Upgrade](#1-alloy-binary-upgrade)
  - [2. Upstream Chart Dependency Upgrade](#2-upstream-chart-dependency-upgrade)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Alloy Binary Upgrade

The chart now pins Grafana Alloy binary version **v1.21.3** (previously v1.18.1) for both node and singleton roles.

| Setting | v2.0.3 | v2.0.4 |
|---------|--------|--------|
| `appVersion` | `1.18.1` | `1.21.3` |
| `node.image.tag` | `v1.18.1` | `v1.21.3` |
| `node.image.digest` | `sha256:0f4434c92b3e6cdac38bb129b344e1790c246f7b6e2eaffcc16a5fa363240e33` | `sha256:8ab871206bd2d8f89277f53abffee5f452a293980788d52f85fa183a87a505a4` |
| `singleton.image.tag` | `v1.18.1` | `v1.21.3` |
| `singleton.image.digest` | `sha256:0f4434c92b3e6cdac38bb129b344e1790c246f7b6e2eaffcc16a5fa363240e33` | `sha256:8ab871206bd2d8f89277f53abffee5f452a293980788d52f85fa183a87a505a4` |

**What changed:**

The Alloy binary is upgraded from v1.18.1 to v1.21.3, bringing three minor version increments (1.19, 1.20, 1.21). The image digest is updated to match the new tag.

**What this means:**

- The agent will run Alloy v1.21.3 after upgrade
- The digest pin ensures the exact binary is deployed (tags are mutable, digests are not)

**Migration Steps:**

No action required. The upgrade is automatic when you run `helm upgrade`. The DaemonSet (node role) will perform a rolling update, and the Deployment (singleton role) will recreate its pod.

> **Note:** The chart uses `digest` to pin the exact image. Even if the `v1.21.3` tag is republished pointing to different bits, the digest ensures the same binary is deployed across all environments.

### 2. Upstream Chart Dependency Upgrade

The chart now depends on the upstream `grafana/alloy` chart version **1.15.0** (previously 1.11.1) for both node and singleton roles.

| Setting | v2.0.3 | v2.0.4 |
|---------|--------|--------|
| `dependencies[0].version` (node) | `1.11.1` | `1.15.0` |
| `dependencies[1].version` (singleton) | `1.11.1` | `1.15.0` |

**What changed:**

The upstream Grafana Alloy Helm chart dependency is upgraded from v1.11.1 to v1.15.0, bringing four minor version increments (1.12, 1.13, 1.14, 1.15).

**What this means:**

- The chart inherits any fixes, features, or breaking changes from the upstream chart versions 1.12.0 through 1.15.0
- The upstream chart controls the structure of the DaemonSet, Deployment and Service resources
- Any values passed to `node.*` or `singleton.*` are forwarded to the upstream chart

**Migration Steps:**

No action required. The upgrade is automatic when you run `helm upgrade`.

> **Important:** If you have overridden any values under `node.*` or `singleton.*` that are not documented in this chart's `values.yaml`, verify compatibility with the upstream chart v1.15.0. Check the [upstream changelog](https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/CHANGELOG.md) for breaking changes.


---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.4 -n monitoring -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm --version 2.0.4 -n monitoring -f values.yaml
```
