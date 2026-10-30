# Helm Upgrade from v5.0.x to v5.1.0

## Topics

- **[Overview](#overview)**
- **[Before you upgrade](#before-you-upgrade)**
  - [1. Provide a license to the manager and the worker](#1-provide-a-license-to-the-manager-and-the-worker)
  - [2. Write every boolean as true or false](#2-write-every-boolean-as-true-or-false)
  - [3. Roll the worker before the manager](#3-roll-the-worker-before-the-manager)
- **[New: regulatory catalog](#new-regulatory-catalog)**
- **[Behaviour change: institutions scope classic reports](#behaviour-change-institutions-scope-classic-reports)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release moves the chart to Reporter **4.6.0** and teaches it what that version requires.

| Field | v5.0.x | v5.1.0 |
|-------|--------|--------|
| App version | `4.5.x` | `4.6.0` |
| Default `manager.image.tag` / `worker.image.tag` | `4.5.x` | `4.6.0` |

If your values pin `manager.image.tag` or `worker.image.tag`, the pin wins over the chart default: set both to `4.6.0`, as the commands below do.

Chart changes:

- **`reporter.licenseKeyRequired`**: for an image tag `>= 4.6.0`, the chart refuses to render the manager or the worker Secret without `secrets.LICENSE_KEY`. Releases that still run `4.5.x`, or a floating tag such as `latest`, render as before. A component with `useExistingSecret: true` is not checked, because the chart cannot see that Secret.
- `values.yaml` documents `LICENSE_KEY`, `ORGANIZATION_IDS` and the regulatory catalog settings. All are commented out, so nothing new is rendered unless you set it.

## Before you upgrade

### 1. Provide a license to the manager and the worker

Reporter 4.6.0 requires `LICENSE_KEY` in **every** run mode. The worker refuses to boot without it too; before 4.6.0, only the manager checked.

- **Chart-managed Secret:** set `secrets.LICENSE_KEY`. Set `secrets.ORGANIZATION_IDS` too when the license is per organization; it defaults to `global` when unset. Both are rendered into the manager and the worker Secrets.
- **Existing Secret** (`manager.useExistingSecret` / `worker.useExistingSecret`): make sure the Secret both components mount carries `LICENSE_KEY`.

Without it, the render fails with `secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0`. With an existing Secret that lacks it, the pods never become ready.

### 2. Write every boolean as true or false

Reporter 4.6.0 reads boolean environment variables strictly. `TRUE`, `True`, `1`, `yes` or `on` make it refuse to boot. Write `"true"` or `"false"` in `common.configmap`, `manager.configmap`, `worker.configmap` and every `extraEnvVars`.

### 3. Roll the worker before the manager

A 4.6.0 manager publishes generation messages in `schemaVersion` 3 (regulatory filings) and 4 (institution scope). A 4.5.x worker refuses them permanently (`RPT-0136`). One `helm upgrade` rolls both Deployments together, and nothing in the chart orders them, so upgrade in two steps — see [Command to upgrade](#command-to-upgrade). If you upgrade in one step, generations requested while only the manager is on 4.6.0 fail and must be requested again.

## New: regulatory catalog

Reporter 4.6.0 can file curated regulatory documents (CADOC 4010, 4016 and 4111) from Lerian's catalog. It is **off** until the manager is told where the catalog is:

```yaml
manager:
  configmap:
    REGULATORY_CATALOG_GITHUB_REPO: "LerianStudio/lerian-regulatory-catalog"
    REGULATORY_CATALOG_CHANNEL: "stable"
```

- **`REGULATORY_CATALOG_CHANNEL`:** `stable` is the default and reads only releases (production). `rc` reads release candidates and never a beta (staging). `beta` reads the newest of any kind (development).
- **No token.** The catalog repository is public.
- **Releases are verified offline.** Every release must carry its Sigstore attestation, which the app checks against the root of trust it embeds. A release without one is refused with `RPT-0155`. There is no key to configure.
- **Worker:** the GitHub settings go on the manager only. The worker does not read them. The exception is a mounted catalog (`REGULATORY_CATALOG_DIR`, for development), which the worker reads too: set it for both components and mount the tree in both pods.
- **Private mirror:** only a private mirror needs `REGULATORY_CATALOG_GITHUB_TOKEN`. It is a credential: put it under `secrets`, not in a configmap.
- **While unset:** the regulatory endpoints answer `RPT-0147`, and every other feature works as before.

## Behaviour change: institutions scope classic reports

4.6.0 introduces **institutions**: the regulatory declarants of a tenant, each with its CNPJ and the rows of each data source that belong to it. They change classic template reports and deadlines too:

| Institutions in the tenant | A report or deadline that names none |
|---|---|
| none | reads everything, as before |
| one | reads only that institution's scope, and is refused if the template reads a table outside it |
| several | is refused; name one, or `all` (the console offers "All institutions") |

A tenant that registers its first institution to start filing should either cover, in that institution's scope, every table its templates read, or set its deadlines to `all`.

## Preview changes before upgrading

Pass the same values you deploy with, so the license reaches the render:

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter \
  -f values.yaml \
  --set manager.image.tag=4.6.0 --set worker.image.tag=4.6.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

`values.yaml` is the values file you deploy with: it must carry `secrets.LICENSE_KEY` (or point both components at an existing Secret that does). Without it the render fails for 4.6.0, by design.

**Step 1 — the worker first.** The manager stays on its current tag (`4.5.1` here; use yours):

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter \
  -f values.yaml \
  --set worker.image.tag=4.6.0 --set manager.image.tag=4.5.1 \
  --wait --timeout 10m
kubectl -n reporter rollout status deployment -l app.kubernetes.io/name=reporter-worker --timeout=10m
```

With KEDA (`keda.enabled` or `keda.external`) the worker runs as a ScaledJob and has no Deployment to wait on; `--wait` covers the rest.

**Step 2 — the manager:**

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter \
  -f values.yaml \
  --set worker.image.tag=4.6.0 --set manager.image.tag=4.6.0 \
  --wait --timeout 10m
```

GitOps (helmfile + Argo CD): bump `worker.image.tag` in one commit, let it sync healthy, then bump `manager.image.tag`.
