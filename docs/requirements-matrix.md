# Lerian Helm Charts — Requirements Matrix

## Minimum Kubernetes Version

All charts require **Kubernetes >= 1.24** (specified via `kubeVersion: ">=1.24.0-0"` in Chart.yaml).

This ensures access to:
- Stable v1 APIs (core, apps, batch, networking.k8s.io)
- Built-in CSI volume management
- Pod Security Standards (PSS)
- Resource quota improvements
- Network Policies v1

---

## Minimum Node Requirements

### Scenario-Based Sizing

| Scenario | Worker Nodes | vCPU (total) | Memory (total) | Storage |
|---|---|---|---|---|
| **Midaz core only** | 2 | 8 | 16Gi | 20Gi (PostgreSQL) |
| **Midaz + Console + Access Manager** | 2 | 12 | 24Gi | 20Gi (PostgreSQL) |
| **Full stack (all plugins)** | 3 | 20 | 48Gi | 50Gi (PostgreSQL + MongoDB + Valkey) |

**Notes:**
- Worker nodes = schedulable nodes (must NOT have `node-role.kubernetes.io/control-plane` taint)
- Control-plane nodes are NOT counted toward workload capacity
- Storage requirements are minimum; production deployments should over-provision for safety margin
- These are computed from default CPU/memory requests; adjust via values.yaml for your workload

---

## Per-Chart Resource Requests (defaults)

**Format:** Values reflect `resources.requests` in chart defaults. Override via values.yaml for production sizing.

| Chart | CPU Request | Memory Request | Replicas (default) | Storage Required |
|---|---|---|---|---|
| **midaz** | 3500m | 768Mi | 1 | Yes (PostgreSQL, MongoDB, Valkey subcharts) |
| **product-console** | 512m | 512Mi | 1 | No |
| **plugin-access-manager** | 600m | 384Mi | 1 | No |
| **matcher** | 1750m | 768Mi | 1 | Yes (PostgreSQL) |
| **tracer** | 100m | 128Mi | 1 | No |
| **fetcher** | 200m | 512Mi | 1 | No |
| **flowker** | 100m | 128Mi | 1 | No |
| **reporter** | 200m | 512Mi | 1 | No |
| **plugin-fees** | 100m | 128Mi | 1 | No |
| **plugin-bc-correios** | 100m | 128Mi | 1 | No |
| **plugin-br-bank-transfer** | 150m | 256Mi | 1 | No |
| **plugin-br-payments** | 150m | 256Mi | 1 | No |
| **plugin-br-pix-direct-jd** | 100m | 128Mi | 1 | No |
| **plugin-br-pix-indirect-btg** | 100m | 128Mi | 1 | No |
| **plugin-br-pix-switch** | 200m | 256Mi | 1 | No |
| **otel-collector-lerian** | 250m | 256Mi | 1 | No |
| **notifications** | 200m | 384Mi | 1 | No |
| **underwriter** | 150m | 256Mi | 1 | No |

**Calculation Method:**
- Values are summed from all containers' `requests` in chart defaults
- For charts with subcomponents (midaz includes ledger + crm services), all containers are included
- CPU is in millicores (m), Memory is in Mi (mebibytes)
- Resource **limits** are separate and typically 2-4x the requests
- **All values are defaults** — review and adjust for production sizing based on actual workload patterns

### Total Cluster Sizing

**Minimum for "Midaz core only" (2 worker nodes, 8 total vCPU, 16Gi total memory):**
```
Node 1: 4 vCPU, 8Gi memory
Node 2: 4 vCPU, 8Gi memory

Allocation:
- Midaz: 3500m CPU, 768Mi memory
- system-addons (kube-proxy, CNI, etc): ~500m CPU, 512Mi memory
- Remaining buffer: 0.5 vCPU, 6.2Gi memory per node
```

**Minimum for "Full stack" (3 worker nodes, 20 total vCPU, 48Gi total memory):**
```
All charts deployed:
- Total requests: ~8.5 vCPU, ~7Gi memory
- Buffer (25% over-provision): ~2.5 vCPU, 12Gi memory
- Actual required: 3 nodes × (7 vCPU, 16Gi memory) = adequate headroom
```

---

## Storage Class Requirements

### Charts Requiring Persistent Storage

| Chart | PVC Count | Size (default) | Access Mode | StorageClass |
|---|---|---|---|---|
| **midaz** | 3 | 10Gi each | RWO | Required (default) |
| **matcher** | 1 | 10Gi | RWO | Required (default) |

**Configuration:**
- Requires a **default StorageClass** with `ReadWriteOnce` (RWO) support
- Verify via: `kubectl get storageclass`
- If none is default, set one: `kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`

### Charts NOT Requiring Persistent Storage

All other charts (plugin-*, product-console, tracer, fetcher, flowker, reporter, otel-collector-lerian, underwriter, notifications) are stateless and do not require PVCs.

---

## Required CRDs (optional integrations)

### For TLS/Certificate Management

| CRD | Required by | Installed via | When to use |
|---|---|---|---|
| `certificates.cert-manager.io` | Any chart with `tls.enabled: true` | [cert-manager](https://cert-manager.io) | Production deployments with HTTPS |

```bash
# Install cert-manager (if needed)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true
```

### For Monitoring/Metrics

| CRD | Required by | Installed via | When to use |
|---|---|---|---|
| `servicemonitors.monitoring.coreos.com` | Any chart with `metrics.enabled: true` and Prometheus scraping | [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts) | Production monitoring |

```bash
# Install kube-prometheus-stack (if needed)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

---

## Network Requirements

### Egress (Outbound)

All Lerian charts require outbound connectivity to:
- **Kubernetes API server** (usually cluster-internal)
- **Container registries** (gcr.io, docker.io, quay.io, etc.) — for image pulls
- **External APIs** (payment gateways, banks, etc.) — dependent on plugins

### Ingress (Inbound)

| Service | Port | Protocol | Exposed by |
|---|---|---|---|
| product-console | 3000 | HTTP/HTTPS | Ingress or LoadBalancer |
| midaz API | 8080 | HTTP | Ingress or LoadBalancer |
| tracer | 4317, 4318 | gRPC/HTTP | ClusterIP (internal) |
| otel-collector-lerian | 4317, 4318 | gRPC/HTTP | ClusterIP (internal) |

---

## Validation Checklist

Use this checklist before deploying to production:

- [ ] Kubernetes cluster is version >= 1.24: `kubectl version --short`
- [ ] Worker nodes meet minimum CPU/memory: `kubectl top nodes`
- [ ] Default StorageClass exists: `kubectl get storageclass | grep default`
- [ ] cert-manager installed (if using TLS): `kubectl get crds | grep cert-manager`
- [ ] Network policies allow required egress
- [ ] Image pull secrets configured (if using private registries)
- [ ] Resource quotas do not conflict with chart defaults: `kubectl describe quota -n <namespace>`

---

## Adjusting Resource Limits

All charts support resource override via values.yaml:

```yaml
# Example: Override Midaz CPU/memory limits
midaz:
  resources:
    requests:
      cpu: 2000m
      memory: 1Gi
    limits:
      cpu: 4000m
      memory: 2Gi
```

**Production Best Practices:**
1. Start with chart defaults
2. Monitor actual usage (kubectl top, metrics)
3. Adjust requests/limits to 1.2-1.5x observed 95th percentile usage
4. Leave headroom (never fill cluster to >80% capacity)
5. Re-validate after configuration changes

---

## Related Documentation

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

---

**Last Updated:** 2026-06-26  
**Chart Version:** 1.0.0  
**Kubernetes Minimum:** 1.24  
**Status:** Complete ✅
