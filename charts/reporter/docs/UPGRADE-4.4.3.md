# Helm Upgrade from v4.4.2 to v4.4.3

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Access Manager permission declaration support](#1-access-manager-permission-declaration-support)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds optional Access Manager integration to the reporter manager component. The application version remains unchanged at `4.5.0`.

| Field | v4.4.2 | v4.4.3 |
|-------|--------|--------|
| Chart version | `4.4.2` | `4.4.3` |
| App version | `4.5.0` | `4.5.0` |

## Features

### 1. Access Manager permission declaration support

The manager component now supports optional integration with the Access Manager identity provider (IDP) for permission manifest publication. When enabled, the manager publishes its permission manifest at boot time and requires IDP connectivity and machine-to-machine (M2M) client credentials.

Two new environment variables have been added to `manager.configmap`:

| Variable | Default | Description |
|----------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `"false"` (commented) | Enable Access Manager permission declaration. When `"true"`, manager publishes permission manifest at boot |
| `IDP_HOST` | `""` (commented) | Access Manager identity service URL (e.g. `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001`) |

When `IDP_DECLARATION_ENABLED="true"`, the manager also requires the following top-level secrets to be set:

- `secrets.IDP_M2M_CLIENT_ID` — Machine-to-machine client ID for IDP authentication
- `secrets.IDP_M2M_CLIENT_SECRET` — Machine-to-machine client secret for IDP authentication

> **Note:** These secret fields are not new to this release; they already exist in the chart schema. This release adds the manager-side environment variables that consume them.

**Default configuration (v4.4.3):**

```yaml
manager:
  configmap:
    # IDP_DECLARATION_ENABLED: "false"
    # IDP_HOST: ""
```

Both variables are commented out by default, preserving existing behavior. The manager will not attempt IDP integration unless explicitly enabled.

**Enabled configuration example:**

```yaml
manager:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.reporter.svc.cluster.local:4001"

secrets:
  IDP_M2M_CLIENT_ID: "your-client-id"
  IDP_M2M_CLIENT_SECRET: "your-client-secret"
```

> **Warning:** When `IDP_DECLARATION_ENABLED="true"`, the manager will refuse to start if `IDP_HOST` is not set or if the M2M client credentials are missing. Ensure all three values are configured before enabling this feature.

## Configuration Changes

No existing configuration keys were removed or renamed. Two new optional environment variables were added to `manager.configmap`.

| Setting | v4.4.2 | v4.4.3 | Notes |
|---------|--------|--------|-------|
| `manager.configmap.IDP_DECLARATION_ENABLED` | not present | `"false"` (commented) | Opt-in feature; defaults to disabled |
| `manager.configmap.IDP_HOST` | not present | `""` (commented) | Required when `IDP_DECLARATION_ENABLED="true"` |

## Migration Steps

This upgrade requires no mandatory configuration changes. The new IDP integration is opt-in and disabled by default.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. If you do **not** need Access Manager integration, proceed directly to the upgrade command. The manager will continue to operate as before.

3. If you **do** need Access Manager integration, add the following to your values override file:

   ```yaml
   manager:
     configmap:
       IDP_DECLARATION_ENABLED: "true"
       IDP_HOST: "http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001"
   
   secrets:
     IDP_M2M_CLIENT_ID: "your-client-id"
     IDP_M2M_CLIENT_SECRET: "your-client-secret"
   ```

   Replace `<namespace>` with your actual namespace and provide valid M2M credentials.

4. Run the upgrade command during a maintenance window.

5. Verify the manager pod is running and healthy:

   ```bash
   kubectl get pods -n <namespace> -l app.kubernetes.io/name=reporter-manager
   ```

6. If you enabled IDP integration, check the manager logs to confirm successful permission manifest publication:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50 | grep -i "permission\|idp\|declaration"
   ```

> **Note:** The upgrade triggers a rolling restart of the manager deployment only. The worker component is not affected by this change.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.3 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.4.3 -n reporter
```
