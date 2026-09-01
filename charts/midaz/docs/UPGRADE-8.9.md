# Helm Upgrade from v8.8.0 to v8.9.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 3.8.2](#1-application-version-bump-to-382)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 3.8.2

The midaz application has been upgraded from version `3.8.1` to `3.8.2`. This is a patch release that includes bug fixes and minor improvements to the core application components.

**What changed:**

| Component | v8.8.0 | v8.9.0 |
|-----------|--------|--------|
| Chart version | 8.8.0 | 8.9.0 |
| App version | 3.8.1 | 3.8.2 |
| Ledger image tag | 3.8.1 | 3.8.2 |
| CRM image tag | 3.8.1 | 3.8.2 |

**Why it matters:**

This patch release ensures that all midaz services (ledger and CRM) are running the latest stable version with recent bug fixes and performance improvements. The upgrade maintains backward compatibility with existing configurations.

**How to handle it:**

No configuration changes are required. The image tags will be automatically updated during the Helm upgrade process. The new container images will be pulled according to your configured `pullPolicy`:

- Ledger service uses `pullPolicy: IfNotPresent` by default
- CRM service uses `pullPolicy: Always` by default

> **Note:** If you have pinned specific image tags in your `values.yaml` overrides, ensure they are updated to `3.8.2` or remove the override to use the chart defaults.

## Configuration Reference

This release updates the default image tags for the following components:

**Ledger service:**

```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.8.2"
```

**CRM service:**

```yaml
crm:
  image:
    repository: lerianstudio/midaz-crm
    pullPolicy: Always
    tag: "3.8.2"
```

> **Note:** These are the new default values. You do not need to explicitly set these in your `values.yaml` unless you want to override them with custom values.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.9.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.9.0 -n midaz
```
