# Helm Upgrade from v8.0.0 to v8.0.1

# Topics

- ***[Fixes](#fixes)***
    - [1. CLIENT_ID Backward Compatibility Fallback](#1-client_id-backward-compatibility-fallback)
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Fixes

### 1. CLIENT_ID Backward Compatibility Fallback

The `CLIENT_ID` secret now includes a backward compatibility fallback to `fees.configmap.CLIENT_ID` for operators upgrading from versions prior to v8.0.0 who may still have this value configured in the ConfigMap location.

**What changed:**

| Setting | v8.0.0 | v8.0.1 |
|---------|--------|--------|
| `CLIENT_ID` fallback chain | `fees.secrets.CLIENT_ID` → default value | `fees.secrets.CLIENT_ID` → `fees.configmap.CLIENT_ID` → default value |

**Before (v8.0.0):**

```yaml
stringData:
  CLIENT_ID: {{ .Values.fees.secrets.CLIENT_ID | default "ac56c81d4d6d95c0ac12" | quote }}
```

**After (v8.0.1):**

```yaml
stringData:
  CLIENT_ID: {{ .Values.fees.secrets.CLIENT_ID | default .Values.fees.configmap.CLIENT_ID | default "ac56c81d4d6d95c0ac12" | quote }}
```

**Why this matters:**

In v8.0.0, `CLIENT_ID` was moved from the ConfigMap to the Secret to align with the `CLIENT_SECRET` pairing pattern used in other charts. However, operators upgrading from pre-v8.0.0 versions who had set `CLIENT_ID` in `fees.configmap.CLIENT_ID` would have lost that configuration unless they explicitly migrated it to `fees.secrets.CLIENT_ID`.

This patch release adds a fallback that checks the old ConfigMap location before applying the default value, ensuring a smoother upgrade path without requiring immediate manual migration.

**Migration impact:**

- **No action required** for most operators — the upgrade will work seamlessly
- If you currently have `CLIENT_ID` set in `fees.configmap.CLIENT_ID`, it will continue to work automatically
- If you have already migrated to `fees.secrets.CLIENT_ID` in v8.0.0, that value takes precedence (no change in behavior)
- If you have not set `CLIENT_ID` anywhere, the default value `"ac56c81d4d6d95c0ac12"` continues to be used

**Recommended migration path:**

While the fallback ensures compatibility, it is recommended to explicitly move `CLIENT_ID` to the secrets section for consistency:

#### Option 1: Keep existing ConfigMap location (temporary)

No changes needed — the fallback will handle it automatically.

```yaml
fees:
  configmap:
    CLIENT_ID: "your-custom-client-id"
```

#### Option 2: Migrate to secrets location (recommended)

Move the value to the secrets section and remove it from configmap:

```yaml
fees:
  secrets:
    CLIENT_ID: "your-custom-client-id"
    CLIENT_SECRET: "your-client-secret"
  # Remove CLIENT_ID from configmap if present
  configmap: {}
```

> **Note:** The fallback will remain in place for future releases to support gradual migration, but storing `CLIENT_ID` alongside `CLIENT_SECRET` in the secrets section is the recommended long-term configuration.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.1 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 8.0.1 -n plugin-fees
```
