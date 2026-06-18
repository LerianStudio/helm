# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Default passwords removed from values.yaml](#1-default-passwords-removed-from-valuesyaml)
  - [2. RabbitMQ credentials single-sourced from application Secret](#2-rabbitmq-credentials-single-sourced-from-application-secret)
  - [3. RabbitMQ Erlang cookie now required](#3-rabbitmq-erlang-cookie-now-required)
  - [4. MongoDB password single-sourced from subchart Secret](#4-mongodb-password-single-sourced-from-subchart-secret)
  - [5. Redis password removed from secrets](#5-redis-password-removed-from-secrets)
- **[Features](#features)**
  - [1. Security context hardening for manager and worker](#1-security-context-hardening-for-manager-and-worker)
  - [2. Application version bump to 2.0.0](#2-application-version-bump-to-200)
  - [3. Chart type annotation added](#3-chart-type-annotation-added)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Generate stable RabbitMQ Erlang cookie](#step-1-generate-stable-rabbitmq-erlang-cookie)
  - [Step 2: Set all required passwords](#step-2-set-all-required-passwords)
  - [Step 3: Review security context changes](#step-3-review-security-context-changes)
  - [Step 4: Verify RabbitMQ authentication configuration](#step-4-verify-rabbitmq-authentication-configuration)
  - [Step 5: Execute the upgrade](#step-5-execute-the-upgrade)
  - [Step 6: Verify deployment health](#step-6-verify-deployment-health)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major release that removes all default passwords from the chart, implements single-source credential management for infrastructure components, and hardens pod security contexts. The application version is bumped to `2.0.0`.

| Field | v2.2.0 | v3.0.0 |
|-------|--------|--------|
| Chart version | `2.2.0` | `3.0.0` |
| App version | `1.2.0` | `2.0.0` |
| Manager image tag | `1.2.0` | `2.0.0` |
| Worker image tag | `1.2.0` | `2.0.0` |

> **Warning:** This upgrade will fail if required passwords are not provided. All default password values have been removed for security compliance.

## Breaking Changes

### 1. Default passwords removed from values.yaml

All hardcoded default passwords have been removed from `values.yaml`. Operators must now explicitly provide passwords via values overrides or existing secrets.

| Setting | v2.2.0 | v3.0.0 |
|---------|--------|--------|
| `global.mongodb.adminCredentials.password` | `"lerian"` | `""` (required) |
| `global.mongodb.reporterCredentials.password` | `"lerian"` | `""` (required) |
| `secrets.MONGO_PASSWORD` | `"lerian"` | `""` (see note) |
| `secrets.REDIS_PASSWORD` | `"lerian"` | removed |
| `secrets.RABBITMQ_DEFAULT_USER` | `"plugin"` | `"plugin"` (unchanged) |
| `secrets.RABBITMQ_DEFAULT_PASS` | `"Lerian@123"` | `""` (required) |
| `secrets.RABBITMQ_ERLANG_COOKIE` | not present | `""` (required) |
| `secrets.DATASOURCE_ONBOARDING_PASSWORD` | `"lerian"` | `""` (required) |
| `secrets.OBJECT_STORAGE_ACCESS_KEY_ID` | `"any"` | `""` (required) |
| `secrets.OBJECT_STORAGE_SECRET_KEY` | `"any"` | `""` (required) |
| `mongodb.auth.rootPassword` | `"lerian"` | `""` (required) |
| `externalRabbitmqDefinitions.adminCredentials.password` | `"lerian"` | `""` (required) |
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | `"Lerian@123"` | `""` (required) |
| `rabbitmq.authentication.user.value` | `"midaz"` | removed (see breaking change #2) |
| `rabbitmq.authentication.password.value` | `"lerian"` | removed (see breaking change #2) |
| `rabbitmq.authentication.erlangCookie.value` | `"b2a717550ac09676c545fe9d986c7651f7237b2691292961"` | removed (see breaking change #2) |

> **Important:** `secrets.MONGO_PASSWORD` behavior has changed. When using the bundled MongoDB subchart, leave this empty — the password is single-sourced from the subchart's Secret. Only set this value when using an external MongoDB without `mongodb.auth.existingSecret`.

**Before (v2.2.0):**

```yaml
secrets:
  MONGO_PASSWORD: lerian
  REDIS_PASSWORD: "lerian"
  RABBITMQ_DEFAULT_PASS: Lerian@123
  DATASOURCE_ONBOARDING_PASSWORD: lerian
  OBJECT_STORAGE_ACCESS_KEY_ID: "any"
  OBJECT_STORAGE_SECRET_KEY: "any"
```

**After (v3.0.0):**

```yaml
secrets:
  MONGO_PASSWORD: ""  # Leave empty for bundled MongoDB; set only for external MongoDB
  # REDIS_PASSWORD removed — bundled valkey runs without authentication
  RABBITMQ_DEFAULT_PASS: "your-secure-password"
  RABBITMQ_ERLANG_COOKIE: "your-stable-erlang-cookie"
  DATASOURCE_ONBOARDING_PASSWORD: "your-secure-password"
  OBJECT_STORAGE_ACCESS_KEY_ID: "your-access-key"
  OBJECT_STORAGE_SECRET_KEY: "your-secret-key"
```

### 2. RabbitMQ credentials single-sourced from application Secret

The bundled RabbitMQ subchart now reads its credentials from the application manager Secret (`reporter-manager`) instead of maintaining its own copy. This eliminates credential duplication and resolves the latent user mismatch between the broker (`midaz`) and application (`plugin`).

| Setting | v2.2.0 | v3.0.0 |
|---------|--------|--------|
| `rabbitmq.authentication.existingSecret` | not set (inline values) | `"reporter-manager"` |
| `rabbitmq.authentication.user.value` | `"midaz"` | removed |
| `rabbitmq.authentication.user.secretKey` | not present | `"RABBITMQ_DEFAULT_USER"` |
| `rabbitmq.authentication.password.value` | `"lerian"` | removed |
| `rabbitmq.authentication.password.secretKey` | not present | `"RABBITMQ_DEFAULT_PASS"` |
| `rabbitmq.authentication.erlangCookie.value` | `"b2a717550ac09676c545fe9d986c7651f7237b2691292961"` | removed |
| `rabbitmq.authentication.erlangCookie.secretKey` | not present | `"RABBITMQ_ERLANG_COOKIE"` |

**Before (v2.2.0):**

```yaml
rabbitmq:
  authentication:
    user:
      value: "midaz"
    password:
      value: "lerian"
    erlangCookie:
      value: "b2a717550ac09676c545fe9d986c7651f7237b2691292961"
```

**After (v3.0.0):**

```yaml
rabbitmq:
  authentication:
    existingSecret: "reporter-manager"
    user:
      secretKey: RABBITMQ_DEFAULT_USER
    password:
      secretKey: RABBITMQ_DEFAULT_PASS
    erlangCookie:
      secretKey: RABBITMQ_ERLANG_COOKIE
```

> **Warning:** If you have overridden `manager.name` or `manager.existingSecretName`, you must also update `rabbitmq.authentication.existingSecret` to match the actual manager Secret name. The chart will fail at render time if this mismatch is detected.

### 3. RabbitMQ Erlang cookie now required

The RabbitMQ Erlang cookie must now be provided in `secrets.RABBITMQ_ERLANG_COOKIE` when the bundled RabbitMQ subchart is enabled. This value must be stable across upgrades — changing it will break the RabbitMQ cluster.

| Setting | v2.2.0 | v3.0.0 |
|---------|--------|--------|
| `secrets.RABBITMQ_ERLANG_COOKIE` | not present | required when `rabbitmq.enabled=true` |

Generate a stable cookie once and store it securely:

```bash
openssl rand -hex 32
```

**Required configuration:**

```yaml
secrets:
  RABBITMQ_ERLANG_COOKIE: "your-stable-64-character-hex-string"
```

> **Important:** The Erlang cookie must remain constant across all upgrades. Store it in a secure location (e.g., secrets manager, encrypted values file). Changing this value will cause RabbitMQ cluster formation to fail.

### 4. MongoDB password single-sourced from subchart Secret

When using the bundled MongoDB subchart, the application now reads `MONGO_PASSWORD` directly from the subchart's generated Secret (`<release>-mongodb`) via `secretKeyRef`. The `secrets.MONGO_PASSWORD` field in `values.yaml` should be left empty in this scenario.

| Deployment mode | v2.2.0 | v3.0.0 |
|-----------------|--------|--------|
| Bundled MongoDB | `secrets.MONGO_PASSWORD` duplicated in app Secret | `secrets.MONGO_PASSWORD` left empty; app reads from `<release>-mongodb` Secret |
| External MongoDB with `mongodb.auth.existingSecret` | `secrets.MONGO_PASSWORD` duplicated in app Secret | `secrets.MONGO_PASSWORD` left empty; app reads from operator's existing Secret |
| External MongoDB without existing Secret | `secrets.MONGO_PASSWORD` set inline | `secrets.MONGO_PASSWORD` set inline (unchanged) |

**Bundled MongoDB (v3.0.0):**

```yaml
mongodb:
  enabled: true
  auth:
    rootPassword: "your-secure-password"
secrets:
  MONGO_PASSWORD: ""  # Leave empty — single-sourced from subchart
```

**External MongoDB with existing Secret (v3.0.0):**

```yaml
mongodb:
  enabled: false
  auth:
    existingSecret: "my-mongo-secret"
secrets:
  MONGO_PASSWORD: ""  # Leave empty — single-sourced from existingSecret
```

**External MongoDB without existing Secret (v3.0.0):**

```yaml
mongodb:
  enabled: false
secrets:
  MONGO_PASSWORD: "your-secure-password"  # Set inline for external MongoDB
```

### 5. Redis password removed from secrets

The `secrets.REDIS_PASSWORD` field has been removed. The bundled Valkey subchart runs with `auth.enabled=false`, so no authentication is required.

| Setting | v2.2.0 | v3.0.0 |
|---------|--------|--------|
| `secrets.REDIS_PASSWORD` | `"lerian"` | removed |

> **Note:** If you enable authentication on the Valkey subchart in the future, reintroduce this key and configure the subchart to read it from the application Secret.

## Features

### 1. Security context hardening for manager and worker

Both `manager` and `worker` deployments now include hardened security contexts that enforce non-root execution, read-only root filesystem, and drop all capabilities.

**New fields added:**

| Component | Field | Default |
|-----------|-------|---------|
| `manager` | `podSecurityContext` | `{}` |
| `manager` | `securityContext.runAsUser` | `1000` |
| `manager` | `securityContext.runAsGroup` | `1000` |
| `manager` | `securityContext.runAsNonRoot` | `true` |
| `manager` | `securityContext.readOnlyRootFilesystem` | `true` |
| `manager` | `securityContext.allowPrivilegeEscalation` | `false` |
| `manager` | `securityContext.capabilities.drop` | `["ALL"]` |
| `manager` | `securityContext.seccompProfile.type` | `RuntimeDefault` |
| `worker` | `podSecurityContext` | `{}` |
| `worker` | `securityContext.runAsUser` | `1000` |
| `worker` | `securityContext.runAsGroup` | `1000` |
| `worker` | `securityContext.runAsNonRoot` | `true` |
| `worker` | `securityContext.readOnlyRootFilesystem` | `true` |
| `worker` | `securityContext.allowPrivilegeEscalation` | `false` |
| `worker` | `securityContext.capabilities.drop` | `["ALL"]` |
| `worker` | `securityContext.seccompProfile.type` | `RuntimeDefault` |

**Rendered security context (v3.0.0):**

```yaml
manager:
  podSecurityContext: {}
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

```yaml
worker:
  podSecurityContext: {}
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
```

> **Note:** If your container images require write access to specific paths, mount an `emptyDir` volume at those paths. The read-only root filesystem prevents all writes to the container's filesystem layer.

### 2. Application version bump to 2.0.0

The manager and worker image tags have been updated from `1.2.0` to `2.0.0`, and the chart `appVersion` field reflects this change.

| Component | v2.2.0 | v3.0.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"1.2.0"` | `"2.0.0"` |
| `worker.image.tag` | `"1.2.0"` | `"2.0.0"` |
| Chart `appVersion` | `"1.2.0"` | `"1.2.0"` (unchanged in Chart.yaml, but images are `2.0.0`) |

> **Note:** The `appVersion` field in `Chart.yaml` remains `1.2.0`, but the actual deployed images are tagged `2.0.0` via `values.yaml`.

### 3. Chart type annotation added

The chart now includes a `lerian.studio/chart-type: multi-component` annotation in `Chart.yaml` to indicate that it deploys multiple application components (manager, worker) alongside infrastructure subcharts.

**Added annotation:**

```yaml
annotations:
  lerian.studio/chart-type: multi-component
```

## Configuration Reference

### Required password fields

All password fields must be set via values overrides or `--set` flags. The chart will fail to deploy if required passwords are empty.

| Field | Default | Description |
|-------|---------|-------------|
| `global.mongodb.adminCredentials.password` | `""` | MongoDB admin password for job-based user creation |
| `global.mongodb.reporterCredentials.password` | `""` | MongoDB reporter user password |
| `secrets.MONGO_PASSWORD` | `""` | Leave empty for bundled MongoDB; set only for external MongoDB without `existingSecret` |
| `secrets.RABBITMQ_DEFAULT_PASS` | `""` | RabbitMQ plugin user password (single-sourced) |
| `secrets.RABBITMQ_ERLANG_COOKIE` | `""` | Stable Erlang cookie for RabbitMQ clustering (required when `rabbitmq.enabled=true`) |
| `secrets.DATASOURCE_ONBOARDING_PASSWORD` | `""` | Onboarding datasource password |
| `secrets.OBJECT_STORAGE_ACCESS_KEY_ID` | `""` | S3-compatible storage access key |
| `secrets.OBJECT_STORAGE_SECRET_KEY` | `""` | S3-compatible storage secret key |
| `mongodb.auth.rootPassword` | `""` | MongoDB root password for bundled subchart |
| `externalRabbitmqDefinitions.adminCredentials.password` | `""` | RabbitMQ admin password for external broker definitions |
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | `""` | RabbitMQ plugin user password for external broker definitions |

### Security context fields

| Field | Default | Description |
|-------|---------|-------------|
| `manager.podSecurityContext` | `{}` | Pod-level security context for manager |
| `manager.securityContext.runAsUser` | `1000` | User ID to run manager container |
| `manager.securityContext.runAsGroup` | `1000` | Group ID to run manager container |
| `manager.securityContext.runAsNonRoot` | `true` | Enforce non-root execution |
| `manager.securityContext.readOnlyRootFilesystem` | `true` | Mount root filesystem as read-only |
| `manager.securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation |
| `manager.securityContext.capabilities.drop` | `["ALL"]` | Drop all Linux capabilities |
| `manager.securityContext.seccompProfile.type` | `RuntimeDefault` | Seccomp profile type |
| `worker.podSecurityContext` | `{}` | Pod-level security context for worker |
| `worker.securityContext.runAsUser` | `1000` | User ID to run worker container |
| `worker.securityContext.runAsGroup` | `1000` | Group ID to run worker container |
| `worker.securityContext.runAsNonRoot` | `true` | Enforce non-root execution |
| `worker.securityContext.readOnlyRootFilesystem` | `true` | Mount root filesystem as read-only |
| `worker.securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation |
| `worker.securityContext.capabilities.drop` | `["ALL"]` | Drop all Linux capabilities |
| `worker.securityContext.seccompProfile.type` | `RuntimeDefault` | Seccomp profile type |

### RabbitMQ authentication fields

| Field | Default | Description |
|-------|---------|-------------|
| `rabbitmq.authentication.existingSecret` | `"reporter-manager"` | Name of Secret containing RabbitMQ credentials (single-sourced) |
| `rabbitmq.authentication.user.secretKey` | `RABBITMQ_DEFAULT_USER` | Key in existingSecret for RabbitMQ username |
| `rabbitmq.authentication.password.secretKey` | `RABBITMQ_DEFAULT_PASS` | Key in existingSecret for RabbitMQ password |
| `rabbitmq.authentication.erlangCookie.secretKey` | `RABBITMQ_ERLANG_COOKIE` | Key in existingSecret for Erlang cookie |

## Migration Steps

### Step 1: Generate stable RabbitMQ Erlang cookie

Generate a 64-character hexadecimal string to use as the RabbitMQ Erlang cookie. This value must remain constant across all future upgrades.

```bash
openssl rand -hex 32
```

Store the output securely (e.g., in a secrets manager or encrypted values file).

### Step 2: Set all required passwords

Create a `values-override.yaml` file with all required passwords:

```yaml
global:
  mongodb:
    adminCredentials:
      password: "your-mongodb-admin-password"
    reporterCredentials:
      password: "your-mongodb-reporter-password"

secrets:
  MONGO_PASSWORD: ""  # Leave empty for bundled MongoDB
  RABBITMQ_DEFAULT_PASS: "your-rabbitmq-password"
  RABBITMQ_ERLANG_COOKIE: "your-stable-erlang-cookie-from-step-1"
  DATASOURCE_ONBOARDING_PASSWORD: "your-onboarding-password"
  OBJECT_STORAGE_ACCESS_KEY_ID: "your-s3-access-key"
  OBJECT_STORAGE_SECRET_KEY: "your-s3-secret-key"

mongodb:
  auth:
    rootPassword: "your-mongodb-root-password"

externalRabbitmqDefinitions:
  adminCredentials:
    password: "your-external-rabbitmq-admin-password"
  appCredentials:
    pluginPassword: "your-external-rabbitmq-plugin-password"
```

> **Important:** If you are using external MongoDB with `mongodb.auth.existingSecret`, leave `secrets.MONGO_PASSWORD` empty. If you are using external MongoDB without an existing Secret, set `secrets.MONGO_PASSWORD` to your MongoDB password.

### Step 3: Review security context changes

The new security contexts enforce non-root execution and read-only root filesystem. If your container images require write access to specific paths, add `emptyDir` volume mounts:

```yaml
manager:
  volumes:
    - name: tmp
      emptyDir: {}
  volumeMounts:
    - name: tmp
      mountPath: /tmp

worker:
  volumes:
    - name: tmp
      emptyDir: {}
  volumeMounts:
    - name: tmp
      mountPath: /tmp
```

> **Note:** The chart templates do not currently expose `volumes` and `volumeMounts` fields in `values.yaml`. If write access is required, you may need to patch the Deployment resources after upgrade or request this feature from the chart maintainers.

### Step 4: Verify RabbitMQ authentication configuration

If you have overridden the manager Secret name (via `manager.name` or `manager.existingSecretName`), ensure `rabbitmq.authentication.existingSecret` matches:

```yaml
manager:
  name: "custom-manager-name"

rabbitmq:
  authentication:
    existingSecret: "custom-manager-name"  # Must match manager Secret name
```

The chart will fail at render time if this mismatch is detected.

### Step 5: Execute the upgrade

Run the upgrade command with your values override file:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 3.0.0 \
  -n reporter \
  -f values-override.yaml
```

> **Warning:** The upgrade will trigger a rolling restart of both manager and worker deployments. RabbitMQ and MongoDB pods will also restart if their credentials have changed.

### Step 6: Verify deployment health

Check that all pods are running and healthy:

```bash
kubectl get pods -n reporter
```

Verify manager and worker logs:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50
```

Verify RabbitMQ cluster status:

```bash
kubectl exec -n reporter -it reporter-rabbitmq-0 -- rabbitmqctl cluster_status
```

Verify MongoDB connectivity:

```bash
kubectl exec -n reporter -it reporter-mongodb-0 -- mongosh --username reporter --password 'your-mongodb-root-password' --eval "db.adminCommand('ping')"
```

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.0.0 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 3.0.0 -n reporter
```
