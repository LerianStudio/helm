# Helm Upgrade from v2.0.0 to v2.1.0

## Topics

- **[Features](#features)**
  - [1. Outbound Pix transit](#1-outbound-pix-transit)
  - [2. New secret key for JD SPI authentication](#2-new-secret-key-for-jd-spi-authentication)
  - [3. Template refactoring for multi-port services](#3-template-refactoring-for-multi-port-services)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### 1. Outbound Pix transit

**What changed:**

The `admin` role can now serve an outbound Pix transit on a new port (`ports.pixTransit`, default `8082`). Pix engines call this transit in place of JD's JDPI address. The transit is disabled by default and requires TLS configuration when enabled.

| Setting | v2.0.0 | v2.1.0 |
|---------|---------|---------|
| `ports.pixTransit` | Not present | `8082` |
| `roles.admin.pixTransit.enabled` | Not present | `false` (default) |
| `roles.admin.pixTransit.tls.existingSecret` | Not present | `""` (default) |
| `roles.admin.pixTransit.tls.terminatedUpstream` | Not present | `false` (default) |

**New environment variables (when `roles.admin.pixTransit.enabled: true`):**

| Variable | Set By | Description |
|----------|--------|-------------|
| `PIX_TRANSIT_SERVER_ADDRESS` | Derived from `ports.pixTransit` | Transit listener address (e.g., `:8082`) |
| `PIX_TRANSIT_TLS_CERT_FILE` | Derived from `roles.admin.pixTransit.tls.existingSecret` | Path to TLS certificate (e.g., `/etc/jd-courier/pix-transit-tls/tls.crt`) |
| `PIX_TRANSIT_TLS_KEY_FILE` | Derived from `roles.admin.pixTransit.tls.existingSecret` | Path to TLS private key (e.g., `/etc/jd-courier/pix-transit-tls/tls.key`) |
| `PIX_TRANSIT_TLS_TERMINATED_UPSTREAM` | Derived from `roles.admin.pixTransit.tls.terminatedUpstream` | Set to `"true"` if TLS is terminated before the pod |

**Why it matters:**

Pix engines refuse plain HTTP connections. If you enable the transit without configuring TLS, the chart will refuse to render:

> **Warning:** The chart enforces that `roles.admin.pixTransit.enabled: true` requires either `roles.admin.pixTransit.tls.existingSecret` or `roles.admin.pixTransit.tls.terminatedUpstream: true`. Without one of these, `helm template` or `helm install` will fail with: `roles.admin.pixTransit.enabled needs roles.admin.pixTransit.tls.existingSecret or roles.admin.pixTransit.tls.terminatedUpstream=true: the Pix engines refuse plain HTTP`

**When enabled:**

- The `admin` Deployment exposes port `8082` (configurable via `ports.pixTransit`)
- The `admin` Service includes a `pix-transit` port mapping
- The pod mounts the TLS Secret at `/etc/jd-courier/pix-transit-tls` (if `existingSecret` is set)
- The application serves TLS itself (if `existingSecret` is set) or expects TLS termination upstream (if `terminatedUpstream: true`)

**Configuration options:**

#### Option 1: TLS terminated by the pod (self-signed or CA-issued certificate)

Create a `kubernetes.io/tls` Secret with `tls.crt` and `tls.key`:

```bash
kubectl create secret tls br-jd-courier-pix-transit-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n br-jd-courier
```

Enable the transit and reference the Secret:

```yaml
ports:
  pixTransit: 8082

roles:
  admin:
    pixTransit:
      enabled: true
      tls:
        existingSecret: "br-jd-courier-pix-transit-tls"
```

> **Note:** The certificate is read once at boot. Rotating it requires a rollout restart of the `admin` Deployment.

#### Option 2: TLS terminated upstream (service mesh, load balancer, ingress)

If TLS is terminated before the pod (e.g., by Istio, Linkerd, or a cloud load balancer), set `terminatedUpstream: true`:

```yaml
ports:
  pixTransit: 8082

roles:
  admin:
    pixTransit:
      enabled: true
      tls:
        terminatedUpstream: true
```

The pod will serve plain HTTP on `ports.pixTransit`, but the chart signals to the application that TLS is handled upstream by setting `PIX_TRANSIT_TLS_TERMINATED_UPSTREAM=true`.

**Migration action:**

No action required if you do not need the Pix transit. The feature is disabled by default (`roles.admin.pixTransit.enabled: false`).

**To enable the transit:**

1. Choose a TLS termination strategy (Option 1 or Option 2 above)
2. If using Option 1, create the TLS Secret before upgrading
3. Add the `roles.admin.pixTransit` block to your `values.yaml`
4. Upgrade the chart

**Additional configuration keys:**

The transit reads several environment variables from `config` (see the updated `values.yaml` comments). These keys are documented in the application README under "Pix transit":

- `JD_ALLOW_PRIVATE_NETWORK` (now governs both SPB roles and the Pix transit)
- Transit-specific keys (refer to the application README for the full list)

> **Important:** The chart now refuses `config.PIX_TRANSIT_SERVER_ADDRESS`, `config.PIX_TRANSIT_TLS_CERT_FILE`, `config.PIX_TRANSIT_TLS_KEY_FILE`, and `config.PIX_TRANSIT_TLS_TERMINATED_UPSTREAM` — these are derived from `ports.pixTransit` and `roles.admin.pixTransit.tls`.

### 2. New secret key for JD SPI authentication

**What changed:**

The chart now recognizes `JD_SPI_CLIENT_SECRET` as a secret key and refuses to render if it appears in `config`. This key must arrive through `secrets.existingSecret`, just like `JD_PASSWORD`.

| Setting | v2.0.0 | v2.1.0 |
|---------|---------|---------|
| Refused secret keys in `config` | `JD_PASSWORD`, `JD_PRIVATE_KEY_PEM`, ... | `JD_PASSWORD`, `JD_SPI_CLIENT_SECRET`, `JD_PRIVATE_KEY_PEM`, ... |

**Why it matters:**

If you were setting `JD_SPI_CLIENT_SECRET` in `config` (which was not explicitly refused in v2.0.0), the chart will now fail to render. This key is a secret and must be stored in the Secret referenced by `secrets.existingSecret`.

**Migration action:**

If you use `JD_SPI_CLIENT_SECRET`:

1. Remove it from `config` in your `values.yaml`
2. Add it to the Secret referenced by `secrets.existingSecret`:

```bash
kubectl create secret generic br-jd-courier-secrets \
  --from-literal=LICENSE_KEY='your-license-key' \
  --from-literal=JD_PASSWORD='your-jd-password' \
  --from-literal=JD_SPI_CLIENT_SECRET='your-spi-client-secret' \
  --dry-run=client -o yaml | kubectl apply -f - -n br-jd-courier
```

> **Note:** If you do not use `JD_SPI_CLIENT_SECRET`, no action is required.

### 3. Template refactoring for multi-port services

**What changed:**

The chart's internal templates have been refactored to support roles that expose multiple ports. This is an internal change to enable the Pix transit feature — the rendered manifests for existing roles (`spb-consumer`, `spb-sender`, `pix-ingress`) are functionally identical.

**Before (v2.0.0):**

Services were rendered with a single port, passed as a string:

```yaml
# spb-sender/service.yaml
{{- include "br-jd-courier.service" (dict "ctx" $ "key" "spbSender" "role" "spb-sender" "port" "soap") }}
```

**After (v2.1.0):**

Services are rendered with a list of ports:

```yaml
# spb-sender/service.yaml
{{- include "br-jd-courier.service" (dict "ctx" $ "key" "spbSender" "role" "spb-sender" "ports" (list "soap")) }}
```

The `admin` Service now conditionally includes the `pixTransit` port when `roles.admin.pixTransit.enabled: true`:

```yaml
# admin/service.yaml
{{- include "br-jd-courier.service" (dict "ctx" $ "key" "admin" "role" "admin" "ports" (splitList " " (include "br-jd-courier.adminPorts" .))) }}
```

**Why it matters:**

This change has **no operational impact** for existing deployments. The rendered Kubernetes manifests are identical for roles that expose a single port. The refactoring enables the `admin` role to expose both `http` (port `8080`) and `pixTransit` (port `8082`) when the transit is enabled.

**Migration action:**

None required. This is an internal template change with no user-facing configuration impact.

---

## Configuration Reference

### New configuration blocks

#### Pix transit configuration

```yaml
ports:
  http: 8080
  soap: 8081
  pixTransit: 8082  # New in v2.1.0

roles:
  admin:
    enabled: true
    replicas: 1
    resources: {}
    service:
      type: ClusterIP
    # New in v2.1.0
    pixTransit:
      enabled: false
      tls:
        existingSecret: ""
        terminatedUpstream: false
```

| Flag | Default | Description |
|------|---------|-------------|
| `ports.pixTransit` | `8082` | Port for the outbound Pix transit (served by `admin` role) |
| `roles.admin.pixTransit.enabled` | `false` | Whether to enable the Pix transit listener |
| `roles.admin.pixTransit.tls.existingSecret` | `""` | Name of a `kubernetes.io/tls` Secret (with `tls.crt`, `tls.key`) for TLS termination by the pod |
| `roles.admin.pixTransit.tls.terminatedUpstream` | `false` | Set to `true` if TLS is terminated before the pod (e.g., by a service mesh or load balancer) |

### Updated configuration restrictions

The chart now refuses the following additional keys in `config`:

| Refused Key | Reason |
|-------------|--------|
| `PIX_TRANSIT_SERVER_ADDRESS` | Derived from `ports.pixTransit` |
| `PIX_TRANSIT_TLS_CERT_FILE` | Derived from `roles.admin.pixTransit.tls.existingSecret` |
| `PIX_TRANSIT_TLS_KEY_FILE` | Derived from `roles.admin.pixTransit.tls.existingSecret` |
| `PIX_TRANSIT_TLS_TERMINATED_UPSTREAM` | Derived from `roles.admin.pixTransit.tls.terminatedUpstream` |
| `JD_SPI_CLIENT_SECRET` | Must arrive through `secrets.existingSecret` (secret key) |

### Updated Secret keys

The Secret referenced by `secrets.existingSecret` may now contain:

| Key | Required By | Description |
|-----|-------------|-------------|
| `JD_SPI_CLIENT_SECRET` | SPB roles, Pix transit (if used) | JD SPI client secret for authentication |

> **Note:** This key is optional. Add it only if your deployment uses JD SPI authentication.

### Example values.yaml with Pix transit enabled

**Option 1: TLS terminated by the pod**

```yaml
jd-courier:
  image:
    tag: "1.1.0"

secrets:
  existingSecret: "br-jd-courier-secrets"

config:
  ENVIRONMENT_NAME: "production"
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  JD_BASE_URL: "https://jd-consultores.example.com"
  JD_ALLOW_PRIVATE_NETWORK: "false"

ports:
  pixTransit: 8082

roles:
  admin:
    enabled: true
    replicas: 1
    pixTransit:
      enabled: true
      tls:
        existingSecret: "br-jd-courier-pix-transit-tls"
```

**Option 2: TLS terminated upstream**

```yaml
jd-courier:
  image:
    tag: "1.1.0"

secrets:
  existingSecret: "br-jd-courier-secrets"

config:
  ENVIRONMENT_NAME: "production"
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  JD_BASE_URL: "https://jd-consultores.example.com"
  JD_ALLOW_PRIVATE_NETWORK: "false"

ports:
  pixTransit: 8082

roles:
  admin:
    enabled: true
    replicas: 1
    pixTransit:
      enabled: true
      tls:
        terminatedUpstream: true
```

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.0 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.0 -n br-jd-courier
```
