# Helm Upgrade from v4.2.7 to v4.3.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Support for two new optional sibling services](#1-support-for-two-new-optional-sibling-services)
- **[Configuration Changes](#configuration-changes)**
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor feature release that adds support for two new optional sibling services: **Lender** and **Matcher**. These services join the existing optional services (Flowker and Tracer) that the product-console can integrate with. The application version remains unchanged.

| Field | v4.2.7 | v4.3.0 |
|-------|--------|--------|
| Chart version | `4.2.7` | `4.3.0` |
| App version | `2.5.0` | `2.5.0` |

## Features

### 1. Support for two new optional sibling services

The chart now supports configuration for two additional optional services:

- **Lender** – A lending service that can be integrated with the console
- **Matcher** – A matching service that can be integrated with the console

Like Flowker and Tracer, these services are **optional deployments**. The chart intentionally provides no default addresses for them: if you have not deployed these services, leaving the configuration empty prevents the console from attempting connections that would result in errors on the page.

**What changed:**

| Setting | v4.2.7 | v4.3.0 |
|---------|--------|--------|
| `configmap.LENDER_BASE_PATH` | not supported | supported (optional) |
| `configmap.MATCHER_BASE_PATH` | not supported | supported (optional) |
| Optional services count | 2 (Flowker, Tracer) | 4 (Flowker, Lender, Matcher, Tracer) |

**Path conventions:**

Each optional service follows a specific URL path convention:

| Service | Environment Variable | Path Convention | Example |
|---------|---------------------|-----------------|---------|
| Flowker | `FLOWKER_BASE_PATH` | Ends in `/v1` | `http://flowker.flowker.svc.cluster.local:4021/v1` |
| Lender | `LENDER_BASE_PATH` | Ends in `/api/v1` | `http://lender.lender.svc.cluster.local:4017/api/v1` |
| Matcher | `MATCHER_BASE_PATH` | Bare origin (no version suffix) | `http://matcher.matcher.svc.cluster.local:8080` |
| Tracer | `TRACER_BASE_PATH` | Bare origin (no version suffix) | `http://midaz-tracer.midaz.svc.cluster.local:4020` |

> **Note:** TRACER_BASE_PATH and MATCHER_BASE_PATH are bare origins with no `/v1` suffix — the console adds version paths itself. FLOWKER_BASE_PATH ends in `/v1` and LENDER_BASE_PATH ends in `/api/v1`.

## Configuration Changes

No existing configuration keys were removed or renamed. Two new optional environment variables are now supported in the `configmap` block.

| Setting | v4.2.7 | v4.3.0 | Notes |
|---------|--------|--------|-------|
| `configmap.LENDER_BASE_PATH` | not supported | optional | New, set only if Lender service is deployed |
| `configmap.MATCHER_BASE_PATH` | not supported | optional | New, set only if Matcher service is deployed |

## Configuration Reference

### New environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LENDER_BASE_PATH` | not set | Base URL for the Lender service, ending in `/api/v1`. Only set if the Lender service is deployed in your cluster. |
| `MATCHER_BASE_PATH` | not set | Base URL for the Matcher service (bare origin, no version suffix). Only set if the Matcher service is deployed in your cluster. |

### Configuration examples

#### Example 1: No optional services deployed

If you have not deployed any optional services, no changes are required:

```yaml
configmap: {}
```

#### Example 2: Only Lender deployed

If you have deployed the Lender service:

```yaml
configmap:
  LENDER_BASE_PATH: "http://lender.lender.svc.cluster.local:4017/api/v1"
```

#### Example 3: Only Matcher deployed

If you have deployed the Matcher service:

```yaml
configmap:
  MATCHER_BASE_PATH: "http://matcher.matcher.svc.cluster.local:8080"
```

#### Example 4: All optional services deployed

If you have deployed all four optional services:

```yaml
configmap:
  FLOWKER_BASE_PATH: "http://flowker.flowker.svc.cluster.local:4021/v1"
  LENDER_BASE_PATH: "http://lender.lender.svc.cluster.local:4017/api/v1"
  MATCHER_BASE_PATH: "http://matcher.matcher.svc.cluster.local:8080"
  TRACER_BASE_PATH: "http://midaz-tracer.midaz.svc.cluster.local:4020"
```

> **Important:** Replace the namespace and service names in the examples above with the actual release name and namespace where you deployed each service.

## Migration Steps

This upgrade requires no mandatory configuration changes. The new environment variables are optional and should only be set if you have deployed the corresponding services.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Determine which optional services you have deployed in your cluster:

```bash
kubectl get svc -A | grep -E "lender|matcher"
```

3. If you have deployed Lender or Matcher services, prepare your values override file with the appropriate base paths.

4. Run the upgrade command with your values file (see [Command to upgrade](#command-to-upgrade)).

5. Verify the deployment rolled successfully:

```bash
kubectl get pods -n product-console
kubectl rollout status deployment/product-console -n product-console
```

6. Check that the new environment variables are present in the ConfigMap (only if you configured them):

```bash
kubectl get configmap product-console -n product-console -o yaml | grep -E "LENDER_BASE_PATH|MATCHER_BASE_PATH"
```

7. Verify the console can reach the configured services by checking the application logs:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

> **Note:** If you do not set `LENDER_BASE_PATH` or `MATCHER_BASE_PATH`, the corresponding features will simply not be available in the console UI. This is the intended behavior for optional services.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.3.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.3.0 -n product-console
```

**With Lender service configured:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.3.0 \
  --set configmap.LENDER_BASE_PATH="http://lender.lender.svc.cluster.local:4017/api/v1" \
  -n product-console
```

**With Matcher service configured:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.3.0 \
  --set configmap.MATCHER_BASE_PATH="http://matcher.matcher.svc.cluster.local:8080" \
  -n product-console
```

**With both new services configured:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.3.0 \
  --set configmap.LENDER_BASE_PATH="http://lender.lender.svc.cluster.local:4017/api/v1" \
  --set configmap.MATCHER_BASE_PATH="http://matcher.matcher.svc.cluster.local:8080" \
  -n product-console
```
