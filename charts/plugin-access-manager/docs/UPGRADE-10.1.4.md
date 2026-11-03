# Helm Upgrade from v10.1.3 to v10.1.4

# Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This release changes the chart documentation only. The chart version moves from 10.1.3 to 10.1.4 in `Chart.yaml`, and the license line in `README.md` now reads Elastic License 2.0 instead of Apache-2.0. No template, `values.yaml` or `values.schema.json` change, and the application version stays at 3.14.0.

**What changed:**

| Setting | v10.1.3 | v10.1.4 |
|---------|---------|---------|
| Chart version | 10.1.3 | 10.1.4 |
| Application version | 3.14.0 | 3.14.0 |
| License stated in `README.md` | Apache-2.0 | Elastic License 2.0 |

**What this means for operators:**

- You do not need to change your values.
- Rendered resources differ from v10.1.3 only in the `helm.sh/chart` label. That label is part of the pod templates of the auth, identity and caradhras Deployments, so the upgrade replaces the pods of all three, even though no image or setting changes. Caradhras rolls with `maxSurge: 1` and `maxUnavailable: 0`. Auth and identity render `maxSurge: 1` and `maxUnavailable: 1` by default (auth runs 3 replicas, identity 1), so identity can be briefly unavailable during the rollout when it runs a single replica.
- `helm diff` is not empty: it shows the `helm.sh/chart` label change on these Deployments and on the other resources that carry the label. With the bundled database and no existing Secret (the default), helm-diff can also show a new random password in the `<release>-auth-database` Secret, because it runs the `lookup` function only with `--dry-run=server`. `helm upgrade` reads the existing Secret and keeps the password.
- The license change is in `README.md` only. No rendered resource carries it.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.4 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.4 -n plugin-access-manager
```
