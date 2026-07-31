# Helm Upgrade from v1.2.0 to v1.2.1

## Topics ToC

- **[Fixes](#fixes)**
  - [Service Discovery TLS Skip Verify Default](#service-discovery-tls-skip-verify-default)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### Service Discovery TLS Skip Verify Default

The default value for the `SD_TLS_SKIP_VERIFY` environment variable has been changed from `true` to `false` to improve security posture for service discovery TLS connections.

| Setting | v1.2.0 | v1.2.1 |
|---------|---------|---------|
| `SD_TLS_SKIP_VERIFY` default | `true` | `false` |

#### What changed

The `lerian-common.serviceDiscovery.env` helper now defaults `SD_TLS_SKIP_VERIFY` to `false` instead of `true` when the field is not explicitly set in `global.serviceDiscovery.tlsSkipVerify` or component-level `configmap.SD_TLS_SKIP_VERIFY`.

**Before (v1.2.0):**

```yaml
SD_TLS_SKIP_VERIFY: {{ $sd.tlsSkipVerify | default true | quote }}
```

**After (v1.2.1):**

```yaml
SD_TLS_SKIP_VERIFY: {{ $sd.tlsSkipVerify | default false | quote }}
```

#### Why it matters

Skipping TLS certificate verification is a security risk in production environments. The previous default (`true`) was permissive and could allow man-in-the-middle attacks when service discovery is configured with TLS enabled.

The new default (`false`) enforces certificate validation by default, aligning with security best practices. This ensures that service discovery connections verify the Consul server's certificate chain unless explicitly disabled.

#### Operational impact

**For deployments with `global.serviceDiscovery.tlsSkipVerify` explicitly set:**

No impact. The helper respects the explicit value in your umbrella `values.yaml`:

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: true  # Explicit override — behavior unchanged
```

**For deployments with `global.serviceDiscovery.tlsSkipVerify` not set:**

The rendered `SD_TLS_SKIP_VERIFY` environment variable will change from `"true"` to `"false"`.

**Impact scenarios:**

1. **Service discovery disabled (`SD_ENABLED=false`):** No impact. The variable is ignored when service discovery is disabled.

2. **Service discovery enabled with TLS disabled (`SD_TLS=false`):** No impact. The variable is ignored when TLS is not enabled.

3. **Service discovery enabled with TLS enabled (`SD_TLS=true`) and valid certificates:** No impact. Certificate validation will succeed.

4. **Service discovery enabled with TLS enabled and self-signed/invalid certificates:** **Breaking change.** Service discovery connections will fail with certificate validation errors.

#### Migration steps

**If your Consul server uses valid certificates signed by a trusted CA:**

No action required. The new default is correct for your environment.

**If your Consul server uses self-signed certificates or certificates not trusted by the container's CA bundle:**

You must explicitly set `tlsSkipVerify: true` to maintain existing behavior:

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: true  # Required for self-signed certificates
    workload: "production"
```

> **Warning:** Setting `tlsSkipVerify: true` disables certificate validation and should only be used in non-production environments or when you have a documented security exception. For production deployments, configure your Consul server with valid certificates and remove this override.

**Alternative (recommended for production):**

Instead of disabling certificate validation, configure your container to trust the Consul server's CA certificate:

1. Add the CA certificate to your container's trust store (via init container or base image customization)
2. Remove or set `tlsSkipVerify: false` in your values
3. Verify service discovery connections succeed with certificate validation enabled

> **Note:** Product charts that have adopted `lerian-common` will inherit this change when they upgrade their `lerian-common` dependency to v1.2.1. Coordinate with product chart maintainers to ensure compatibility.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.2.1 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.2.1 -n lerian-common
```
