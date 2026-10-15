# Helm Upgrade from v8.0.2 to v8.0.3

# Topics

- ***[Fixes](#fixes)***
    - [1. MongoDB Image Repository Migration](#1-mongodb-image-repository-migration)
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Fixes

### 1. MongoDB Image Repository Migration

The chart now uses the `bitnamilegacy/mongodb` repository instead of the deprecated `bitnami/mongodb` tags. This change ensures continued access to MongoDB images while maintaining data compatibility with existing deployments.

**What changed:**

| Setting | v8.0.2 | v8.0.3 |
|---------|--------|--------|
| `mongodb.image.repository` | `bitnami/mongodb` (default) | `bitnamilegacy/mongodb` |
| `mongodb.global.security.allowInsecureImages` | not set | `true` |

**Why this matters:**

Bitnami has removed certain MongoDB tags from their primary registry. The `bitnamilegacy` repository provides access to the same MongoDB versions with identical data formats, ensuring seamless upgrades without data migration. The subchart continues to use the same tag, so existing persistent volumes remain fully compatible.

**Template changes:**

**Before (v8.0.2):**

```yaml
mongodb:
  enabled: true
  external: false
  auth:
    enabled: true
    rootUser: "plugin-fees"
```

**After (v8.0.3):**

```yaml
mongodb:
  enabled: true
  external: false
  # bitnami/mongodb tags are gone; bitnamilegacy serves the subchart's same tag, so data stays readable.
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/mongodb
  auth:
    enabled: true
    rootUser: "plugin-fees"
```

**Operational impact:**

This change only affects deployments using the embedded MongoDB subchart (`mongodb.enabled: true` and `mongodb.external: false`). If you are using an external MongoDB instance (`mongodb.external: true`), no action is required.

For deployments with embedded MongoDB:

- **Existing deployments:** The upgrade will pull the MongoDB image from the new repository. Your existing persistent volumes and data remain unchanged and fully compatible.
- **New deployments:** MongoDB will be deployed using the `bitnamilegacy/mongodb` repository from the start.
- **Image security:** The `allowInsecureImages: true` flag is required because the legacy repository images may not have the latest security metadata. This does not affect the security of your data or the MongoDB service itself — it only allows Kubernetes to schedule the pod.

> **Important:** If you have custom `mongodb.image.repository` overrides in your values.yaml, ensure they point to a valid MongoDB image repository. The default has changed to `bitnamilegacy/mongodb` to maintain compatibility with the subchart's tag.

> **Note:** This change does not require any data migration, backup, or restore operations. The MongoDB data format remains identical between `bitnami/mongodb` and `bitnamilegacy/mongodb` for the same version tags.

**Example: Upgrading with embedded MongoDB (default configuration)**

No changes to your values.yaml are required. The chart will automatically use the new repository:

```yaml
mongodb:
  enabled: true
  external: false
  auth:
    enabled: true
    rootUser: "plugin-fees"
    rootPassword: "your-mongodb-password"
```

**Example: Using external MongoDB (no impact)**

If you're using an external MongoDB instance, this change does not affect your deployment:

```yaml
mongodb:
  enabled: true
  external: true
  auth:
    enabled: true
    rootUser: "plugin-fees"
    rootPassword: "your-mongodb-password"
  hosts:
    - "mongodb.example.com:27017"
```

**Example: Custom MongoDB image repository**

If you maintain your own MongoDB image repository, continue using your custom configuration:

```yaml
mongodb:
  enabled: true
  external: false
  image:
    repository: "your-registry.example.com/mongodb"
    tag: "6.0.5"
  auth:
    enabled: true
    rootUser: "plugin-fees"
    rootPassword: "your-mongodb-password"
```

> **Warning:** Do not change the `mongodb.image.tag` value during this upgrade unless you are intentionally upgrading MongoDB itself. The repository change is transparent and does not require a MongoDB version upgrade.

# Configuration Reference

**Default configuration (embedded MongoDB with new repository):**

```yaml
mongodb:
  enabled: true
  external: false
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/mongodb
  auth:
    enabled: true
    rootUser: "plugin-fees"
    rootPassword: "your-mongodb-password"
```

**External MongoDB configuration (unchanged):**

```yaml
mongodb:
  enabled: true
  external: true
  auth:
    enabled: true
    rootUser: "plugin-fees"
    rootPassword: "your-mongodb-password"
  hosts:
    - "mongodb.example.com:27017"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.3 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.3 -n plugin-fees
```
