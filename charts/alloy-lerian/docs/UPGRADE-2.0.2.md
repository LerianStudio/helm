# Helm Upgrade from v2.0.1 to v2.0.2

This guide covers the upgrade from `alloy-lerian` chart version **2.0.1** to **2.0.2**. This patch release fixes namespace filtering for cluster object metrics in client profile deployments.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Namespace Filtering for Cluster Object Metrics](#1-namespace-filtering-for-cluster-object-metrics)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Namespace Filtering for Cluster Object Metrics

The chart now correctly filters cluster object metrics by namespace in `profile: client` deployments. Previously, the `kube_*` metrics allowlist filtered by metric family but did not apply the namespace perimeter, causing the agent to collect metrics from all namespaces in the cluster.

**Before (v2.0.1):**

The `prometheus.relabel "allowlist_objetos"` block applied only the metric family allowlist:

```yaml
prometheus.relabel "allowlist_objetos" {
  forward_to = [prometheus.relabel.sanitize_regulated.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "kube_pod_container_status_running|kube_pod_container_status_waiting|..."
    action        = "keep"
  }

  rule {
    target_label = "client_id"
    replacement  = sys.env("ALLOY_CLIENT_ID")
  }
}
```

**After (v2.0.2):**

The block now includes a namespace filter that matches the `namespaceInclude` perimeter:

```yaml
prometheus.relabel "allowlist_objetos" {
  forward_to = [prometheus.relabel.sanitize_regulated.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "kube_pod_container_status_running|kube_pod_container_status_waiting|..."
    action        = "keep"
  }

  // ⚠️ PERÍMETRO DE NAMESPACE — o mesmo dos eventos de cluster deste papel
  // (`namespaceInclude`). O kube-state-metrics descreve o cluster INTEIRO e não
  // recebe argumento de namespace; sem esta regra a allowlist acima filtra só a
  // FAMÍLIA, e cada pod, deployment e PVC do cliente sai do cluster dele.
  //
  // MEDIDO em voluti-stg (2026-10-20), primeiro BYOC migrado: 1.109 séries
  // `kube_*`, das quais 647 (58%) eram de kube-system, observability e security
  // do cliente. O agente anterior entregava só os namespaces da Lerian.
  //
  // Filtrar AQUI, e não nos argumentos do kube-state-metrics, é o que cobre o
  // `clusterObjectTarget` apontado para uma instância que o cliente já roda —
  // essa não é configurável por nós.
  //
  // ⚠️ `|^$` no fim, como no consumo de contêiner: `kube_node_*` e
  // `kube_persistentvolume_*` são de ESCOPO DE CLUSTER e não têm `namespace`.
  // Estão na allowlist de propósito (74 séries no mesmo cliente), e um `keep`
  // sem a alternativa vazia as descartaria em silêncio.
  //
  // Só o `include` vira regra. O `exclude` do perfil `own` fica de fora: lá o
  // cluster é nosso, e aplicá-lo aqui tiraria os `kube_*` de kube-system dos
  // ambientes internos — mudança que esta correção não pediu nem mediu.
  // VERIFICADO: com `examples/values-benedita.yaml` o render sai idêntico ao
  // anterior, fora este comentário.
  rule {
    source_labels = ["namespace"]
    regex         = "^(midaz|midaz-plugins)$|^$"
    action        = "keep"
  }

  rule {
    target_label = "client_id"
    replacement  = sys.env("ALLOY_CLIENT_ID")
  }
}
```

**What changed:**

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| Namespace filtering for `kube_*` metrics | Not applied | Applied via `prometheus.relabel` rule |
| Cluster-scoped metrics (`kube_node_*`, `kube_persistentvolume_*`) | Collected | Still collected (regex includes `\|^$` to preserve empty namespace label) |

**What this means:**

1. **In `profile: client` deployments**, the agent now collects cluster object metrics **only from namespaces matching `collection.namespaces.include`**
2. **Cluster-scoped metrics** (e.g., `kube_node_*`, `kube_persistentvolume_*`) continue to be collected because they have an empty `namespace` label and the regex includes `|^$` to match it
3. **In `profile: own` deployments**, no change: the namespace `exclude` filter is **not** applied to cluster object metrics (by design, to preserve `kube_*` metrics from `kube-system` in internal environments)

**Impact:**

Measured in a client cluster (`voluti-stg`, first BYOC migration):

- **Before:** 1,109 `kube_*` series collected, of which 647 (58%) were from client-owned namespaces (`kube-system`, `observability`, `security`)
- **After:** 462 `kube_*` series collected (only from `midaz` and `midaz-plugins` namespaces, plus 74 cluster-scoped series)

This is a **58% reduction** in series count for cluster object metrics in client profile deployments.

**Migration Steps:**

No action required. The namespace filter is applied automatically based on your existing `collection.namespaces.include` configuration.

**Verify the filter after upgrade:**

```bash
kubectl port-forward -n alloy-lerian svc/alloy-lerian-singleton 12345:12345
curl -s http://localhost:12345/metrics | grep 'kube_pod_info{namespace=' | cut -d'{' -f2 | cut -d',' -f1 | sort -u
```

You should see only namespaces matching your `collection.namespaces.include` regex, plus cluster-scoped metrics with `namespace=""`.

> **Note:** If you are using `collection.clusterObjectTarget` to point to an existing `kube-state-metrics` instance operated by the client, this fix ensures the namespace perimeter is still enforced. The previous version collected metrics from all namespaces in that scenario.

> **Important:** This fix applies **only to `profile: client`**. In `profile: own`, the namespace `exclude` filter is intentionally **not** applied to cluster object metrics to preserve visibility into system namespaces in internal environments.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.2 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.2 -n alloy-lerian
```
