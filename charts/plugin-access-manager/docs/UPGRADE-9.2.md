# Helm Upgrade from v9.1.0 to v9.2.0

# Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. Caradhras Component Promotion](#1-caradhras-component-promotion)
  - [2. Database Creation Default Changed](#2-database-creation-default-changed)
  - [3. Casdoor References Renamed to Caradhras](#3-casdoor-references-renamed-to-caradhras)
- **[Features](#features)**
  - [1. New Caradhras UI Component](#1-new-caradhras-ui-component)
  - [2. Caradhras Ingress Support](#2-caradhras-ingress-support)
  - [3. Independent PodDisruptionBudget for Caradhras](#3-independent-poddisruptionbudget-for-caradhras)
  - [4. Init User Job Disabled by Default](#4-init-user-job-disabled-by-default)
- **[Migration Guide](#migration-guide)**
  - [Step 1: Review Your Current Configuration](#step-1-review-your-current-configuration)
  - [Step 2: Choose Your Migration Path](#step-2-choose-your-migration-path)
  - [Step 3: Update Database Creation Setting](#step-3-update-database-creation-setting)
  - [Step 4: Verify Probe Timeouts](#step-4-verify-probe-timeouts)
  - [Step 5: Test the Upgrade](#step-5-test-the-upgrade)
- **[Configuration Reference](#configuration-reference)**
  - [Caradhras Component](#caradhras-component)
  - [Caradhras UI Component](#caradhras-ui-component)
  - [Backward Compatibility Aliases](#backward-compatibility-aliases)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking Changes

### 1. Caradhras Component Promotion

The auth backend component (formerly `auth.backend`) has been promoted to a top-level component named `caradhras`. This reflects the product transition from Casdoor to Lerian's Caradhras authorization service.

**What changed:**

| Setting | v9.1.0 | v9.2.0 |
|---------|--------|--------|
| Component path | `auth.backend.*` | `caradhras.*` |
| Component name | `<release>-auth-backend` | `<release>-caradhras` |
| Image repository | `ghcr.io/lerianstudio/casdoor` | `ghcr.io/lerianstudio/caradhras` |
| Image tag | `3.1.0` | `1.2.0` |
| Migrations image | `ghcr.io/lerianstudio/casdoor-migrations` | `ghcr.io/lerianstudio/caradhras-migrations` |

**Before (v9.1.0):**

```yaml
auth:
  backend:
    name: ""
    replicaCount: 1
    service:
      type: ClusterIP
      port: 8000
    image:
      repository: ghcr.io/lerianstudio/casdoor
      pullPolicy: Always
      tag: "3.1.0"
    migrations:
      image:
        repository: ghcr.io/lerianstudio/casdoor-migrations
        pullPolicy: Always
        tag: "3.1.0"
```

**After (v9.2.0):**

```yaml
caradhras:
  name: ""
  replicaCount: ""
  service:
    type: ClusterIP
    port: ""
    annotations: {}
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.2.0"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      tag: ""
```

**Why this matters:**

- Kubernetes resource names change from `*-auth-backend` to `*-caradhras`
- Service DNS names change: `<release>-auth-backend:8000` becomes `<release>-caradhras:8000`
- The auth component's `AUTHORIZER_ADDRESS` ConfigMap value is automatically updated to point to the new service name
- PodDisruptionBudget is now independent (see [section 3](#3-independent-poddisruptionbudget-for-caradhras))

> **Important:** The chart implements backward compatibility for existing installs. If you currently override `auth.backend.*` values in your own values files, those overrides will continue to work through fallback aliases. However, the new `caradhras.*` path takes precedence if both are set.

### 2. Database Creation Default Changed

The `createDatabase` setting default has changed from `true` to `false`.

**What changed:**

| Setting | v9.1.0 Default | v9.2.0 Default |
|---------|----------------|----------------|
| `auth.backend.createDatabase` | `true` | N/A (removed) |
| `caradhras.createDatabase` | N/A | `false` |

**Why this matters:**

Most production database users granted to the caradhras component do not have `CREATEDB` privilege. The previous default of `true` caused permission-denied errors on startup in environments where the database/schema is provisioned ahead of time by infrastructure automation.

**Action required:**

If your deployment relies on caradhras creating its own database on startup (i.e., the database user has `CREATEDB` permission and no external provisioning exists), you must explicitly set:

```yaml
caradhras:
  createDatabase: true
```

> **Warning:** If you do not set this and your database does not already exist, caradhras will fail to start with a "database does not exist" error.

### 3. Casdoor References Renamed to Caradhras

All user-facing documentation strings and comments referencing "Casdoor" have been updated to "Caradhras" to reflect the product name change.

**What changed:**

| Location | v9.1.0 | v9.2.0 |
|----------|--------|--------|
| `common.authorizer.clientId` comment | "Casdoor application client id" | "Caradhras application client id" |
| Template comments | References to `casdoor` | References to `caradhras` |
| ConfigMap `appname` | `plugin-auth-casdoor-backend` | (removed from chart defaults) |

**Why this matters:**

This is primarily a documentation change. No configuration keys or environment variable names have changed. Operators do not need to take action unless they have hardcoded references to "Casdoor" in their own values overrides or external documentation.

# Features

### 1. New Caradhras UI Component

A new optional UI component (`caradhras.ui`) is now available. This deploys an nginx-based SPA console that serves the Caradhras admin panel and reverse-proxies API requests to the caradhras backend service.

**What this enables:**

- Web-based administration console for Caradhras
- Same-origin reverse proxy to avoid CORS issues
- Independent scaling and ingress configuration from the backend API

**Configuration:**

The UI component is **disabled by default**. To enable it:

```yaml
caradhras:
  ui:
    enabled: true
```

**Default settings** (applied when `enabled: true`):

| Setting | Default | Description |
|---------|---------|-------------|
| `caradhras.ui.image.repository` | `ghcr.io/lerianstudio/caradhras-ui` | UI container image |
| `caradhras.ui.image.tag` | `1.2.0` | UI image version |
| `caradhras.ui.image.pullPolicy` | `Always` | Image pull policy |
| `caradhras.ui.service.type` | `ClusterIP` | Kubernetes service type |
| `caradhras.ui.service.port` | `80` | Service port |
| `caradhras.ui.replicaCount` | `1` | Number of replicas |
| `caradhras.ui.autoscaling.enabled` | `false` | Enable HPA |
| `caradhras.ui.ingress.enabled` | `false` | Enable ingress |

**Example: Enable UI with ingress**

```yaml
caradhras:
  ui:
    enabled: true
    ingress:
      enabled: true
      className: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
      hosts:
        - host: caradhras-console.example.com
          paths:
            - path: /
              pathType: Prefix
      tls:
        - secretName: caradhras-ui-tls
          hosts:
            - caradhras-console.example.com
```

> **Note:** The UI ingress (`caradhras.ui.ingress`) is separate from the backend API ingress (`caradhras.ingress`). Most deployments will only expose the UI publicly and keep the backend API internal.

### 2. Caradhras Ingress Support

The caradhras backend component now supports its own ingress configuration, independent of the auth and identity components.

**Configuration:**

```yaml
caradhras:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: caradhras-api.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: caradhras-api-tls
        hosts:
          - caradhras-api.example.com
```

**Why this matters:**

Previously, the auth backend (Casdoor) had no ingress support in the chart. Operators who needed external access had to create ingress resources manually. Now the chart can manage it directly.

> **Important:** Do not confuse `caradhras.ingress` (backend API, port 8000) with `caradhras.ui.ingress` (SPA console, port 80). They front different services.

### 3. Independent PodDisruptionBudget for Caradhras

Caradhras now has its own PodDisruptionBudget configuration, separate from the auth component.

**What changed:**

| Setting | v9.1.0 | v9.2.0 |
|---------|--------|--------|
| PDB toggle | `auth.pdb.enabled` (shared) | `caradhras.pdb.enabled` (independent) |
| PDB applies to | auth + auth-backend | auth only |

**Before (v9.1.0):**

```yaml
auth:
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0
```

This PDB applied to **both** the auth component and the auth-backend component.

**After (v9.2.0):**

```yaml
auth:
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0

caradhras:
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0
```

Each component now has its own independent PDB.

**Why this matters:**

- You can now disable the PDB for one component without affecting the other
- Different availability requirements can be set per component
- Caradhras PDB defaults to **enabled** (matching the previous shared behavior)

**Action required:**

If you previously disabled `auth.pdb.enabled` intending to disable the PDB for the auth backend, you must now also set:

```yaml
caradhras:
  pdb:
    enabled: false
```

### 4. Init User Job Disabled by Default

The init user job (which creates the admin user on first install) is now **disabled by default** and intentionally not advertised in the values.yaml defaults.

**What changed:**

| Setting | v9.1.0 Default | v9.2.0 Default |
|---------|----------------|----------------|
| `auth.initUser.enabled` | `true` | `false` |

**Why this matters:**

The init user job was previously enabled by default with a hardcoded admin email (`admin@midaz.tech`) but **no default password** (the install would fail if `adminPassword` was not set). This created confusion and required every install to explicitly handle the admin password secret.

The new default (`false`) makes the behavior explicit: operators who want the admin user auto-created must opt in by setting `initUser.enabled=true` and providing credentials.

**Action required:**

If your deployment relies on the init user job, you must now explicitly enable it:

```yaml
auth:
  initUser:
    enabled: true
    adminEmail: "admin@example.com"
    adminDisplayName: "Admin"
    adminPassword: "your-secure-password"
```

Or use an existing secret:

```yaml
auth:
  initUser:
    enabled: true
    useExistingSecret: true
    adminPasswordSecretName: "caradhras-admin-credentials"
    adminPasswordSecretKey: "ADMIN_PASSWORD"
```

> **Note:** The init user job only runs on **first install**, not on upgrades. If you delete the admin user after creation, it will not be recreated.

# Migration Guide

### Step 1: Review Your Current Configuration

Check if your current values file overrides any of these paths:

```bash
helm get values plugin-access-manager -n plugin-access-manager > current-values.yaml
grep -E "auth\.backend\.|initUser\." current-values.yaml
```

### Step 2: Choose Your Migration Path

#### Option 1: Keep Existing Configuration (Recommended for Most)

If you currently override `auth.backend.*` values, **you do not need to change anything**. The chart's backward compatibility layer will continue to honor those overrides.

**Example:** Your existing values file has:

```yaml
auth:
  backend:
    replicaCount: 3
    image:
      tag: "3.1.0"
    readinessProbe:
      timeoutSeconds: 10
```

This will continue to work in v9.2.0. The chart will:
- Use `replicaCount: 3`
- Use image tag `3.1.0` (you may want to update this to `1.2.0` for the new Caradhras image)
- Use `readinessProbe.timeoutSeconds: 10`

> **Warning:** If you keep `auth.backend.image.tag: "3.1.0"`, you will continue running the old Casdoor image. To use the new Caradhras image, update to `tag: "1.2.0"` or migrate to the `caradhras.*` path.

#### Option 2: Migrate to New Configuration Path

If you want to adopt the new structure and remove the legacy `auth.backend` overrides:

**Before (v9.1.0):**

```yaml
auth:
  backend:
    replicaCount: 3
    service:
      port: 8000
    image:
      repository: ghcr.io/lerianstudio/casdoor
      tag: "3.1.0"
    readinessProbe:
      timeoutSeconds: 10
    livenessProbe:
      timeoutSeconds: 10
```

**After (v9.2.0):**

```yaml
caradhras:
  replicaCount: 3
  service:
    port: 8000
  image:
    repository: ghcr.io/lerianstudio/caradhras
    tag: "1.2.0"
  readinessProbe:
    timeoutSeconds: 10
  livenessProbe:
    timeoutSeconds: 10
```

### Step 3: Update Database Creation Setting

Check if your database user has `CREATEDB` privilege:

```bash
# Connect to your PostgreSQL database
psql -h <db-host> -U <db-user> -d postgres -c "\du <db-user>"
```

Look for `Create DB` in the attributes column.

**If your user does NOT have CREATEDB privilege** (most production setups):

No action required. The new default (`createDatabase: false`) is correct.

**If your user DOES have CREATEDB privilege and you rely on auto-creation:**

```yaml
caradhras:
  createDatabase: true
```

### Step 4: Verify Probe Timeouts

If you previously overrode `auth.backend.readinessProbe.timeoutSeconds` or `auth.backend.livenessProbe.timeoutSeconds` (common in production environments where Casdoor/Caradhras health endpoints take 5-13 seconds to respond), verify the override is still in place:

**Check your current values:**

```bash
helm get values plugin-access-manager -n plugin-access-manager | grep -A 5 "readinessProbe:"
```

**If you see custom timeout values**, ensure they are preserved:

```yaml
# Legacy path (still works via fallback)
auth:
  backend:
    readinessProbe:
      timeoutSeconds: 10
    livenessProbe:
      timeoutSeconds: 10

# OR new path (takes precedence)
caradhras:
  readinessProbe:
    timeoutSeconds: 10
  livenessProbe:
    timeoutSeconds: 10
```

> **Warning:** If you do not have these overrides and your Caradhras/Casdoor instance takes longer than 1 second to respond to health checks, pods may flap into CrashLoopBackOff after the upgrade. Set explicit timeouts if you experience this.

### Step 5: Test the Upgrade

Use `helm diff` to preview all changes before applying:

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.2.0 \
  -n plugin-access-manager \
  -f your-values.yaml
```

Look for:
- Service name changes (`auth-backend` → `caradhras`)
- Image repository/tag changes
- New resources (caradhras PDB, optional UI deployment)
- ConfigMap updates (AUTHORIZER_ADDRESS pointing to new service name)

# Configuration Reference

### Caradhras Component

The caradhras component is the authorization backend (formerly auth.backend). All settings are optional; the chart provides sensible defaults.

**Core settings:**

```yaml
caradhras:
  # Component name override (default: <release>-caradhras)
  name: ""
  
  # Replica count (default: 1)
  replicaCount: ""
  
  # Revision history limit
  revisionHistoryLimit: 10
  
  # Database creation on startup (default: false)
  createDatabase: false
  
  # Service configuration
  service:
    type: ClusterIP
    port: ""  # default: 8000
    annotations: {}
  
  # Image configuration
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.2.0"
  
  # Resource limits and requests
  resources:
    limits:
      cpu: 1
      memory: 1024Mi
    requests:
      cpu: 500m
      memory: 256Mi
  
  # Autoscaling
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80
  
  # Health probes
  readinessProbe: {}
  livenessProbe: {}
  
  # PodDisruptionBudget
  pdb:
    enabled: true
    maxUnavailable: 1
    minAvailable: 0
    annotations: {}
  
  # Ingress (disabled by default)
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts: []
    tls: []
  
  # Migrations job
  migrations:
    image:
      repository: ""  # default: ghcr.io/lerianstudio/caradhras-migrations
      pullPolicy: ""  # default: Always
      tag: ""         # default: 1.2.0
```

**Health probe defaults:**

| Probe | Path | Initial Delay | Period | Timeout | Success Threshold | Failure Threshold |
|-------|------|---------------|--------|---------|-------------------|-------------------|
| Readiness | `/readyz` | 15s | 5s | 1s | 1 | 3 |
| Liveness | `/api/health` | 20s | 10s | 1s | 1 | 3 |

**Example: Production configuration**

```yaml
caradhras:
  replicaCount: 3
  createDatabase: false
  
  resources:
    limits:
      cpu: 2
      memory: 2048Mi
    requests:
      cpu: 1
      memory: 1024Mi
  
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  
  readinessProbe:
    timeoutSeconds: 10
    failureThreshold: 5
  
  livenessProbe:
    timeoutSeconds: 10
    failureThreshold: 5
  
  pdb:
    enabled: true
    minAvailable: 2
```

### Caradhras UI Component

The UI component is a separate deployment that serves the Caradhras admin console SPA.

**Configuration:**

```yaml
caradhras:
  ui:
    # Enable the UI component (default: false)
    enabled: false
    
    # Component name override (default: <release>-caradhras-ui)
    name: ""
    
    # Replica count (default: 1)
    replicaCount: 1
    
    # Image configuration
    image:
      repository: ghcr.io/lerianstudio/caradhras-ui
      pullPolicy: Always
      tag: "1.2.0"
    
    # Service configuration
    service:
      type: ClusterIP
      port: 80
      annotations: {}
    
    # Resource limits and requests
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi
    
    # Autoscaling
    autoscaling:
      enabled: false
      minReplicas: 1
      maxReplicas: 3
      targetCPUUtilizationPercentage: 80
    
    # Health probes
    readinessProbe: {}
    livenessProbe: {}
    
    # Ingress
    ingress:
      enabled: false
      className: ""
      annotations: {}
      hosts: []
      tls: []
```

**Example: Enable UI with public ingress**

```yaml
caradhras:
  ui:
    enabled: true
    replicaCount: 2
    
    ingress:
      enabled: true
      className: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      hosts:
        - host: auth-console.example.com
          paths:
            - path: /
              pathType: Prefix
      tls:
        - secretName: caradhras-ui-tls
          hosts:
            - auth-console.example.com
```

### Backward Compatibility Aliases

The chart maintains backward compatibility with the legacy `auth.backend.*` configuration path. The following fields support fallback:

| New Path | Legacy Path | Default |
|----------|-------------|---------|
| `caradhras.name` | `auth.backend.name` | `<release>-caradhras` |
| `caradhras.replicaCount` | `auth.backend.replicaCount` | `1` |
| `caradhras.service.port` | `auth.backend.service.port` | `8000` |
| `caradhras.image.repository` | `auth.backend.image.repository` | `ghcr.io/lerianstudio/caradhras` |
| `caradhras.image.tag` | `auth.backend.image.tag` | `1.2.0` |
| `caradhras.image.pullPolicy` | `auth.backend.image.pullPolicy` | `Always` |
| `caradhras.readinessProbe.timeoutSeconds` | `auth.backend.readinessProbe.timeoutSeconds` | `1` |
| `caradhras.livenessProbe.timeoutSeconds` | `auth.backend.livenessProbe.timeoutSeconds` | `1` |
| `caradhras.migrations.image.repository` | `auth.backend.migrations.image.repository` | `ghcr.io/lerianstudio/caradhras-migrations` |
| `caradhras.migrations.image.tag` | `auth.backend.migrations.image.tag` | `1.2.0` |
| `caradhras.migrations.image.pullPolicy` | `auth.backend.migrations.image.pullPolicy` | `Always` |

**Precedence rules:**

1. If `caradhras.<field>` is set (non-empty), it is used
2. Otherwise, if `auth.backend.<field>` is set (non-empty), it is used as a fallback
3. Otherwise, the hardcoded chart default is used

**Example: Mixed configuration (not recommended, but supported)**

```yaml
# New path takes precedence for image
caradhras:
  image:
    tag: "1.2.0"

# Legacy path used as fallback for replica count
auth:
  backend:
    replicaCount: 3
```

Result: The deployment will use `tag: "1.2.0"` (from new path) and `replicaCount: 3` (from legacy path).

> **Note:** For clarity and maintainability, we recommend using **either** the new `caradhras.*` path **or** the legacy `auth.backend.*` path consistently, not mixing them.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.0 -n plugin-access-manager
```
