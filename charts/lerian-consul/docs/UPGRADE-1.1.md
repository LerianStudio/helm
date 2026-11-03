# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Consul version upgrade: 1.20.6 → 2.1.0](#consul-version-upgrade-1206--210)
  - [No in-place upgrade path](#no-in-place-upgrade-path)
- **[Configuration Changes](#configuration-changes)**
  - [1. Consul server image](#1-consul-server-image)
  - [2. Consul control-plane image](#2-consul-control-plane-image)
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

> **Warning:** Review the [official Consul upgrade guide](https://developer.hashicorp.com/consul/docs/upgrading) before proceeding.

### No in-place upgrade path

According to the Chart.yaml comment in the diff:

> There is no supported in-place path from Consul 1.x, so the 1.x → 2.x move is a fresh install (see README, "Upgrading from 1.x").

**What this means for operators:**

You **cannot** perform a rolling upgrade from v1.0.0 to v1.1.0 while preserving existing Consul state (KV data, service registrations, ACL tokens, etc.). The upgrade is a fresh install:

#### Fresh install

This is the only supported path. HashiCorp supports no in-place upgrade from Consul 1.x to 2.x.

1. Uninstall the existing v1.0.0 release:

```bash
helm uninstall lerian-consul -n lerian-consul
```

2. With ACLs on (`consul.global.acls.manageSystemACLs=true`, the default), delete the old bootstrap Secret. An existing one makes the new install skip ACL bootstrap:

```bash
kubectl delete secret -n lerian-consul lerian-consul-consul-bootstrap-acl-token
```

3. Delete the server PVCs. A stale Raft data dir from 1.x prevents the 2.x server from starting. List them with `kubectl get pvc -n lerian-consul`; they are named `data-<namespace>-<consul-fullname>-server-<n>`:

```bash
kubectl delete pvc -n lerian-consul <pvc-name>
```

4. Install v1.1.0 as a fresh deployment:

```bash
helm install lerian-consul oci://ghcr.io/lerianstudio/lerian-consul --version 1.1.0 -n lerian-consul
```

5. With `consul.global.acls.manageSystemACLs=true`, the new install bootstraps a new ACL system. Re-mint the per-workload SD tokens (see the chart README, "ACL tokens"), update each workload's `SD_TOKEN`, and restart the consuming workloads if they do not re-register on their own.

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

**What you need to do:**

- If you override `consul.global.image` in your `values.yaml`, update it to the new digest
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
- The image is pinned by digest to prevent supply-chain drift

**What you need to do:**

- If you override `consul.global.imageK8S`, update it to the new digest

---


## Command to upgrade

> **Warning:** Do not `helm upgrade` an existing 1.x release. Follow the fresh-install steps above, which end with:

```bash
helm install lerian-consul oci://ghcr.io/lerianstudio/lerian-consul --version 1.1.0 -n lerian-consul
```
