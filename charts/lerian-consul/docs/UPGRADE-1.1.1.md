# Helm Upgrade from v1.1.0 to v1.1.1

## Topics

- **[Fixes](#fixes)**
  - [Consul DNS service disabled](#consul-dns-service-disabled)
- **[Configuration Changes](#configuration-changes)**
  - [1. Consul DNS disabled](#1-consul-dns-disabled)
  - [2. NOTES.txt updated with gossip encryption recommendation](#2-notestxt-updated-with-gossip-encryption-recommendation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### Consul DNS service disabled

The upstream hashicorp/consul chart renders a separate `<consul-fullname>-dns` Service on port 53 and declares DNS ports (8600 tcp/udp) on the server Service, even when the Consul agent's DNS listener is disabled via `ports.dns: -1`. This chart has always disabled the DNS listener because lib-service-discovery uses only the HTTP API, never Consul DNS.

**What changed:**

v1.1.1 now explicitly sets `consul.dns.enabled: false` in `values.yaml` to prevent the upstream chart from rendering the unused DNS Service and anonymous DNS ACL policy.

**Why this matters:**

- **Reduced attack surface:** The unused DNS Service and anonymous DNS read grant are no longer created
- **Cleaner resource list:** `kubectl get svc -n lerian-consul` no longer shows a `<consul-fullname>-dns` Service that binds no listener
- **No functional impact:** The Consul agent DNS listener was already disabled in v1.1.0 via `extraConfig: {"ports": {"dns": -1}}`; this change only stops the chart from rendering Kubernetes resources for a feature that is not in use

**What you need to do:**

- No action required. The upgrade will remove the unused DNS Service and ACL policy automatically
- If you have external monitoring or scripts that reference the `<consul-fullname>-dns` Service, remove those references

---

## Configuration Changes

### 1. Consul DNS disabled

The chart now explicitly disables the Consul DNS feature in the upstream subchart.

**Before (v1.1.0):**

The `consul.dns` key was not set (defaulted to `enabled: true` in the upstream chart), but the DNS listener was disabled via agent config:

```yaml
consul:
  server:
    extraConfig: |
      {"ports": {"dns": -1}}
```

**After (v1.1.1):**

```yaml
consul:
  dns:
    enabled: false
  server:
    extraConfig: |
      {"ports": {"dns": -1}}
```

| Setting | v1.1.0 | v1.1.1 |
|---------|--------|--------|
| `consul.dns.enabled` | (not set, defaults to `true`) | `false` |

**Why this matters:**

- The upstream chart's DNS feature includes a Service on port 53 and an anonymous ACL policy for DNS reads
- With `dns.enabled: false`, these resources are no longer rendered
- The Consul agent DNS listener remains disabled via `ports.dns: -1` (unchanged from v1.1.0)

**What you need to do:**

- If you override `consul.dns` in your `values.yaml`, ensure it remains `enabled: false`
- If you have workloads that expect a `<consul-fullname>-dns` Service, migrate them to use the HTTP API (port 8500) instead

### 2. NOTES.txt updated with gossip encryption recommendation

The post-install NOTES now include the `consul.global.gossipEncryption.autoGenerate=true` flag in the HA scaling example.

**Before (v1.1.0):**

```yaml
--set consul.server.replicas=3 --set consul.server.bootstrapExpect=3
```

**After (v1.1.1):**

```yaml
--set consul.server.replicas=3 --set consul.server.bootstrapExpect=3 \
--set consul.global.gossipEncryption.autoGenerate=true
```

**Why this matters:**

- Gossip encryption secures Consul's internal cluster communication (Serf protocol)
- The default single-server deployment does not require gossip encryption (no cluster traffic)
- Multi-server HA deployments should enable it to prevent eavesdropping and tampering on the gossip layer

**What you need to do:**

- If you are running a single-server deployment (the default), no action is required
- If you scale to 3+ servers for HA, add the gossip encryption flag:

```bash
helm upgrade lerian-consul oci://registry-1.docker.io/lerianstudio/lerian-consul-helm \
  --version 1.1.1 \
  --set consul.server.replicas=3 \
  --set consul.server.bootstrapExpect=3 \
  --set consul.global.gossipEncryption.autoGenerate=true \
  -n lerian-consul
```

> **Note:** The `autoGenerate=true` flag creates a Kubernetes Secret with a random 32-byte gossip key. If you already have a gossip key Secret from a previous install, the chart will reuse it (the upstream subchart's gossip-key Job is idempotent).

---

## Preview changes before upgrading

```bash
helm diff upgrade lerian-consul oci://registry-1.docker.io/lerianstudio/lerian-consul-helm --version 1.1.1 -n lerian-consul
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade lerian-consul oci://registry-1.docker.io/lerianstudio/lerian-consul-helm --version 1.1.1 -n lerian-consul
```
