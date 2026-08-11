# Consul (Lerian wrapper) Helm Chart

## Chart Contract

- Chart type: `dependency-wrapper`
- Wraps: the official [`hashicorp/consul`](https://helm.releases.hashicorp.com) chart, pinned exactly at `1.6.10` (Consul `1.20.6`).
- Purpose: a minimal, single-node Consul **service-discovery** backend for `lib-service-discovery`. It is NOT a general Consul distribution — Connect/mesh, UI, catalog-sync, gateways and per-node client agents are all disabled.
- Dependency notes: wraps the upstream `consul` chart and intentionally carries only `templates/NOTES.txt`. All Kubernetes resources (StatefulSet, Services, ACL/gossip/TLS jobs) come from the subchart, so application-chart artifacts such as `_helpers.tpl` and a component `Deployment` do not apply.
- Required secrets: none to supply manually. With `consul.global.acls.manageSystemACLs=true` (default) the chart generates the bootstrap-ACL-token Secret; gossip encryption is OFF by default (single-node has no server-to-server gossip) and is REQUIRED before scaling past one server.
- Production overrides: for HA set `consul.server.replicas`/`consul.server.bootstrapExpect` to an odd number (3/5) and `consul.server.disruptionBudget.enabled=true`; set `consul.global.tls.enabled=true` for cross-trust-boundary access; tune `consul.server.storage`, `consul.server.storageClass`, `consul.global.image` and `consul.server.resources` per cluster.
- Reproducibility: `values.schema.json` keeps the `consul:` override block validated and `Chart.lock` pins the resolved dependency.
- Source/license: chart source in `github.com/LerianStudio/helm` under Apache-2.0. **The deployed Consul is third-party software under the Business Source License 1.1 — see [License](#license) below.**

---

## Why this wrapper exists

Consul is consumed only by `lib-service-discovery`, which uses a small slice of
Consul's API: Agent register/deregister, TTL + HTTP health checks, and
`Health().Service()` (resolve + blocking-query watch). It does not use KV,
Connect/mesh, namespaces, or the catalog. This chart curates the upstream chart
down to exactly that need.

### Deployment stance — facilitator, not blocker

The default is a **single Consul server (non-HA)**. Resilience is delegated to
the library: `lib-service-discovery`'s `DynamicResolver` keeps a
last-known-good cache, so a brief Consul outage degrades gracefully. Scale to a
real HA cluster only when required.

---

## Curated (BYOC) values surface

Only this small subset is meant to be tuned; everything else stays at upstream
defaults or is explicitly disabled in `values.yaml`.

| Key | Default | Notes |
| --- | --- | --- |
| `consul.server.replicas` / `consul.server.bootstrapExpect` | `1` / `1` | ODD counts only (1, 3, 5). `2` is forbidden. |
| `consul.global.image` | `hashicorp/consul:1.20.6@sha256:2004…518d` | Consul image, pinned by DIGEST for reproducibility. |
| `consul.server.storage` | `5Gi` | Raft data PVC size. |
| `consul.server.storageClass` | `""` | Empty = cluster default StorageClass. |
| `consul.global.acls.manageSystemACLs` | `true` | ACL bootstrap + token Secret. |
| `consul.global.tls.enabled` | `false` | See TLS note below. |
| `consul.global.gossipEncryption.autoGenerate` | `false` | OFF at the single-node default (nothing to encrypt). REQUIRED before scaling to 3/5 — set `true` (or provide `.secretName`); the chart fails the render otherwise. |
| `consul.server.resources` | modest | Sized for SD-only traffic. |
| `consul.server.disruptionBudget.enabled` | `false` | Enable when running 3/5 replicas. |

Disabled by default (do not enable unless you know you need them):
`consul.client`, `consul.ui`, `consul.syncCatalog`, `consul.connectInject`,
`consul.meshGateway`, `consul.ingressGateways`, `consul.terminatingGateways`.

### Raft quorum rules

- `1` — intentionally non-HA (default).
- `2` — **forbidden**: quorum of 2 tolerates zero failures and risks split-brain.
- `3` / `5` — tolerate 1 / 2 failures. Set `disruptionBudget.enabled=true` too.

```console
$ helm install lerian-consul charts/lerian-consul \
    --set consul.server.replicas=3 \
    --set consul.server.bootstrapExpect=3 \
    --set consul.server.disruptionBudget.enabled=true
```

### TLS

Default OFF. The server is reachable only in-cluster via ClusterIP, so the HTTP
API stays inside the pod network. Enabling TLS pulls in the `tls-init` Job (CA +
server cert generation), moves the API to port `8501`, and requires distributing
the CA to consumers.

```console
$ helm install lerian-consul charts/lerian-consul --set consul.global.tls.enabled=true
```

With TLS on, point `lib-service-discovery` at `...-consul-server:8501` (HTTPS)
and supply the generated CA.

### Hardening for external / shared clusters

The single-node defaults optimize for an internal, single-tenant BYOC backend. A
ClusterIP is **not** a trust boundary — by default any pod in the cluster can
reach the Consul HTTP/RPC/gossip ports. For an externally-distributed or shared
cluster, harden the deployment:

- **TLS**: `consul.global.tls.enabled=true` (encrypts the API; moves it to 8501).
- **NetworkPolicy**: `networkPolicy.enabled=true` restricts ingress to the server
  ports — server-to-server (RPC/gossip) only between the Consul servers, and the
  API (8500/8501) only from the same namespace plus `networkPolicy.allowedNamespaces`
  (list the SD-consuming namespaces). Off by default; not every CNI enforces it,
  and some route kubelet probes through it (see the template note if a probe breaks).
- **ACL**: hand workloads a scoped SD token, never the bootstrap token (below).

These are the gates for shipping to external clients; the DNS listener is already
disabled (`consul.server.extraConfig`).

---

## After install

- `SD_ADDRESS`: `<consul-fullname>-server.<namespace>.svc:8500` (or `:8501` with TLS), where `<consul-fullname>` resolves to `consul.fullnameOverride`, else `consul.global.name`, else `<release>-consul`. The post-install `NOTES` print the exact address resolved for your release.
See the post-install `NOTES` for the values resolved for your release.

### ACL tokens — bootstrap is admin-only

With `consul.global.acls.manageSystemACLs=true` (default) the chart writes the **bootstrap** token into `<consul-fullname>-bootstrap-acl-token`. This token has **full, unrestricted** access (ACLs, KV, operator) — treat it as an **administrator** credential:

```console
$ kubectl get secret -n <namespace> <consul-fullname>-bootstrap-acl-token \
    -o jsonpath='{.data.token}' | base64 -d ; echo
```

**Do not give the bootstrap token to application workloads** (CWE-269 least-privilege). Use it once, as an operator, to mint a **scoped service-discovery token** for `lib-service-discovery` — one that can only register/deregister and read health, nothing else:

```console
# CONSUL_HTTP_TOKEN = the bootstrap token above
$ cat > sd-policy.hcl <<'EOF'
service_prefix "" { policy = "write" }   # register / deregister + resolve
node_prefix    "" { policy = "read"  }   # read node health for resolution
EOF
$ consul acl policy create -name lib-service-discovery -rules @sd-policy.hcl
$ consul acl token create  -description lib-service-discovery \
    -policy-name lib-service-discovery -format=json | jq -r .SecretID
```

Store that SecretID in your own Secret and pass it to `lib-service-discovery` as `SD_TOKEN`; rotate/revoke it independently of the bootstrap token. (If you register through the **catalog** API instead of the agent API, grant `node_prefix "" { policy = "write" }` as well.) Automating this as an in-chart post-bootstrap Job is a deliberate non-goal for the minimal wrapper — do it in your platform bootstrap.

---

## Application Version Mapping

| Chart Version | Consul Version |
| :---: | :---: |
| `1.0.0` | 1.20.6 |

---

## License

This chart (the Lerian wrapper) is licensed **Apache-2.0**.

The workload it deploys — **HashiCorp Consul** (pinned `1.20.6`) — is **not** Apache/MPL: Consul `1.17.0`+ is under the **Business Source License 1.1 (BSL)**, HashiCorp's source-available license (Consul `≤ 1.16.x` was MPL 2.0). This chart does **not** redistribute the Consul binary — it references the upstream chart/images (`helm.releases.hashicorp.com`), which your cluster pulls at deploy time.

**BSL Additional Use Grant (summary — read the full text at [hashicorp/consul `v1.20.6` LICENSE](https://github.com/hashicorp/consul/blob/v1.20.6/LICENSE)):** you may make production use of Consul **provided you do not offer it to third parties on a hosted or embedded basis in order to compete with HashiCorp's paid Consul** (HCP Consul / Consul Enterprise). "Embedded" means bundling Consul code **in a competitive offering**; a "competitive offering" is a *paid* product that *significantly overlaps* with HashiCorp's paid Consul. Each version's BSL converts to **MPL 2.0** four years after its release (the "Change Date").

**What this means for Lerian and its clients:** running Consul as the internal service-discovery backend for `lib-service-discovery` in a core-banking platform is **not** a competitive offering — Consul is internal plumbing, not a Consul-like product sold to third parties — so this embedded / BYOC use is within the grant. If you intend to **resell managed or hosted Consul**, that is out of scope of this grant; obtain the appropriate HashiCorp license. This note is informational, not legal advice.

**Bundled third-party chart:** packaging this wrapper embeds the upstream `hashicorp/consul` Helm chart (`1.6.10`), which is **MPL-2.0** (a different license from the BSL binary above). Its full text and the attribution travel with the package — see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and [`licenses/MPL-2.0.txt`](licenses/MPL-2.0.txt).
