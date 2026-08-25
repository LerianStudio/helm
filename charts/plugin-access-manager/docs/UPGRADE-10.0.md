# Helm Upgrade from v9.x to v10.x

# Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. `auth.backend` Promoted to a Top-Level `caradhras` Component](#1-authbackend-promoted-to-a-top-level-caradhras-component)
  - [2. Image Family Rename: Casdoor → Caradhras](#2-image-family-rename-casdoor--caradhras)
- **[Features](#features)**
  - [3. Caradhras UI (SPA Console)](#3-caradhras-ui-spa-console)
- **[Backward Compatibility](#backward-compatibility)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Move `auth.backend.*` Overrides to `caradhras.*`](#step-1-move-authbackend-overrides-to-caradhras)
  - [Step 2: Update Pinned Image Tags](#step-2-update-pinned-image-tags)
  - [Step 3 (Optional): Enable the Caradhras UI](#step-3-optional-enable-the-caradhras-ui)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking Changes

### 1. `auth.backend` Promoted to a Top-Level `caradhras` Component

**What changed:**

The auth backend component — previously nested at `auth.backend` with its own
templates under `templates/auth-backend/` — is now a top-level component named
`caradhras`, a sibling of `identity` and `auth`, with its own `templates/caradhras/`
directory and its own `_helpers.tpl` naming functions (`plugin-caradhras.*`).

| Component | v9.x Location | v10.x Location |
|-----------|----------------|-----------------|
| Backend Deployment/Service/ConfigMap/HPA/PDB | `auth.backend.*` | `caradhras.*` |
| Backend migrations Job | `auth.backend.migrations.*` | `caradhras.migrations.*` |
| Backend component name | `auth.backend.name` | `caradhras.name` |

**Before (v9.x):**

```yaml
auth:
  backend:
    replicaCount: 1
    name: ""
    service:
      port: 8000
    image:
      repository: ghcr.io/lerianstudio/casdoor
      tag: "3.1.0"
    migrations:
      image:
        repository: ghcr.io/lerianstudio/casdoor-migrations
        tag: "3.1.0"
```

**After (v10.x):**

```yaml
caradhras:
  replicaCount: 1
  name: ""
  service:
    port: 8000
  image:
    repository: ghcr.io/lerianstudio/caradhras
    tag: "1.2.0-beta.59"
  migrations:
    image:
      repository: ghcr.io/lerianstudio/caradhras-migrations
      tag: "1.2.0-beta.59"
```

> **Note:** `auth.initUser.*` is unaffected — it was already a direct child of
> `auth:` (not `auth.backend:`) and stays there; only its image family is renamed
> (see below).

### 2. Image Family Rename: Casdoor → Caradhras

Lerian has replaced the Casdoor-based backend with a new product, **Caradhras**.
The container image family is renamed accordingly:

| v9.x Image | v10.x Image | Default Tag |
|------------|-------------|--------------|
| `ghcr.io/lerianstudio/casdoor` | `ghcr.io/lerianstudio/caradhras` | `1.2.0-beta.59` |
| `ghcr.io/lerianstudio/casdoor-migrations` | `ghcr.io/lerianstudio/caradhras-migrations` | `1.2.0-beta.59` |
| `ghcr.io/lerianstudio/casdoor-user-init` | `ghcr.io/lerianstudio/caradhras-user-init` | `3.2.0-beta.67` |

> **Gotcha:** the `caradhras-migrations` GHCR repository carries **two unrelated
> version trains** — `1.2.0-beta.x` (caradhras's own migrations, correct) and
> `3.2.0-beta.x` (a different, legacy plugin-access-manager applier). The chart
> pins the `1.2.0-beta.x` train by default (`caradhras.migrations.image.tag`).
> If you override this tag, stay on the `1.2.0-beta.x` train — a `3.2.0-beta.x`
> tag exists, pulls fine, and silently applies the wrong migration chain.

# Features

### 3. Caradhras UI (SPA Console)

A new optional sub-resource of the `caradhras` component: a Deployment (nginx
serving the SPA, reverse-proxying same-origin to the caradhras backend Service),
Service, and Ingress. Disabled by default.

```yaml
caradhras:
  ui:
    enabled: false          # set true to deploy the UI
    image:
      repository: ghcr.io/lerianstudio/caradhras-ui
      tag: "1.2.0-beta.59"
    service:
      port: 80
    ingress:
      enabled: false
      hosts:
        - host: "caradhras.example.com"
          paths:
            - path: /
              pathType: Prefix
```

# Backward Compatibility

**A legacy `auth.backend.*` override in your OWN values file keeps working.**
The chart's own `values.yaml` no longer ships a real `auth.backend` block (only
`caradhras`), but the templates resolve five fields with explicit "new key wins,
old key is a fallback alias" precedence:

- `image.repository`, `image.tag`, `image.pullPolicy`
- `service.port`
- `replicaCount`

Precedence order:

1. `caradhras.<field>` — wins if set
2. `auth.backend.<field>` — fallback, only relevant if you still set it in your
   own values override
3. Hardcoded chart default

This means you do **not** have to migrate immediately: if you have
`auth.backend.image.repository`/`auth.backend.image.tag`/etc. set today, the
caradhras Deployment/Service continue to pick them up unchanged after
upgrading to v10.x. Migrate to `caradhras.*` whenever convenient — there is no
forced cutover date, but `auth.backend.*` is not documented in `values.yaml`
going forward and may be removed in a future major version.

> **Note:** Fields NOT in the list above (e.g. `createDatabase`, `migrations.image.*`,
> `name`) do not carry this legacy fallback — `caradhras.name` does fall back to
> `auth.backend.name` too (component naming needed the same alias to avoid
> breaking cross-component DNS), but `migrations.image.*` and `createDatabase`
> only read the new `caradhras.*` path.

# Migration Steps

### Step 1: Move `auth.backend.*` Overrides to `caradhras.*`

Whenever convenient, rename any `auth.backend.*` keys in your values file to
`caradhras.*`:

```yaml
# Before
auth:
  backend:
    image:
      repository: my-registry/casdoor-fork
      tag: "custom"

# After
caradhras:
  image:
    repository: my-registry/casdoor-fork
    tag: "custom"
```

### Step 2: Update Pinned Image Tags

If you pin image tags explicitly, update them to the Caradhras equivalents:

```yaml
caradhras:
  image:
    tag: "1.2.0-beta.59"
  migrations:
    image:
      tag: "1.2.0-beta.59"   # stay on the 1.2.0-beta.x train
auth:
  initUser:
    image:
      tag: "3.2.0-beta.67"
```

### Step 3 (Optional): Enable the Caradhras UI

```yaml
caradhras:
  ui:
    enabled: true
    ingress:
      enabled: true
      hosts:
        - host: "caradhras.example.com"
          paths:
            - path: /
              pathType: Prefix
```

# Configuration Reference

See the [README](../README.md#caradhras-service-auth-backend) for the full
`caradhras.*` parameter table.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.0.0 -n plugin-access-manager
```
