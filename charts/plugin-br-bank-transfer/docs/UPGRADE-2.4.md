# Helm Upgrade from v2.3.1 to v2.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. ENVIRONMENT_NAME replaces ENV_NAME](#1-environment_name-replaces-env_name)
  - [2. Licence settings](#2-licence-settings)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.4.0 needs no change to your values, unless an install left its environment name blank (see [ENVIRONMENT_NAME replaces ENV_NAME](#1-environment_name-replaces-env_name)). Newer app images read `ENVIRONMENT_NAME` and older ones read `ENV_NAME`; the chart renders both with one value, so every image reads the right environment.

The licence settings change too: `LICENSE_SERVICE_ADDRESS` is no longer rendered.

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

A blank, whitespace-only or null value counts as unset at every level, so it falls through to the next source.

> **Warning:** Earlier charts rendered a blank name as an empty `ENV_NAME`, and the app booted with an empty environment name: neither its production checks nor its development relaxations applied. The shipped `values-template.yaml` (`global.env.name: ""`) did exactly that. This chart renders `"production"` instead, so an install that left the name blank now boots under the production checks. If such an install is not production, set its name explicitly before upgrading.

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

> **Warning:** Setting both keys to different values fails the render, because the deployment would name two environments: `bankTransfer.configmap.ENVIRONMENT_NAME ("staging") and bankTransfer.configmap.ENV_NAME ("production") name two environments: set only ENVIRONMENT_NAME, ENV_NAME is its deprecated alias`. Setting both to the same value renders normally.

The chart keeps emitting `ENV_NAME` until the app drops the fallback.

### 2. Licence settings

**What changed:**

- `LICENSE_SERVICE_ADDRESS` is no longer rendered. The app never passed it to the licence client, which picks its gateway itself, and newer app images no longer read it. Delete `bankTransfer.configmap.LICENSE_SERVICE_ADDRESS` from your values; a leftover entry is ignored.
- `IS_DEVELOPMENT` is deprecated and ignored: the chart does not render it, and products validate licences only on the production gateway.

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
