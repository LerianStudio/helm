# Helm Upgrade from v10.1.2 to v10.1.3

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This release changes the chart documentation only. The chart version moves from 10.1.2 to 10.1.3 in `Chart.yaml`, and `README.md` gains a note on keeping the Caradhras ingress internal. No template, `values.yaml` or `values.schema.json` change, and the application version stays at 3.14.0.

**What changed:**

| Setting | v10.1.2 | v10.1.3 |
|---------|---------|---------|
| Chart version | 10.1.2 | 10.1.3 |
| Application version | 3.14.0 | 3.14.0 |

**What this means for operators:**

- You do not need to change your values.
- Rendered resources differ from v10.1.2 only in the `helm.sh/chart` label. That label is part of the pod templates of the auth, identity and caradhras Deployments, so the upgrade replaces the pods of all three, even though no image or setting changes. Caradhras rolls with `maxSurge: 1` and `maxUnavailable: 0`. Auth and identity render `maxSurge: 1` and `maxUnavailable: 1` by default (auth runs 3 replicas, identity 1), so identity can be briefly unavailable during the rollout when it runs a single replica.
- If you expose Caradhras through an ingress, read the new README note and keep that ingress internal.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.3 -n plugin-access-manager
```
