<!-- {% raw %} -->
# Helm Upgrade from v1.0.2 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[What changed](#what-changed)**
- **[Permission declaration (RI)](#permission-declaration-ri)**
  - [Configuration reference](#configuration-reference)
  - [Enable the declaration](#enable-the-declaration)
- **[Operational impact](#operational-impact)**
- **[Migration steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Chart 1.1.0 adds the chart wiring for the Access Manager permission declaration (RI). The declaration is off by default. If you do not enable it, you do not need to change your values.

The application version does not change. Chart 1.0.2 already deployed `ghcr.io/lerianstudio/system-facts:1.1.0`, and `appVersion` was already `1.1.0`. The default tags of the migrations image and of the worker image are also `1.1.0` in both chart versions.

## What changed

| Item | v1.0.2 | v1.1.0 |
|------|--------|--------|
| Chart version | `1.0.2` | `1.1.0` |
| `lerian-common-helm` dependency | `2.0.0` | `2.4.0` |
| New value `global.idp` (`host`, `declarationEnabled`) | no | yes, default `{}` |
| New values `system-facts.secrets.IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` | no | yes, default empty |
| ConfigMap key `IDP_DECLARATION_ENABLED` | not rendered | always rendered, default `"false"` |
| ConfigMap key `IDP_HOST` | not rendered | rendered only when not empty |

`values.schema.json` now describes `IDP_DECLARATION_ENABLED` and `IDP_HOST` under `system-facts.configmap`, and the two client keys under `system-facts.secrets`. The `lerian-common-helm` helpers `lerian-common.idp.env`, `lerian-common.idp.secret` and `lerian-common.idp.keys` render these keys. Helm pulls the new dependency version when it packages the chart, so you do not need to do anything for it.

## Permission declaration (RI)

When the gate is on, the System Facts API publishes its embedded `permissions.yaml` to the Access Manager at boot. The worker never declares and renders none of these keys.

### Configuration reference

| Key | Where to set it | Rendered in |
|-----|-----------------|-------------|
| `IDP_DECLARATION_ENABLED` | `system-facts.configmap`, then a `system-facts.extraEnvVars` entry (legacy), then `global.idp.declarationEnabled` | ConfigMap, always, default `"false"` |
| `IDP_HOST` | same order, with `global.idp.host` | ConfigMap, only when not empty |
| `IDP_M2M_CLIENT_ID`, `IDP_M2M_CLIENT_SECRET` | `system-facts.secrets` | Secret, each only when not empty |

The first source in the order wins. An `IDP_DECLARATION_ENABLED` or `IDP_HOST` entry in `system-facts.extraEnvVars` still works. The template now feeds it to the helper and skips it in the raw passthrough, so the key appears once.

> **Warning:** `global.idp.declarationEnabled: true` turns the gate on for every component of the release that reads `global.idp`, and each one then needs its own client pair. Set the gate in `system-facts.configmap.IDP_DECLARATION_ENABLED` to enable it only for System Facts.

> **Warning:** The chart does not validate the combination. With the gate on, the application refuses to boot when the host or the client pair is missing. Set all three values before you enable the gate.

### Enable the declaration

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity:4001"

system-facts:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
  secrets:
    IDP_M2M_CLIENT_ID: "<client-id>"
    IDP_M2M_CLIENT_SECRET: "<client-secret>"
```

Do not commit the client secret to a values file. Pass it from your secret store, or keep it in an existing Secret.

With `system-facts.useExistingSecret: true`, the chart does not render its own Secret. Put `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` in the Secret named by `system-facts.existingSecretName`, next to the keys that Secret already holds (for example `POSTGRES_PASSWORD`). Add the two keys to that Secret without replacing the existing ones.

## Operational impact

- The System Facts pods roll once. The pod template carries the `helm.sh/chart` label, and the ConfigMap now has the new `IDP_DECLARATION_ENABLED` key, so the config checksum annotation changes as well. This happens even when you do not enable the declaration.
- No image tag changes. The `system-facts` image stays on `1.1.0`.
- The ConfigMap gains `IDP_DECLARATION_ENABLED: "false"` when you do not enable the declaration. That value keeps the application behavior as it was.

## Migration steps

### Step 1: Decide whether to enable the declaration

If you do not need it, skip to Step 3.

If you need it, get the Access Manager identity URL and an M2M client ID and secret for System Facts, and prepare the values from [Enable the declaration](#enable-the-declaration).

### Step 2: Check your current values

```bash
helm get values system-facts -n system-facts -o yaml
```

This shows only the values you set. If you set `IDP_DECLARATION_ENABLED` or `IDP_HOST` in `system-facts.extraEnvVars`, they keep working.

### Step 3: Upgrade

Use your values file, so new chart defaults apply:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.1.0 \
  -n system-facts \
  -f values.yaml
```

If you have no values file, use `--reset-then-reuse-values` instead of `--reuse-values`. `--reuse-values` keeps the values of the old release and does not apply the new chart defaults, such as `global.idp`.

### Step 4: Verify

Check the rollout:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

Check the rendered keys. These commands do not print the client secret:

```bash
kubectl get configmap system-facts -n system-facts -o jsonpath='{.data.IDP_DECLARATION_ENABLED}{"\n"}{.data.IDP_HOST}{"\n"}'
kubectl get secret system-facts -n system-facts -o jsonpath='{.data}' | grep -o 'IDP_M2M_CLIENT_[A-Z]*'
```

The chart names the Deployment, ConfigMap and Secret `system-facts`, whatever the release name is. The Secret exists only when `useExistingSecret` is `false`. With an existing Secret, check that Secret instead.

If you enabled the declaration and the pod does not become ready, read its log for the missing host or client pair.

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.0 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.0 -n system-facts
```
<!-- {% endraw %} -->
