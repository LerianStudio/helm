# Helm Upgrade from v2.3.1 to v2.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. ENVIRONMENT_NAME replaces ENV_NAME](#1-environment_name-replaces-env_name)
  - [2. Licence settings](#2-licence-settings)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.4.0 needs no change to your values. The chart now emits the environment name as `ENVIRONMENT_NAME`, the key the Bank Transfer app reads from now on, and keeps emitting `ENV_NAME` with the same value. Every app image therefore reads the right environment, whichever one this chart runs.

The licence settings change too: `LICENSE_SERVICE_ADDRESS` is no longer rendered, and `IS_DEVELOPMENT` can be set to reach the development licence gateway.

## Features

### 1. ENVIRONMENT_NAME replaces ENV_NAME

**What changed:**

`bankTransfer.configmap.ENVIRONMENT_NAME` is the canonical key. `bankTransfer.configmap.ENV_NAME` is deprecated and still honoured. The chart resolves the name once, in this order, and renders it under both keys:

| Order | Source | Note |
|-------|--------|------|
| 1 | `bankTransfer.configmap.ENVIRONMENT_NAME` | Canonical |
| 2 | `bankTransfer.configmap.ENV_NAME` | Deprecated, still honoured |
| 3 | `global.env.name` | Env-wide default shared with other charts |
| 4 | `"production"` | Chart default, unchanged |

App images that read `ENVIRONMENT_NAME` fall back to `ENV_NAME` with a deprecation warning. With this chart they find both keys and log nothing. Older images read only `ENV_NAME`, which keeps its value.

**Operator action:** rename `bankTransfer.configmap.ENV_NAME` to `bankTransfer.configmap.ENVIRONMENT_NAME` when convenient. The rendered ConfigMap is identical either way.

**Before:**

```yaml
bankTransfer:
  configmap:
    ENV_NAME: "staging"
```

**After:**

```yaml
bankTransfer:
  configmap:
    ENVIRONMENT_NAME: "staging"
```

Both render:

```yaml
ENVIRONMENT_NAME: "staging"
ENV_NAME: "staging"
```

> **Warning:** Setting both keys to different values fails the render, because the deployment would name two environments: `bankTransfer.configmap.ENVIRONMENT_NAME ("staging") and bankTransfer.configmap.ENV_NAME ("production") name two environments: set only ENVIRONMENT_NAME, ENV_NAME is its deprecated alias`. Setting both to the same value renders normally.

The chart keeps emitting `ENV_NAME` until the app drops the fallback.

### 2. Licence settings

**What changed:**

- `LICENSE_SERVICE_ADDRESS` is no longer rendered. The app never passed it to the licence client, which picks its gateway itself, and newer app images no longer read it. Delete `bankTransfer.configmap.LICENSE_SERVICE_ADDRESS` from your values; a leftover entry is ignored.
- `IS_DEVELOPMENT` is a new optional key, rendered in both tenancy modes only when set. lib-license-go reads it: exactly `"true"` selects the development licence gateway, which a development licence key needs.

```yaml
bankTransfer:
  configmap:
    IS_DEVELOPMENT: "true"   # only with a development licence key
```

> **Important:** Newer app images refuse to boot without `bankTransfer.secrets.LICENSE_KEY` and `ORGANIZATION_IDS` in every environment, not only in production. Set both in development, staging and homologation before moving those environments to such an image. The chart does not check either value.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.4.0 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.4.0 -n plugin-br-bank-transfer
```
