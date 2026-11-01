# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Consul version upgrade: 1.20.6 → 2.1.0](#consul-version-upgrade-1206--210)
  - [No in-place upgrade path](#no-in-place-upgrade-path)
- **[Configuration Changes](#configuration-changes)**
  - [1. Consul server image](#1-consul-server-image)
  - [2. Consul control-plane image](#2-consul-control-plane-image)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Consul version upgrade: 1.20.6 → 2.1.0

The lerian-consul chart now ships **Consul 2.1.0** (a major version bump from 1.20.6). This is a significant change that affects the underlying Consul binary, the consul-k8s control-plane, and the upstream Helm chart dependency.

| Component | v1.0.0 | v1.1.0 |
|-----------|--------|--------|
| Consul binary | 1.20.6 | 2.1.0 |
| consul-k8s control-plane | 1.6.10 | 2.1.0 |
| hashicorp/consul chart | 1.6.10 | 2.1.0 |

> **Warning:** Consul 2.x introduces breaking changes in the data plane, API, and configuration schema. Review the [official Consul 2.0 upgrade guide](https://developer.hashicorp.com/consul/docs/upgrading) before proceeding.

### No in-place upgrade path

According to the Chart.yaml comment in the diff:

> There is no supported in-place path from Consul 1.x, so the 1.x → 2.x move is a fresh install (see README, "Upgrading from 1.x").

**What this means for operators:**

You **cannot** perform a rolling upgrade from v1.0.0 to v1.1.0 while preserving existing Consul state (KV data, service registrations, ACL tokens, etc.). The upgrade requires one of the following approaches:

#### Option 1: Fresh install (data loss)

If your Consul cluster does not hold critical state, or if you can afford to lose ephemeral service mesh registrations:

1. Uninstall the existing v1.0.0 release:

```bash
helm uninstall lerian-consul -n lerian-consul
```

2. Delete the PersistentVolumeClaims (if any) to ensure a clean slate:

```bash
kubectl delete pvc -n lerian-consul -l app=consul
```

3. Install v1.1.0 as a fresh deployment:

```bash
helm install lerian-consul oci://registry-1.docker.io/lerianstudio/lerian-consul-helm --version 1.1.0 -n lerian-consul
```

> **Important:** All ACL tokens, KV data, and service registrations will be lost. Plan for service re-registration and ACL token regeneration.

#### Option 2: Backup and restore (manual migration)

If you need to preserve Consul state:

1. **Backup Consul data** from the v1.0.0 cluster:
   - Export ACL tokens, policies, and roles
   - Snapshot the KV store using `consul snapshot save`
   - Document service registrations and intentions

2. **Deploy v1.1.0** as a fresh install (see Option 1, steps 1–3)

3. **Restore data** into the new Consul 2.1.0 cluster:
   - Re-create ACL policies and tokens (note: schema may have changed)
   - Restore KV data using `consul snapshot restore` or manual import
   - Re-register services (update sidecar configurations for Consul 2.x compatibility)

> **Note:** Consul 2.x may reject snapshots or configurations from 1.x due to schema changes. Test the restore process in a staging environment first.

#### Option 3: Blue-green deployment

For production environments with zero-downtime requirements:

1. Deploy a **new Consul 2.1.0 cluster** (v1.1.0 chart) in a separate namespace or cluster
2. Gradually migrate services to register with the new cluster
3. Decommission the old Consul 1.20.6 cluster once migration is complete

---

## Configuration Changes

### 1. Consul server image

The Consul server image has been updated to version 2.1.0 with a new SHA256 digest.

**Before (v1.0.0):**

```yaml
consul:
  global:
    image: "hashicorp/consul:1.20.6@sha256:200471c74bc0965cd20c81eacc31a209873d5d9e599fe637ceb856b0cbbc518d"
```

**After (v1.1.0):**

```yaml
consul:
  global:
    image: "hashicorp/consul:2.1.0@sha256:259fd02f2544fe1aa03fa49efd3b105c8dd67106d710a72f5e898110266356f7"
```

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `consul.global.image` | `hashicorp/consul:1.20.6@sha256:200471c...` | `hashicorp/consul:2.1.0@sha256:259fd02...` |

**Why this matters:**

- The image is pinned by **digest** (not just tag) to ensure reproducibility
- Consul 2.1.0 includes breaking changes in CLI commands, API endpoints, and configuration schema
- Existing scripts or automation that interact with Consul may need updates

**What you need to do:**

- If you override `consul.global.image` in your `values.yaml`, update it to the new digest
- If you use the default value, no action is required — the chart will pull the new image automatically
- Review your Consul client configurations, health checks, and API integrations for compatibility with Consul 2.x

### 2. Consul control-plane image

The consul-k8s control-plane image (used by ACL init, TLS init, and gossip-key jobs) has been updated to version 2.1.0.

**Before (v1.0.0):**

```yaml
consul:
  global:
    imageK8S: "hashicorp/consul-k8s-control-plane:1.6.10@sha256:9be63ef67b2271f090f26d56e4984604605c10265b91cac97a169e65acba0af7"
```

**After (v1.1.0):**

```yaml
consul:
  global:
    imageK8S: "hashicorp/consul-k8s-control-plane:2.1.0@sha256:5e60f8a69442efe73b909c1b94277496fed0c8a881a586be825c3c88b9a58f2c"
```

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `consul.global.imageK8S` | `hashicorp/consul-k8s-control-plane:1.6.10@sha256:9be63ef...` | `hashicorp/consul-k8s-control-plane:2.1.0@sha256:5e60f8a...` |

**Why this matters:**

- The control-plane image manages ACL bootstrapping, TLS certificate generation, and gossip encryption keys
- Version 2.1.0 may introduce changes to RBAC requirements, secret formats, or job behavior
- The image is pinned by digest to prevent supply-chain drift

**What you need to do:**

- If you override `consul.global.imageK8S`, update it to the new digest
- If you use the default value, no action is required
- Verify that your Kubernetes RBAC policies allow the new control-plane version to create/update secrets and configmaps

---

## Preview changes before upgrading

```bash
helm diff upgrade lerian-consul oci://registry-1.docker.io/lerianstudio/lerian-consul-helm --version 1.1.0 -n lerian-consul
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

> **Warning:** As documented in [Breaking Changes](#breaking-changes), this is **not** an in-place upgrade. You must choose one of the migration strategies (fresh install, backup/restore, or blue-green) before running this command.

```bash
helm upgrade lerian-consul oci://registry-1.docker.io/lerianstudio/lerian-consul-helm --version 1.1.0 -n lerian-consul
```
