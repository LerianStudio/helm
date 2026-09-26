# Helm Upgrade from v3.1.3 to v3.1.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. RabbitMQ plugin user tags corrected](#1-rabbitmq-plugin-user-tags-corrected)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.1.3` to `3.1.4`. This is a **patch** release that fixes the RabbitMQ bootstrap configuration for the plugin user.

The application version (`appVersion: 3.1.0`) is unchanged. No breaking changes, no required `values.yaml` modifications, and no data migration are needed.

## Fixes

### 1. RabbitMQ plugin user tags corrected

The RabbitMQ bootstrap Job previously assigned `administrator` tags to the `plugin` user. This has been corrected to assign no tags (empty string), following the principle of least privilege.

**Before (v3.1.3):**

```yaml
--data "{\"password\":\"$PASS\",\"tags\":\"administrator\"}"
```

**After (v3.1.4):**

```yaml
--data "{\"password\":\"$PASS\",\"tags\":\"\"}"
```

| Setting | v3.1.3 | v3.1.4 |
|---------|--------|--------|
| RabbitMQ plugin user tags | `"administrator"` | `""` (empty) |

> **Note:** The `plugin` user is created by the `bootstrap-rabbitmq` Job and is used by the fetcher application to connect to RabbitMQ. Administrator privileges are not required for normal operation.

**Why this matters:**

The `administrator` tag grants full management API access, including the ability to create/delete users, vhosts, and policies. The fetcher application only needs to publish and consume messages, not manage RabbitMQ infrastructure. Removing the administrator tag reduces the security risk if the plugin user credentials are compromised.

**Operational impact:**

- **New installations:** The plugin user will be created without administrator privileges. No action required.
- **Existing installations:** The bootstrap Job runs as a post-install/post-upgrade hook. On upgrade, it will attempt to update the existing `plugin` user to remove the administrator tag. This operation is idempotent and safe.

> **Important:** If your deployment relies on the plugin user having administrator privileges for custom automation or monitoring, you will need to either:
> - Create a separate RabbitMQ user with administrator privileges for those tasks, or
> - Manually restore the administrator tag after the upgrade using the RabbitMQ management UI or API

To verify the plugin user tags after upgrade:

```bash
# Port-forward to RabbitMQ management interface
kubectl port-forward -n fetcher svc/fetcher-rabbitmq 15672:15672

# Check user tags via API (requires admin credentials)
curl -u guest:your-admin-password http://localhost:15672/api/users/plugin
```

The response should show `"tags": ""` or `"tags": []`.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will update the `bootstrap-rabbitmq` Job template, and the Job will run automatically as a post-upgrade hook to update the plugin user configuration.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify the bootstrap Job completed successfully:

```bash
kubectl get jobs -n fetcher -l app.kubernetes.io/component=bootstrap-rabbitmq
```

4. Check the bootstrap Job logs to confirm the plugin user was updated:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=bootstrap-rabbitmq --tail=100
```

5. Verify the manager and worker pods are healthy and connecting to RabbitMQ:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker
```

> **Note:** The plugin user permissions change does not affect existing RabbitMQ connections. The manager and worker pods do not need to be restarted unless the bootstrap Job fails.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.4 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.4 -n fetcher
```
