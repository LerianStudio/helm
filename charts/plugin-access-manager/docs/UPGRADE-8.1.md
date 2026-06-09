# Helm Upgrade from v8.0.1 to v8.1.0

# Topics

- **[Features](#features)**
  - [1. Improved Init Container URL Parsing](#1-improved-init-container-url-parsing)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Improved Init Container URL Parsing

The identity service's init container now includes enhanced URL parsing logic to properly handle both HTTP and HTTPS URLs, with automatic port detection when ports are not explicitly specified.

**What changed:**

The init container script that checks the availability of the `PLUGIN_AUTH_ADDRESS` service has been updated with more robust URL parsing logic.

**Before (v8.0.1):**

```yaml
# identity/deployment.yaml - init container script
for svc in "$PLUGIN_AUTH_ADDRESS";
do
  echo "Checking $svc...";
  hostport=$(echo "$svc" | sed 's|http://||');
  host=$(echo "$hostport" | cut -d: -f1);
  port=$(echo "$hostport" | cut -d: -f2);
  while ! nc -z "$host" "$port"; do
    echo "$svc is not ready yet, waiting...";
    sleep 5;
  done;
done
```

**After (v8.1.0):**

```yaml
# identity/deployment.yaml - init container script
for svc in "$PLUGIN_AUTH_ADDRESS";
do
  echo "Checking $svc...";
  case "$svc" in https://*) default_port=443;; *) default_port=80;; esac;
  hostport=$(echo "$svc" | sed -E 's|^https?://||' | cut -d/ -f1);
  host=$(echo "$hostport" | cut -d: -f1);
  case "$hostport" in *:*) port=$(echo "$hostport" | cut -d: -f2);; *) port=$default_port;; esac;
  while ! nc -z "$host" "$port"; do
    echo "$svc is not ready yet, waiting...";
    sleep 5;
  done;
done
```

**Why this matters:**

The previous implementation had limitations when handling URLs:

- Only stripped `http://` protocol prefix, failing with `https://` URLs
- Did not handle URLs without explicit port numbers correctly
- Could fail to parse URLs with paths (e.g., `http://service.namespace.svc.cluster.local/path`)

The new implementation:

- Automatically detects the protocol (`https://` or `http://`) and sets the appropriate default port (443 for HTTPS, 80 for HTTP)
- Strips both `http://` and `https://` prefixes using extended regex
- Extracts only the host and port portion, ignoring any path components
- Falls back to protocol-appropriate default ports when no port is explicitly specified

**Operational impact:**

This is a **non-breaking enhancement** that improves reliability. No configuration changes are required.

**Scenarios that now work correctly:**

| URL Format | v8.0.1 Behavior | v8.1.0 Behavior |
|------------|-----------------|-----------------|
| `http://auth-service:3000` | ✅ Works | ✅ Works |
| `https://auth-service:3000` | ❌ Fails (doesn't strip `https://`) | ✅ Works |
| `http://auth-service` | ❌ Fails (no port extracted) | ✅ Works (uses port 80) |
| `https://auth-service` | ❌ Fails (protocol + no port) | ✅ Works (uses port 443) |
| `http://auth-service.namespace.svc.cluster.local/health` | ⚠️ May fail (path in port parsing) | ✅ Works (path stripped) |

**What you should verify after upgrading:**

If your `PLUGIN_AUTH_ADDRESS` configuration uses any of the following formats, the upgrade will improve init container reliability:

```yaml
identity:
  secrets:
    PLUGIN_AUTH_ADDRESS: "https://auth-service"  # Now works without explicit port
```

```yaml
identity:
  secrets:
    PLUGIN_AUTH_ADDRESS: "https://auth-service.plugin-access-manager.svc.cluster.local"  # HTTPS now supported
```

```yaml
identity:
  secrets:
    PLUGIN_AUTH_ADDRESS: "http://auth-service.plugin-access-manager.svc.cluster.local/health"  # Path now handled
```

> **Note:** If you're using standard Kubernetes service DNS names with explicit ports (e.g., `http://auth-service:3000`), you won't notice any difference in behavior. The enhancement primarily benefits configurations using HTTPS, default ports, or URLs with path components.

> **Important:** This change only affects the init container's readiness check logic. It does not modify how the identity service connects to the auth service at runtime. The `PLUGIN_AUTH_ADDRESS` environment variable is still passed unchanged to the application container.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.1.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.1.0 -n plugin-access-manager
```
